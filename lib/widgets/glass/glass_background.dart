import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// DIAGNOSTIC BUILD — Step 1: Simple passthrough (just returns child).
/// If dashboard works: the bug is in the Stack/Positioned/decorative layers.
/// If dashboard is black: the bug is something else (should not happen).
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Step 1: Just return the child. No Stack, no decorations.
    return child;
  }
}
