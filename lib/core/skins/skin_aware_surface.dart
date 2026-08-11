import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/skins/skin_style_registry.dart';
import 'package:hunter_ascend/core/skins/skin_visual_style.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// The single reusable component through which every screen becomes
/// "skin-aware," without any screen ever knowing which specific skin is
/// active.
///
/// ## Why this exists (architecture)
/// Rather than duplicating whole screens per skin
/// (`ShadowDashboard.dart`, `CyberDashboard.dart`, ...), every screen wraps
/// its existing hero/card `Widget` in `SkinAwareSurface(child: existingCard)`.
/// This widget resolves the current [SkinVisualStyle] (via
/// [SkinStyleRegistry]) and paints a purely *structural/decorative* overlay
/// on top — border silhouette, corner emblem, motion — leaving the wrapped
/// `child` (and all the data/logic that built it) completely untouched.
///
/// ## What this widget will NEVER do
/// - It never reads or mutates gameplay data (XP, quests, steps, water,
///   Firestore) — it only wraps a widget that was already built by the
///   screen from that data.
/// - It never introduces a hardcoded color. Every color used internally is
///   pulled from the existing `MembershipTheme.current.accent` token (the
///   same accent every screen already themes its buttons/borders with), so
///   the overlay always matches whichever Premium Theme is currently
///   active. A Skin restructures shape and motion — never palette.
/// - It never renders anything when the Skin is not the active appearance
///   (see [SkinService.skinAppearanceActiveNotifier]) or when
///   [SkinId.classic] is selected — in both cases it returns [child]
///   completely unmodified, guaranteeing byte-for-byte identical rendering
///   to how the screen looked before Phase 3.
///
/// ## Performance
/// The internal [AnimationController] is only ever running while a
/// decorated (non-classic, active-appearance) skin style is resolved —
/// it is stopped immediately once the style has no decoration, so Basic/
/// Classic users pay zero animation-ticking cost.
class SkinAwareSurface extends StatefulWidget {
  const SkinAwareSurface({
    super.key,
    required this.child,
    this.borderRadius,
  });

  /// The existing, fully-built card/content this screen already renders.
  /// Passed through unmodified — this widget only adds decoration around
  /// or on top of it.
  final Widget child;

  /// Optional override for the corner radius the overlay border/clip uses.
  /// Defaults to the active [SkinVisualStyle.baseBorderRadius] when omitted,
  /// so most call sites don't need to specify anything.
  final double? borderRadius;

  @override
  State<SkinAwareSurface> createState() => _SkinAwareSurfaceState();
}

class _SkinAwareSurfaceState extends State<SkinAwareSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SkinId>(
      valueListenable: SkinService.instance.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SkinService.instance.skinAppearanceActiveNotifier,
          builder: (context, appearanceActive, __) {
            final style = (appearanceActive && activeSkin != SkinId.classic)
                ? SkinStyleRegistry.forSkin(activeSkin)
                : SkinStyleRegistry.classic;

            if (!style.hasDecoration) {
              // Classic, or the Skin is suppressed in favor of a Premium
              // Theme — render the screen's original card completely
              // unmodified. No animation ticks, no overlay, no emblem.
              if (_controller.isAnimating) _controller.stop();
              return widget.child;
            }

            if (!_controller.isAnimating) {
              _controller.repeat(reverse: true);
            }

            final radius = widget.borderRadius ?? style.baseBorderRadius;
            final accent = MembershipTheme.current.accent;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    widget.child,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SkinBorderPainter(
                            style: style,
                            t: _controller.value,
                            color: accent,
                            radius: radius,
                          ),
                        ),
                      ),
                    ),
                    if (style.emblemIcon != null)
                      Positioned(
                        top: style.emblemAlignment.y <= 0 ? 8 : null,
                        bottom: style.emblemAlignment.y > 0 ? 8 : null,
                        left: style.emblemAlignment.x <= 0 ? 8 : null,
                        right: style.emblemAlignment.x > 0 ? 8 : null,
                        child: IgnorePointer(
                          child: _SkinEmblem(
                            icon: style.emblemIcon!,
                            color: accent,
                            t: _controller.value,
                            flicker: style.animation == SkinAnimationStyle.flicker,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Small decorative corner badge. Uses only the passed-in [color] (the
/// existing membership accent) — no new color is introduced.
class _SkinEmblem extends StatelessWidget {
  const _SkinEmblem({
    required this.icon,
    required this.color,
    required this.t,
    required this.flicker,
  });

  final IconData icon;
  final Color color;
  final double t;
  final bool flicker;

  @override
  Widget build(BuildContext context) {
    final opacity = flicker
        ? (0.55 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 5))).clamp(0.0, 1.0)
        : 0.85;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.14),
        border: Border.all(color: color.withOpacity(opacity), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(opacity * 0.4), blurRadius: 8),
        ],
      ),
      child: Icon(icon, size: 14, color: color.withOpacity(opacity)),
    );
  }
}

