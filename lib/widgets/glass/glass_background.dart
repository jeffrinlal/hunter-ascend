import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 5: Positioned.fill(_GlassDecorations as passthrough) + child.
/// _GlassDecorations is a SizedBox.expand() — no actual decorations rendered.
/// If dashboard works: the decoration widget slot is fine. Next: add content inside it.
/// If dashboard is black: the _GlassDecorations widget class itself causes an issue.
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

/// DIAGNOSTIC — Step 5: Empty passthrough. No decorations.
class _GlassDecorations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
