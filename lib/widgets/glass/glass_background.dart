import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 7: _GlassDecorations with original production gradient.
/// Uses HunterTheme.background and HunterTheme.surface (dynamic theme colors).
/// No radial glows, no blur, no clip, no animations.
/// If dashboard works: theme-aware gradient is fine. Next: add radial glow #1.
/// If dashboard is black: reading HunterTheme colors in decoration causes issue.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _GlassDecorations(),
        ),
        child,
      ],
    );
  }
}

/// DIAGNOSTIC — Step 7: Original production LinearGradient only.
/// Uses dynamic HunterTheme colors (theme-aware).
class _GlassDecorations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
    );
  }
}
