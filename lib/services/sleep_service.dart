import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Ambience options for the sleep mission.
enum SleepAmbience { none, rain, ocean, forest, campfire, whiteNoise, nightCrickets }

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
  static const String _keyLastChosenAmbience = 'sleep_last_chosen_ambience';
  static const String _keyLastChosenDuration = 'sleep_last_chosen_duration';

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

  /// The user's last chosen ambience (persisted). Defaults to [SleepAmbience.none].
  SleepAmbience _lastChosenAmbience = SleepAmbience.none;
  AmbienceDuration _lastChosenDuration = AmbienceDuration.thirtyMin;

  SleepAmbience get lastChosenAmbience => _lastChosenAmbience;
  AmbienceDuration get lastChosenDuration => _lastChosenDuration;

  /// Saves the user's ambience/duration choice for next time.
  Future<void> saveLastChoice(SleepAmbience ambience, AmbienceDuration duration) async {
    _lastChosenAmbience = ambience;
    _lastChosenDuration = duration;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastChosenAmbience, ambience.index);
    await prefs.setInt(_keyLastChosenDuration, duration.index);
  }

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
    // Load last chosen ambience/duration preferences.
    final lastAmbienceIdx = prefs.getInt(_keyLastChosenAmbience);
    _lastChosenAmbience = lastAmbienceIdx != null && lastAmbienceIdx < SleepAmbience.values.length
        ? SleepAmbience.values[lastAmbienceIdx]
        : SleepAmbience.none;
    final lastDurationIdx = prefs.getInt(_keyLastChosenDuration);
    _lastChosenDuration = lastDurationIdx != null && lastDurationIdx < AmbienceDuration.values.length
        ? AmbienceDuration.values[lastDurationIdx]
        : AmbienceDuration.thirtyMin;
    stateNotifier.value = _active;
  }

  // ── Start Sleep ─────────────────────────────────────────────────────────

  /// Starts a sleep session with the selected ambience settings.
  /// Returns immediately without changes if a session is already active.
  Future<void> startSleep({
    required SleepAmbience ambience,
    required AmbienceDuration duration,
  }) async {
    if (_active) return; // Prevent overwriting an existing session.

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
    final minutes = duration.inMinutes.clamp(0, 1440); // Cap at 24h; ignore negative (clock changes).

    // Reset state.
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

  /// Removes every account-scoped sleep value after permanent account
  /// deletion so a new account on this device cannot inherit progress,
  /// rewards, or the previous hunter's saved choices.
  Future<void> clearAccountData() async {
    _active = false;
    _startTime = null;
    _selectedAmbience = null;
    _selectedAmbienceDuration = null;
    _lastRewardDate = null;
    _lastChosenAmbience = SleepAmbience.none;
    _lastChosenDuration = AmbienceDuration.thirtyMin;
    stateNotifier.value = false;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyActive),
      prefs.remove(_keyStartTime),
      prefs.remove(_keyAmbience),
      prefs.remove(_keyAmbienceDuration),
      prefs.remove(_keyLastRewardDate),
      prefs.remove(_keyLastChosenAmbience),
      prefs.remove(_keyLastChosenDuration),
    ]);
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
      case SleepAmbience.none: return 'No Ambience';
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
      case SleepAmbience.none: return Icons.volume_off_outlined;
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
