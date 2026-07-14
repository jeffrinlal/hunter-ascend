import 'package:flutter/material.dart';

import '../utils/report_palette.dart';

/// A single run (from the `runs` collection).
class RunEntry {
  final double distanceKm;
  final int durationSeconds;
  final int caloriesBurned;
  final int xpEarned;
  final DateTime createdAt;

  const RunEntry({
    required this.distanceKm,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.xpEarned,
    required this.createdAt,
  });
}

/// A single logged meal (from the `calorie_logs` collection).
class MealEntry {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime time;

  const MealEntry({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
  });
}

/// A single weight measurement (from the `weight_history` collection).
class WeightEntry {
  final double weight;
  final DateTime date;

  const WeightEntry({required this.weight, required this.date});
}

/// The raw, already-filtered (≤30 day) data pulled once when the report opens.
///
/// Each source carries its own `*Ok` flag so a single failure (e.g. a missing
/// index) omits only that metric rather than breaking the whole report.
class ReportData {
  final List<MealEntry> meals;
  final List<RunEntry> runs;
  final List<WeightEntry> weights;
  final bool nutritionOk;
  final bool runsOk;
  final bool weightOk;

  const ReportData({
    required this.meals,
    required this.runs,
    required this.weights,
    required this.nutritionOk,
    required this.runsOk,
    required this.weightOk,
  });

  /// An empty, all-unavailable report (used as a safe fallback).
  const ReportData.empty()
      : meals = const [],
        runs = const [],
        weights = const [],
        nutritionOk = false,
        runsOk = false,
        weightOk = false;
}

/// A qualitative rating for the Hunter Analysis section.
///
/// [level] runs 0 (lowest) … 4 (highest) and drives both the label colour and
/// the intensity bar, keeping the presentation consistent everywhere.
@immutable
class Rating {
  final String label;
  final int level;

  const Rating(this.label, this.level);

  /// Colour from the restrained rating scale.
  Color get color => ReportPalette.ratingColor(level);

  /// Bar fill fraction (0.2 … 1.0) for the intensity indicator.
  double get fill => (level + 1) / 5;
}
