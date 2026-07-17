import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// A card widget that renders with true glassmorphism (frosted backdrop blur,
/// semi-transparent gradient fill, thin white borders) when the Crystal Glass
/// theme is active. Falls back to a standard opaque card for all other themes.
///
/// ## Usage
/// Replace any `Container(decoration: BoxDecoration(color: HunterTheme.cardColor, ...))`
/// with `GlassCard(child: ...)` to gain automatic glass rendering when the
/// Crystal Glass theme is selected.
///
/// ## Performance
/// `BackdropFilter` is GPU-intensive. This widget only enables it when
/// Crystal Glass is active — all other themes use a simple `Container` with
/// zero blur overhead.
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
    this.highlightOpacity = 0.06,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final EdgeInsets? margin;

  /// Blur strength (higher = more frosted). 14 is a good balance of
  /// premium feel vs GPU cost.
  final double blurSigma;

  /// Opacity of the gradient fill (top-left highlight).
  final double fillOpacityHigh;

  /// Opacity of the gradient fill (bottom-right).
  final double fillOpacityLow;

  /// Opacity of the thin white border.
  final double borderOpacity;

  /// Opacity of the top-left highlight accent.
  final double highlightOpacity;

  bool get _isGlassActive =>
      ThemeService.instance.activeThemeNotifier.value == AppTheme.crystalGlass;

  @override
  Widget build(BuildContext context) {
    if (!_isGlassActive) {
      return _buildStandardCard();
    }
    return _buildGlassCard();
  }

  /// Standard opaque card used by all non-glass themes.
  Widget _buildStandardCard() {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: HunterTheme.border, width: 1.5),
      ),
      child: child,
    );
  }

  /// True glassmorphism card: backdrop blur + semi-transparent gradient +
  /// thin white border + subtle shadow for floating depth.
  Widget _buildGlassCard() {
    return Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(fillOpacityHigh),
                  Colors.white.withOpacity(fillOpacityLow),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(borderOpacity),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
