import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Manages the daily morning motivation reward.
///
/// Awards XP once per calendar day when the user claims their reward.
/// Persists the last claim date via SharedPreferences.
class DailyRewardService {
  DailyRewardService._();
  static final DailyRewardService instance = DailyRewardService._();

  static const String _keyLastClaimDate = 'daily_reward_last_claim_date';
  static const int rewardXp = 10;

  String? _lastClaimDate;
  bool _initialized = false;

  /// Initializes the service by reading the last claim date from prefs.
  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _lastClaimDate = prefs.getString(_keyLastClaimDate);
    _initialized = true;
  }

  /// Whether the user has already claimed today's reward.
  bool get hasClaimedToday {
    final today = DateTime.now().toString().substring(0, 10);
    return _lastClaimDate == today;
  }

  /// Whether the daily reward dialog should be shown.
  bool get shouldShowReward => _initialized && !hasClaimedToday;

  /// Claims today's daily reward. Returns the XpAwardResult, or null if
  /// already claimed or XP award fails.
  Future<XpAwardResult?> claimReward() async {
    if (hasClaimedToday) return null;

    final result = await XpService.instance.awardXp(amount: rewardXp);

    // Record the claim date regardless of XP result to prevent retries.
    final today = DateTime.now().toString().substring(0, 10);
    _lastClaimDate = today;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastClaimDate, today);

    return result;
  }
}
