import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 4: Positioned.fill(Container(transparent)) + child.
/// If dashboard works: Positioned.fill layout is fine. Next: decorative layers.
/// If dashboard is black: Positioned.fill is the offending widget.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Step 4: Positioned.fill wrapping a transparent Container.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Container(color: Colors.transparent),
        ),
        child,
      ],
    );
  }
}
