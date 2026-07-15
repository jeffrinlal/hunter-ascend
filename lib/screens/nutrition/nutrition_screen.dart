import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/nutrition/calorie_tracker_screen.dart';

/// Nutrition tab: hosts the [CalorieTrackerCard] on a scrollable page.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => Scaffold(
        backgroundColor: HunterTheme.background,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: HunterTheme.background,
          foregroundColor: HunterTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const CalorieTrackerCard(),
          ),
        ),
      ),
    );
  }
}
