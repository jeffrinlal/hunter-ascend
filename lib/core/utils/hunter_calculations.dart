/// Pure calculation & formatting helpers extracted from screen widgets.
///
/// These functions are completely independent of widget state, BuildContext,
/// Firestore, Firebase Auth, timers, navigation, and animations. Each returns
/// exactly the same output as the original in-widget method it replaced.
library;

/// Daily calorie goal derived from BMI (height/weight in the hunter doc).
/// Mirrors the original `_getCalorieGoal` exactly.
int calorieGoalFromData(Map<String, dynamic> data) {
  final height = (data['height'] ?? 0).toDouble();
  final weight = (data['weight'] ?? 0).toDouble();
  if (height <= 0 || weight <= 0) return 2000;
  final bmi = weight / ((height / 100) * (height / 100));
  if (bmi < 18.5) return 2500;
  if (bmi < 25) return 2000;
  if (bmi < 30) return 1700;
  return 1500;
}

/// ISO-8601 week number for [date]. Mirrors the original `_isoWeekNumber`.
int isoWeekNumber(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final dayOfYear = d.difference(DateTime(date.year, 1, 1)).inDays + 1;
  final week = ((dayOfYear - d.weekday + 10) / 7).floor();
  if (week < 1) return isoWeekNumber(DateTime(date.year - 1, 12, 31));
  if (week > 52) {
    final dec31 = DateTime(date.year, 12, 31);
    if (week == 53 && dec31.weekday < 4) return 1;
  }
  return week;
}

/// Current "year-Www" identifier (e.g. 2024-W03). Mirrors `_currentWeekId`.
String currentWeekId() {
  final now = DateTime.now();
  final w = isoWeekNumber(now);
  return '${now.year}-W${w.toString().padLeft(2, '0')}';
}

/// Time remaining until the next Monday 00:00. Mirrors `_untilNextMonday`.
Duration untilNextMonday() {
  final now = DateTime.now();
  final daysUntilMonday = (8 - now.weekday) % 7;
  final days = daysUntilMonday == 0 ? 7 : daysUntilMonday;
  final nextMonday =
      DateTime(now.year, now.month, now.day).add(Duration(days: days));
  return nextMonday.difference(now);
}

/// Formats a [Duration] as "mm:ss". Mirrors the identical in-widget
/// `_formatQuestTime` (dashboard) and `_formatDuration` (duel) methods.
String formatMinutesSeconds(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return "$m:$s";
}
