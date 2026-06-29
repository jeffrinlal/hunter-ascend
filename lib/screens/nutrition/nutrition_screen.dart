import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/nutrition/calorie_tracker_screen.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.cardColor,
        foregroundColor: HunterTheme.textPrimary,
        elevation: 0,
        title: const Text("Nutrition"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: CalorieTrackerCard(),
        ),
      ),
    );
  }
}