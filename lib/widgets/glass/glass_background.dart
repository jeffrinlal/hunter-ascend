import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 2: Simplest possible Stack wrapping child.
/// If dashboard works: the bug is in the decorative layers or Positioned wrappers.
/// If dashboard is black: the Stack itself is the problem.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Step 2: Simplest Stack with just the child.
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
      ],
    );
  }
}
