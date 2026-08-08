import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// The four fitness goals that plan PDFs are organized by.
enum FitnessGoal {
  weightLoss,
  weightGain,
  muscleBuild,
  athleteBody;

  /// Human-readable tab/card label.
  String get label {
    switch (this) {
      case FitnessGoal.weightLoss:
        return 'Weight Loss';
      case FitnessGoal.weightGain:
        return 'Weight Gain';
      case FitnessGoal.muscleBuild:
        return 'Muscle Build';
      case FitnessGoal.athleteBody:
        return 'Athlete Body';
    }
  }

  /// Icon used in tab bars and plan cards.
  IconData get icon {
    switch (this) {
      case FitnessGoal.weightLoss:
        return Icons.local_fire_department_rounded;
      case FitnessGoal.weightGain:
        return Icons.monitor_weight_rounded;
      case FitnessGoal.muscleBuild:
        return Icons.fitness_center_rounded;
      case FitnessGoal.athleteBody:
        return Icons.sports_martial_arts_rounded;
    }
  }

  /// Accent color for the goal across the Shop UI.
  Color get accentColor {
    switch (this) {
      case FitnessGoal.weightLoss:
        return HunterTheme.danger;
      case FitnessGoal.weightGain:
        return HunterTheme.gold;
      case FitnessGoal.muscleBuild:
        return HunterTheme.purple;
      case FitnessGoal.athleteBody:
        return HunterTheme.info;
    }
  }

  /// Folder name used under `assets/plans/`.
  String get folderName {
    switch (this) {
      case FitnessGoal.weightLoss:
        return 'weight_loss';
      case FitnessGoal.weightGain:
        return 'weight_gain';
      case FitnessGoal.muscleBuild:
        return 'muscle_build';
      case FitnessGoal.athleteBody:
        return 'athlete_body';
    }
  }
}

/// The five plan durations available for each goal.
///
/// [days] is used both as the plan's length and as the data-driven unlock
/// window — a 30-day plan stays unlocked for 30 days, etc.
enum PlanDuration {
  oneWeek,
  twoWeek,
  thirtyDay,
  sixtyDay,
  ninetyDay;

  /// Human-readable duration label.
  String get label {
    switch (this) {
      case PlanDuration.oneWeek:
        return '1 Week';
      case PlanDuration.twoWeek:
        return '2 Weeks';
      case PlanDuration.thirtyDay:
        return '30 Days';
      case PlanDuration.sixtyDay:
        return '60 Days';
      case PlanDuration.ninetyDay:
        return '90 Days';
    }
  }

  /// Short badge text for plan cards.
  String get badge {
    switch (this) {
      case PlanDuration.oneWeek:
        return '7D';
      case PlanDuration.twoWeek:
        return '14D';
      case PlanDuration.thirtyDay:
        return '30D';
      case PlanDuration.sixtyDay:
        return '60D';
      case PlanDuration.ninetyDay:
        return '90D';
    }
  }

  /// Number of days this plan lasts — also used as the unlock duration.
  int get days {
    switch (this) {
      case PlanDuration.oneWeek:
        return 7;
      case PlanDuration.twoWeek:
        return 14;
      case PlanDuration.thirtyDay:
        return 30;
      case PlanDuration.sixtyDay:
        return 60;
      case PlanDuration.ninetyDay:
        return 90;
    }
  }

  /// Suffix used in the plan id and PDF file name.
  String get idSuffix {
    switch (this) {
      case PlanDuration.oneWeek:
        return '1_week';
      case PlanDuration.twoWeek:
        return '2_week';
      case PlanDuration.thirtyDay:
        return '30_day';
      case PlanDuration.sixtyDay:
        return '60_day';
      case PlanDuration.ninetyDay:
        return '90_day';
    }
  }
}

/// An immutable description of a single PDF fitness plan in the shop.
@immutable
class FitnessPlan {
  const FitnessPlan({
    required this.id,
    required this.goal,
    required this.duration,
    required this.title,
  });

  /// Unique plan id, e.g. `"weight_loss_1_week"`. Also the Firestore
  /// document id under `hunters/{uid}/planUnlocks/{planId}`.
  final String id;

  /// The goal category this plan belongs to.
  final FitnessGoal goal;

  /// The duration tier of this plan.
  final PlanDuration duration;

  /// Human-readable plan title.
  final String title;

  /// Number of days the plan lasts — derived from [duration.days].
  /// Also used as the unlock window (data-driven expiry).
  int get durationDays => duration.days;

  /// Asset path to the bundled PDF, e.g.
  /// `assets/plans/weight_loss/weight_loss_1_week.pdf`.
  String get assetPath => 'assets/plans/${goal.folderName}/$id.pdf';
}

/// Static catalog of all available fitness plans.
///
/// Generates all 20 plans (4 goals × 5 durations) at compile time.
class PlanCatalog {
  PlanCatalog._();

