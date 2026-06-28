import 'package:flutter/material.dart';
import 'calorie_tracker_screen.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
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