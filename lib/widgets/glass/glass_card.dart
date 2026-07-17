import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// A card widget that renders with true glassmorphism (frosted backdrop blur,
/// semi-transparent gradient fill, thin white borders) when the Crystal Glass
/// theme is active. Falls back to a standard opaque card for all other themes.
///
/// ## Structural Stability
/// The widget tree structure is ALWAYS identical regardless of theme:
///   Container > ClipRRect > BackdropFilter > Container > child
///
/// When glass is inactive, BackdropFilter uses a zero-blur filter (identity
/// matrix — no GPU cost) and the inner Container uses opaque colors. This
/// ensures descendant Elements (including any StatefulWidgets inside the
/// card) are never destroyed by a theme change.
///
/// ## Performance
/// When glass is inactive: `ImageFilter.blur(sigmaX: 0, sigmaY: 0)` is
/// a no-op recognized by the engine — it does not rasterize a blur pass.
/// The only overhead is the extra ClipRRect and BackdropFilter Elements in
/// the tree (negligible — no GPU work, just framework bookkeeping).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20.0,
    this.margin,
    this.blurSigma = 14.0,
    this.fillOpacityHigh = 0.08,
    this.fillOpacityLow = 0.03,
    this.borderOpacity = 0.12,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final EdgeInsets? margin;

  /// Blur strength when glass is active (higher = more frosted).
  final double blurSigma;

  /// Opacity of the gradient fill (top-left highlight) when glass is active.
  final double fillOpacityHigh;

  /// Opacity of the gradient fill (bottom-right) when glass is active.
  final double fillOpacityLow;

  /// Opacity of the thin white border when glass is active.
  final double borderOpacity;

  bool get _isGlassActive =>
      ThemeService.instance.activeThemeNotifier.value == AppTheme.crystalGlass;

  @override
  Widget build(BuildContext context) {
    final glass = _isGlassActive;

    // Outer container: holds margin, shadow (glass only), and border radius.
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // Shadow only visible in glass mode for floating depth.
        boxShadow: glass
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      // ClipRRect + BackdropFilter always present (stable tree structure).
      // When not glass: blur sigma is 0 (no GPU cost, identity filter).
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glass ? blurSigma : 0,
            sigmaY: glass ? blurSigma : 0,
          ),
          // Inner container: decoration switches between glass and opaque.
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // Glass: semi-transparent gradient.
              // Standard: opaque card color.
              color: glass ? null : HunterTheme.cardColor,
              gradient: glass
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(fillOpacityHigh),
                        Colors.white.withOpacity(fillOpacityLow),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: glass
                    ? Colors.white.withOpacity(borderOpacity)
                    : HunterTheme.border,
                width: glass ? 1.0 : 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