  /// All plans in the catalog, ordered by goal then duration.
  static const List<FitnessPlan> all = [
    // ── Weight Loss ──
    FitnessPlan(
        id: 'weight_loss_1_week',
        goal: FitnessGoal.weightLoss,
        duration: PlanDuration.oneWeek,
        title: 'Weight Loss — 1 Week'),
    FitnessPlan(
        id: 'weight_loss_2_week',
        goal: FitnessGoal.weightLoss,
        duration: PlanDuration.twoWeek,
        title: 'Weight Loss — 2 Weeks'),
    FitnessPlan(
        id: 'weight_loss_30_day',
        goal: FitnessGoal.weightLoss,
        duration: PlanDuration.thirtyDay,
        title: 'Weight Loss — 30 Days'),
    FitnessPlan(
        id: 'weight_loss_60_day',
        goal: FitnessGoal.weightLoss,
        duration: PlanDuration.sixtyDay,
        title: 'Weight Loss — 60 Days'),
    FitnessPlan(
        id: 'weight_loss_90_day',
        goal: FitnessGoal.weightLoss,
        duration: PlanDuration.ninetyDay,
        title: 'Weight Loss — 90 Days'),
    // ── Weight Gain ──
    FitnessPlan(
        id: 'weight_gain_1_week',
        goal: FitnessGoal.weightGain,
        duration: PlanDuration.oneWeek,
        title: 'Weight Gain — 1 Week'),
    FitnessPlan(
        id: 'weight_gain_2_week',
        goal: FitnessGoal.weightGain,
        duration: PlanDuration.twoWeek,
        title: 'Weight Gain — 2 Weeks'),
    FitnessPlan(
        id: 'weight_gain_30_day',
        goal: FitnessGoal.weightGain,
        duration: PlanDuration.thirtyDay,
        title: 'Weight Gain — 30 Days'),
    FitnessPlan(
        id: 'weight_gain_60_day',
        goal: FitnessGoal.weightGain,
        duration: PlanDuration.sixtyDay,
        title: 'Weight Gain — 60 Days'),
    FitnessPlan(
        id: 'weight_gain_90_day',
        goal: FitnessGoal.weightGain,
        duration: PlanDuration.ninetyDay,
        title: 'Weight Gain — 90 Days'),
    // ── Muscle Build ──
    FitnessPlan(
        id: 'muscle_build_1_week',
        goal: FitnessGoal.muscleBuild,
        duration: PlanDuration.oneWeek,
        title: 'Muscle Build — 1 Week'),
    FitnessPlan(
        id: 'muscle_build_2_week',
        goal: FitnessGoal.muscleBuild,
        duration: PlanDuration.twoWeek,
        title: 'Muscle Build — 2 Weeks'),
    FitnessPlan(
        id: 'muscle_build_30_day',
        goal: FitnessGoal.muscleBuild,
        duration: PlanDuration.thirtyDay,
        title: 'Muscle Build — 30 Days'),
    FitnessPlan(
        id: 'muscle_build_60_day',
        goal: FitnessGoal.muscleBuild,
        duration: PlanDuration.sixtyDay,
        title: 'Muscle Build — 60 Days'),
    FitnessPlan(
        id: 'muscle_build_90_day',
        goal: FitnessGoal.muscleBuild,
        duration: PlanDuration.ninetyDay,
        title: 'Muscle Build — 90 Days'),
    // ── Athlete Body ──
    FitnessPlan(
        id: 'athlete_body_1_week',
        goal: FitnessGoal.athleteBody,
        duration: PlanDuration.oneWeek,
        title: 'Athlete Body — 1 Week'),
    FitnessPlan(
        id: 'athlete_body_2_week',
        goal: FitnessGoal.athleteBody,
        duration: PlanDuration.twoWeek,
        title: 'Athlete Body — 2 Weeks'),
    FitnessPlan(
        id: 'athlete_body_30_day',
        goal: FitnessGoal.athleteBody,
        duration: PlanDuration.thirtyDay,
        title: 'Athlete Body — 30 Days'),
    FitnessPlan(
        id: 'athlete_body_60_day',
        goal: FitnessGoal.athleteBody,
        duration: PlanDuration.sixtyDay,
        title: 'Athlete Body — 60 Days'),
    FitnessPlan(
        id: 'athlete_body_90_day',
        goal: FitnessGoal.athleteBody,
        duration: PlanDuration.ninetyDay,
        title: 'Athlete Body — 90 Days'),
  ];

  /// Returns all plans for the given [goal].
  static List<FitnessPlan> byGoal(FitnessGoal goal) =>
      all.where((p) => p.goal == goal).toList();

  /// Finds a plan by id, or `null` if not found.
  static FitnessPlan? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
