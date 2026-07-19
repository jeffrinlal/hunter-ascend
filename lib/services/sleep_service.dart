import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Ambience options for the sleep mission.
enum SleepAmbience { rain, ocean, forest, campfire, whiteNoise, nightCrickets }

/// Duration options for ambience playback.
enum AmbienceDuration { thirtyMin, fortyFiveMin, sixtyMin, untilStopped }

/// Result of completing a sleep session.
class SleepResult {
  const SleepResult({
    required this.durationMinutes,
    required this.xpAwarded,
    required this.leveledUp,
  });

  final int durationMinutes;
  final int xpAwarded;
  final bool leveledUp;
}

/// Manages sleep mission state, persistence, and XP rewards.
///
/// State is persisted via SharedPreferences so it survives app restarts.
/// The elapsed timer is purely timestamp-based (DateTime.now() - sleepStartTime)
/// and does not rely on any background execution or periodic Timer.
class SleepService {
  SleepService._();
  static final SleepService instance = SleepService._();

  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const String _keyActive = 'sleep_active';
  static const String _keyStartTime = 'sleep_start_time';
  static const String _keyAmbience = 'sleep_ambience';
  static const String _keyAmbienceDuration = 'sleep_ambience_duration';
  static const String _keyLastRewardDate = 'sleep_last_reward_date';

  // ── State ───────────────────────────────────────────────────────────────
  bool _active = false;
  DateTime? _startTime;
  SleepAmbience? _selectedAmbience;
  AmbienceDuration? _selectedAmbienceDuration;
  String? _lastRewardDate;

  /// Fires when sleep state changes (start/stop).
  final ValueNotifier<bool> stateNotifier = ValueNotifier<bool>(false);

  // ── Public getters ──────────────────────────────────────────────────────

  bool get isActive => _active;
  DateTime? get startTime => _startTime;
  SleepAmbience? get selectedAmbience => _selectedAmbience;
  AmbienceDuration? get selectedAmbienceDuration => _selectedAmbienceDuration;

  /// Whether the user has already been rewarded today.
  bool get hasRewardedToday {
    final today = DateTime.now().toString().substring(0, 10);
    return _lastRewardDate == today;
  }

  /// Current elapsed duration (returns Duration.zero if not active).
  Duration get elapsed {
    if (!_active || _startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  // ── Initialization ──────────────────────────────────────────────────────

  /// Loads persisted state from SharedPreferences. Call once at app startup.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _active = prefs.getBool(_keyActive) ?? false;
    final startMs = prefs.getInt(_keyStartTime);
    _startTime = startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : null;
    final ambienceIndex = prefs.getInt(_keyAmbience);
    _selectedAmbience = ambienceIndex != null && ambienceIndex < SleepAmbience.values.length
        ? SleepAmbience.values[ambienceIndex]
        : null;
    final durationIndex = prefs.getInt(_keyAmbienceDuration);
    _selectedAmbienceDuration = durationIndex != null && durationIndex < AmbienceDuration.values.length
        ? AmbienceDuration.values[durationIndex]
        : null;
    _lastRewardDate = prefs.getString(_keyLastRewardDate);
    stateNotifier.value = _active;
  }

  // ── Start Sleep ─────────────────────────────────────────────────────────

  /// Starts a sleep session with the selected ambience settings.
  Future<void> startSleep({
    required SleepAmbience ambience,
    required AmbienceDuration duration,
  }) async {
    _active = true;
    _startTime = DateTime.now();
    _selectedAmbience = ambience;
    _selectedAmbienceDuration = duration;
    stateNotifier.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActive, true);
    await prefs.setInt(_keyStartTime, _startTime!.millisecondsSinceEpoch);
    await prefs.setInt(_keyAmbience, ambience.index);
    await prefs.setInt(_keyAmbienceDuration, duration.index);
  }

  // ── Stop Sleep ──────────────────────────────────────────────────────────

