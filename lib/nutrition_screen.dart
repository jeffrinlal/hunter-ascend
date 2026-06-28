import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'calorie_tracker_screen.dart';

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
        title: const Text("Nutrition"),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          child: CalorieTrackerCard(),
        ),
      ),
    );
  }
}