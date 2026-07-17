import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 3: Stack with two children (SizedBox.shrink + child).
/// If dashboard works: multiple children in Stack is not the problem.
/// If dashboard is black: adding a second child breaks layout.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Step 3: Stack with a harmless second child.
    return Stack(
      fit: StackFit.expand,
      children: [
        const SizedBox.shrink(),
        child,
      ],
    );
  }
}
