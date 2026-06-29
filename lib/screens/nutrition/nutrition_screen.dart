import 'package:flutter/material.dart';
import 'package:hunter_ascend/screens/nutrition/calorie_tracker_screen.dart';

/// Nutrition tab: hosts the [CalorieTrackerCard] on a scrollable page.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        foregroundColor: const Color(0xFF1A1A1A),
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
    );
  }
}
