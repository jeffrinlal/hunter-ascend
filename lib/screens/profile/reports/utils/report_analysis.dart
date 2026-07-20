import '../models/report_data.dart';
import 'report_format.dart';

/// Hunter Analysis — deterministic, rule-based ratings.
///
/// Every rating below is computed with a fixed set of thresholds applied to
/// values that ALREADY exist in Firestore (or are derived from them client
/// side). There is **no AI**, no randomness, and no network call: the same
/// inputs always produce the same rating. This makes the analysis explainable,
/// testable, and free (no reads/writes beyond the report's own data load).
///
/// Inputs used:
///   • streak      — `hunters/{uid}.streak`             (current daily streak)
///   • activeDays  — distinct calendar days in the selected range that have a
///                   `calorie_logs`, `runs`, or `weight_history` entry
///   • totalDuels  — `duelWins + duelLosses`            (lifetime duel count)
///   • level       — `hunters/{uid}.level`
///   • rank        — derived from `hunters/{uid}.level` via `RankService`
class ReportAnalysis {
  ReportAnalysis._();

  /// DISCIPLINE — measured purely from the current daily [streak].
  ///
  /// A longer uninterrupted streak reflects stronger day-to-day discipline.
  ///
  /// | streak (days) | rating       | level |
  /// |---------------|--------------|-------|
  /// | ≥ 30          | Excellent    | 4     |
  /// | 14 – 29       | Great        | 3     |
  /// | 7 – 13        | Good         | 2     |
  /// | 3 – 6         | Developing   | 1     |
  /// | 0 – 2         | Awakening    | 0     |
  static Rating discipline(int streak) {
    if (streak >= 30) return const Rating('Excellent', 4);
    if (streak >= 14) return const Rating('Great', 3);
    if (streak >= 7) return const Rating('Good', 2);
    if (streak >= 3) return const Rating('Developing', 1);
    return const Rating('Awakening', 0);
  }

  /// CONSISTENCY — measured from [activeDays]: the number of DISTINCT calendar
  /// days within the selected range (max 30) on which the hunter logged any
  /// activity (a meal, a run, or a weight entry).
  ///
  /// More active days out of the period = higher consistency.
  ///
  /// | active days | rating     | level |
  /// |-------------|------------|-------|
  /// | ≥ 20        | Very High  | 4     |
  /// | 12 – 19     | High       | 3     |
  /// | 6 – 11      | Moderate   | 2     |
  /// | 1 – 5       | Building   | 1     |
  /// | 0           | Dormant    | 0     |
  static Rating consistency(int activeDays) {
    if (activeDays >= 20) return const Rating('Very High', 4);
    if (activeDays >= 12) return const Rating('High', 3);
    if (activeDays >= 6) return const Rating('Moderate', 2);
    if (activeDays >= 1) return const Rating('Building', 1);
    return const Rating('Dormant', 0);
  }

  /// COMBAT ACTIVITY — measured from [totalDuels] (`duelWins + duelLosses`),
  /// i.e. how engaged the hunter is with duels overall (lifetime).
  ///
  /// | total duels | rating    | level |
  /// |-------------|-----------|-------|
  /// | ≥ 20        | Elite     | 4     |
  /// | 10 – 19     | High      | 3     |
  /// | 4 – 9       | Good      | 2     |
  /// | 1 – 3       | Active    | 1     |
  /// | 0           | Untested  | 0     |
  static Rating combat(int totalDuels) {
    if (totalDuels >= 20) return const Rating('Elite', 4);
    if (totalDuels >= 10) return const Rating('High', 3);
    if (totalDuels >= 4) return const Rating('Good', 2);
    if (totalDuels >= 1) return const Rating('Active', 1);
    return const Rating('Untested', 0);
  }

  /// HUNTER POTENTIAL — an overall composite of the hunter's standing.
  ///
  /// A single weighted score is computed from five capped inputs, then mapped
  /// to a rating. Each input is capped so no single dimension dominates:
  ///
  ///   score = rankIndex(rank) * 10   // rank E..S → 0..50
  ///         + clamp(level,      0, 50)
  ///         + clamp(streak,     0, 30)
  ///         + clamp(activeDays, 0, 30)
  ///         + clamp(totalDuels, 0, 20)
  ///
  /// Maximum possible score = 50 + 50 + 30 + 30 + 20 = 180.
  ///
  /// | score     | rating     | level |
  /// |-----------|------------|-------|
  /// | ≥ 120     | S-Class    | 4     |
  /// | 85 – 119  | Elite      | 3     |
  /// | 55 – 84   | Rising     | 2     |
  /// | 25 – 54   | Promising  | 1     |
  /// | 0 – 24    | Novice     | 0     |
  static Rating potential({
    required String rank,
    required int level,
    required int streak,
    required int activeDays,
    required int totalDuels,
  }) {
    final score = rankIndex(rank) * 10 +
        level.clamp(0, 50) +
        streak.clamp(0, 30) +
        activeDays.clamp(0, 30) +
        totalDuels.clamp(0, 20);
    if (score >= 120) return const Rating('S-Class', 4);
    if (score >= 85) return const Rating('Elite', 3);
    if (score >= 55) return const Rating('Rising', 2);
    if (score >= 25) return const Rating('Promising', 1);
    return const Rating('Novice', 0);
  }
}
