import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 3b: Stack with full-screen transparent Container + child.
/// If dashboard works: a full-screen background layer is fine.
/// If dashboard is black: a full-size child before content breaks layout.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Step 3b: Full-screen transparent Container as background layer.
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.transparent),
        child,
      ],
    );
  }
}