  /// Stops the current sleep session and awards XP based on duration.
  /// Returns null if no session was active or already rewarded today.
  Future<SleepResult?> stopSleep() async {
    if (!_active || _startTime == null) return null;

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);
    final minutes = duration.inMinutes;

    // Reset state.
    _active = false;
    final startTimeCopy = _startTime;
    _startTime = null;
    _selectedAmbience = null;
    _selectedAmbienceDuration = null;
    stateNotifier.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActive, false);
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyAmbience);
    await prefs.remove(_keyAmbienceDuration);

    // Check if already rewarded today.
    final today = DateTime.now().toString().substring(0, 10);
    if (_lastRewardDate == today) {
      return SleepResult(durationMinutes: minutes, xpAwarded: 0, leveledUp: false);
    }

    // Calculate XP reward.
    final xp = _calculateXp(minutes);
    if (xp <= 0) {
      return SleepResult(durationMinutes: minutes, xpAwarded: 0, leveledUp: false);
    }

    // Award XP.
    final result = await XpService.instance.awardXp(amount: xp);

    // Record reward date.
    _lastRewardDate = today;
    await prefs.setString(_keyLastRewardDate, today);

    return SleepResult(
      durationMinutes: minutes,
      xpAwarded: xp,
      leveledUp: result?.leveledUp ?? false,
    );
  }

  // ── Cancel (no reward) ──────────────────────────────────────────────────

  /// Cancels the current sleep session without awarding XP.
  Future<void> cancelSleep() async {
    _active = false;
    _startTime = null;
    _selectedAmbience = null;
    _selectedAmbienceDuration = null;
    stateNotifier.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActive, false);
    await prefs.remove(_keyStartTime);
    await prefs.remove(_keyAmbience);
    await prefs.remove(_keyAmbienceDuration);
  }

  // ── XP Calculation ──────────────────────────────────────────────────────

  /// Returns the XP to award based on sleep duration in minutes.
  static int _calculateXp(int minutes) {
    final hours = minutes / 60.0;
    if (hours < 4) return 0;
    if (hours < 6) return 10;
    if (hours < 8) return 25;
    if (hours <= 10) return 40;
    return 15; // >10 hours — discourage excessive sleep
  }

  /// Returns a human-readable description of the XP tier for a given duration.
  static String xpTierDescription(int minutes) {
    final hours = minutes / 60.0;
    if (hours < 4) return 'Sleep at least 4 hours to earn XP';
    if (hours < 6) return '+10 XP (4-6 hours)';
    if (hours < 8) return '+25 XP (6-8 hours)';
    if (hours <= 10) return '+40 XP (8-10 hours)';
    return '+15 XP (>10 hours)';
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Human-readable ambience name.
  static String ambienceName(SleepAmbience ambience) {
    switch (ambience) {
      case SleepAmbience.rain: return 'Rain';
      case SleepAmbience.ocean: return 'Ocean';
      case SleepAmbience.forest: return 'Forest';
      case SleepAmbience.campfire: return 'Campfire';
      case SleepAmbience.whiteNoise: return 'White Noise';
      case SleepAmbience.nightCrickets: return 'Night Crickets';
    }
  }

  /// Icon for an ambience type.
  static IconData ambienceIcon(SleepAmbience ambience) {
    switch (ambience) {
      case SleepAmbience.rain: return Icons.water_drop_outlined;
      case SleepAmbience.ocean: return Icons.waves_outlined;
      case SleepAmbience.forest: return Icons.park_outlined;
      case SleepAmbience.campfire: return Icons.local_fire_department_outlined;
      case SleepAmbience.whiteNoise: return Icons.graphic_eq_outlined;
      case SleepAmbience.nightCrickets: return Icons.nights_stay_outlined;
    }
  }

  /// Human-readable duration label.
  static String durationLabel(AmbienceDuration duration) {
    switch (duration) {
      case AmbienceDuration.thirtyMin: return '30 min';
      case AmbienceDuration.fortyFiveMin: return '45 min';
      case AmbienceDuration.sixtyMin: return '60 min';
      case AmbienceDuration.untilStopped: return 'Until stopped';
    }
  }
}
