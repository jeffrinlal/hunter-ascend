import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 9: Production gradient + both radial glows.
/// No blur, no clip, no animations.
/// If dashboard works: all static decorations are fine. Next: advanced rendering.
/// If dashboard is black: the second radial glow causes the issue.
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

/// DIAGNOSTIC — Step 9: Production gradient + both radial glows.
class _GlassDecorations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Production gradient
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

        // First radial glow (top-left)
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

        // Second radial glow (bottom-right)
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
      ],
    );
  }
}
