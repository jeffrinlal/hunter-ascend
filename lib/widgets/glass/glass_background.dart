import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 6: _GlassDecorations with a simple gradient.
/// No blur, no clip, no animations.
/// If dashboard works: gradients are fine. Next: restore full decoration stack.
/// If dashboard is black: a gradient in the decoration layer causes the issue.
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

/// DIAGNOSTIC — Step 6: Single gradient only. No blur, no clip, no animation.
class _GlassDecorations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x11000000),
            Color(0x00000000),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
