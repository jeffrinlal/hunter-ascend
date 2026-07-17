import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// A background widget that provides visual depth for glassmorphism.
///
/// When the Crystal Glass theme is active, it renders a subtle gradient with
/// soft radial glows behind the content — giving `BackdropFilter` something
/// meaningful to blur.
///
/// ## Structural Stability
/// The widget tree structure is ALWAYS:
///   Stack > [decorativeLayer, contentLayer]
///
/// Both layers are always present. The decorative layer renders nothing
/// (SizedBox.shrink) when glass is inactive, and gradient/glow visuals
/// when glass is active. The content layer is always at index 1 with a
/// stable ValueKey — ensuring Flutter never destroys or recreates
/// descendant Elements (StreamBuilder, FutureBuilder, Controllers, etc.)
/// when the theme changes.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  bool get _isGlassActive =>
      ThemeService.instance.activeThemeNotifier.value == AppTheme.crystalGlass;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Index 0: Decorative layer (always present, content varies).
        if (_isGlassActive)
          Positioned.fill(
            child: _GlassDecorations(),
          )
        else
          const SizedBox.shrink(),

        // Index 1: Content layer (always at this index, keyed for safety).
        Positioned.fill(
          key: const ValueKey('glass_bg_content'),
          child: child,
        ),
      ],
    );
  }
}

/// The decorative background layers for the glass effect.
/// Separated into its own widget so the Stack children list always has
/// exactly 2 items (decorative + content) regardless of theme state.
class _GlassDecorations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Gradient base ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HunterTheme.background,
                  HunterTheme.surface,
                  HunterTheme.background,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // ── Top-left radial glow ──
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  HunterTheme.primary.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Bottom-right radial glow ──
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  HunterTheme.primary.withOpacity(0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Center ambient glow ──
        Positioned(
          top: 200,
          left: 80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.02),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
