import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/data/achievements_catalog.dart';
import 'package:hunter_ascend/data/models/achievement.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';

/// Resolves achievement unlock state from the hunter's existing stats and
/// remembers unlocks locally (SharedPreferences) so they stay unlocked with an
/// unlock date — even if the underlying stat later drops (e.g. a broken
/// streak). No Firestore fields are added.
class AchievementsService {
  AchievementsService._();
  static final AchievementsService instance = AchievementsService._();

  static const String _prefsKey = 'unlockedAchievements_v1';

  /// id -> ISO-8601 unlock timestamp.
  final Map<String, String> _unlocked = {};
  bool _loaded = false;
  SharedPreferences? _prefs;

  /// Loads persisted unlocks once. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) => _unlocked[k] = v.toString());
      } catch (_) {}
    }
    _loaded = true;
  }

  void _persist() {
    _prefs?.setString(_prefsKey, jsonEncode(_unlocked));
  }

  /// Evaluates the whole catalog against [h]. Newly satisfied achievements are
  /// recorded (sticky) with the current timestamp and persisted. Returns the
  /// resolved status for every achievement.
  List<AchievementStatus> evaluate(HunterData h) {
    final now = DateTime.now();
    bool changed = false;
    final out = <AchievementStatus>[];

    for (final a in kAchievements) {
      if (a.isDone(h) && !_unlocked.containsKey(a.id)) {
        _unlocked[a.id] = now.toIso8601String();
        changed = true;
      }
      final unlockedAtStr = _unlocked[a.id];
      final unlocked = unlockedAtStr != null;
      out.add(AchievementStatus(
        achievement: a,
        unlocked: unlocked,
        unlockedAt: unlockedAtStr != null ? DateTime.tryParse(unlockedAtStr) : null,
        progress: unlocked ? 1.0 : a.progressOf(h),
      ));
    }

    if (changed) _persist();
    return out;
  }
}