/// Paints a skin's structural border silhouette (shape + motion). Every
/// color used derives from [color] (the caller-supplied membership accent)
/// — this painter has no concept of "which skin" beyond the geometry
/// described by [SkinVisualStyle]; it never hardcodes a palette.
class _SkinBorderPainter extends CustomPainter {
  _SkinBorderPainter({
    required this.style,
    required this.t,
    required this.color,
    required this.radius,
  });

  final SkinVisualStyle style;
  final double t;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = _pathForShape(rect);

    double strokeWidth = 1.4;
    double opacity = 0.45;

    switch (style.animation) {
      case SkinAnimationStyle.none:
        opacity = 0.35;
        break;
      case SkinAnimationStyle.pulseGlow:
        final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        opacity = 0.32 + 0.34 * wave;
        strokeWidth = 1.4 + 0.7 * wave;
        break;
      case SkinAnimationStyle.scanline:
        opacity = 0.5;
        break;
      case SkinAnimationStyle.frostShimmer:
        opacity = 0.38 + 0.28 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
        break;
      case SkinAnimationStyle.flicker:
        final flick =
            (0.5 + 0.5 * math.sin(t * 2 * math.pi * 3) * math.cos(t * 2 * math.pi * 1.7))
                .abs();
        opacity = 0.30 + 0.35 * flick;
        break;
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(opacity.clamp(0.0, 1.0));

    canvas.drawPath(path, borderPaint);

    if (style.doubleBorder) {
      final innerPath = _pathForShape(rect.deflate(6));
      canvas.drawPath(
        innerPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 0.8
          ..color = color.withOpacity((opacity * 0.6).clamp(0.0, 1.0)),
      );
    }

    if (style.animation == SkinAnimationStyle.scanline) {
      final y = size.height * t;
      final band = Rect.fromLTWH(0, (y - 12).clamp(0, size.height), size.width, 24);
      final scanPaint = Paint()
        ..shader = LinearGradient(
          colors: [color.withOpacity(0), color.withOpacity(0.5), color.withOpacity(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(band);
      canvas.drawRect(band, scanPaint);
    }
  }

  Path _pathForShape(Rect rect) {
    switch (style.cornerShape) {
      case SkinCornerShape.rounded:
        return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

      case SkinCornerShape.sharpPanel:
        final r = math.min(radius, 8.0);
        final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
        const tick = 14.0;
        path
          ..moveTo(rect.left, rect.top + tick)
          ..lineTo(rect.left, rect.top)
          ..lineTo(rect.left + tick, rect.top)
          ..moveTo(rect.right - tick, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + tick)
          ..moveTo(rect.right, rect.bottom - tick)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.right - tick, rect.bottom)
          ..moveTo(rect.left + tick, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.left, rect.bottom - tick);
        return path;

      case SkinCornerShape.crystalFacet:
        final facet = math.min(radius, math.min(rect.width, rect.height) * 0.18);
        return Path()
          ..moveTo(rect.left + facet, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom - facet)
          ..lineTo(rect.right - facet, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..lineTo(rect.left, rect.top + facet)
          ..close();

      case SkinCornerShape.jaggedEdge:
        const toothHeight = 8.0;
        const teeth = 6;
        final segment = rect.width / teeth;
        final path = Path()
          ..moveTo(rect.left, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.bottom - toothHeight);
        for (int i = teeth; i >= 0; i--) {
          final x = rect.left + segment * i;
          final y = i.isEven ? rect.bottom : rect.bottom - toothHeight;
          path.lineTo(x, y);
        }
        path
          ..lineTo(rect.left, rect.bottom - toothHeight)
          ..close();
        return path;
    }
  }

  @override
  bool shouldRepaint(covariant _SkinBorderPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.style != style || oldDelegate.color != color || oldDelegate.radius != radius;
}
