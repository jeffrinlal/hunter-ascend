/// Pure formatting & derivation helpers for the Hunter Report.
///
/// These functions are independent of Flutter, Firestore and widget state, so
/// they are trivially testable and shared across every report module.
library;

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// Ordinal index of a rank (E = 0 … S = 5). Used by the analysis scoring.
///
/// Note: Hunter Rank itself is now resolved centrally from the player's LEVEL
/// via `RankService`. This pure helper only maps an already-computed rank
/// letter to its ordinal, so it stays Flutter-free and testable.
int rankIndex(String rank) =>
    const ['E', 'D', 'C', 'B', 'A', 'S'].indexOf(rank).clamp(0, 5);

/// Formats an integer with thousands separators (no `intl` dependency).
String fmtInt(num v) {
  final s = v.round().toString();
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

/// Formats a date as e.g. "Jul 13, 2026".
String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Stable calendar-day key (yyyy-MM-dd) used for de-duplicating active days.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Formats a duration in seconds as a compact "Xh Ym" / "Ym" string.
String fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

/// Builds a deterministic, local-only "Report ID" purely for visual polish
/// (e.g. `SR-4F2A-1C9`). Derived from the hunter uid + the current date so it
/// stays stable across a day and requires no backend/storage.
String localReportId(String uid, DateTime date) {
  final seed = '$uid-${dayKey(date)}';
  int hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  final hex = hash.toRadixString(16).toUpperCase().padLeft(7, '0');
  return 'SR-${hex.substring(0, 4)}-${hex.substring(4, 7)}';
}
