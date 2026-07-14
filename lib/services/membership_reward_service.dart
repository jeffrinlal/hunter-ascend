import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Result of a membership reward claim.
class RewardClaimResult {
  final bool success;
  final String? membershipType;
  final String? expiryDate;
  final int? pendingAds;
  final String? error;
  final String? message;

  const RewardClaimResult({
    required this.success,
    this.membershipType,
    this.expiryDate,
    this.pendingAds,
    this.error,
    this.message,
  });

  /// Whether this is a partial Max claim (first of two ads).
  bool get isPendingMax => success && pendingAds == 1;

  /// Whether membership time was actually granted.
  bool get wasExtended => success && expiryDate != null;
}

/// Service responsible for claiming membership rewards via Cloud Functions.
///
/// This service:
/// - Calls the `claimMembershipReward` Cloud Function after a rewarded ad.
/// - Refreshes [MembershipService] on success.
/// - Returns structured results for the UI to display.
///
/// This service does NOT:
/// - Grant membership locally.
/// - Write to Firestore directly.
/// - Show or manage rewarded ads (that's the UI layer's job).
class MembershipRewardService {
  MembershipRewardService._();

  /// The single shared instance.
  static final MembershipRewardService instance = MembershipRewardService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Whether a claim is currently in progress.
  final ValueNotifier<bool> isClaiming = ValueNotifier<bool>(false);

  /// Claims a membership reward after a rewarded ad has been watched.
  ///
  /// [membershipType] must be `"pro"` or `"max"`.
  ///
  /// For Pro: 1 call = +1 day granted immediately.
  /// For Max: 1st call = pending (returns pendingAds=1).
  ///          2nd call = +1 day granted (returns pendingAds=0).
  ///
  /// On success, automatically reloads [MembershipService] so the UI
  /// reflects the updated membership state.
  ///
  /// Returns a [RewardClaimResult] with the outcome.
  Future<RewardClaimResult> claimReward(String membershipType) async {
    if (isClaiming.value) {
      return const RewardClaimResult(
        success: false,
        error: 'claim_in_progress',
        message: 'A claim is already in progress.',
      );
    }

    isClaiming.value = true;

    try {
      final callable = _functions.httpsCallable('claimMembershipReward');
      final response = await callable.call<Map<String, dynamic>>({
        'membershipType': membershipType,
      });

      final data = response.data;
      final success = data['success'] == true;

      final result = RewardClaimResult(
        success: success,
        membershipType: data['membershipType']?.toString(),
        expiryDate: data['expiryDate']?.toString(),
        pendingAds: data['pendingAds'] is int ? data['pendingAds'] as int : null,
        error: data['error']?.toString(),
        message: data['message']?.toString(),
      );

      // Reload membership if time was actually granted or type changed.
      if (success) {
        await MembershipService.instance.reload();
      }

      debugPrint('MembershipRewardService: claim result — '
          'success=$success, type=${result.membershipType}, '
          'pending=${result.pendingAds}, expiry=${result.expiryDate}');

      return result;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('MembershipRewardService: Cloud Function error — '
          '${e.code}: ${e.message}');
      return RewardClaimResult(
        success: false,
        error: e.code,
        message: _userFriendlyError(e.code),
      );
    } catch (e) {
      debugPrint('MembershipRewardService: unexpected error — $e');
      return const RewardClaimResult(
        success: false,
        error: 'network_error',
        message: 'Could not connect to the server. Please check your '
            'internet connection and try again.',
      );
    } finally {
      isClaiming.value = false;
    }
  }

  /// Maps Cloud Function error codes to user-friendly messages.
  String _userFriendlyError(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Please sign in to claim your reward.';
      case 'invalid-argument':
        return 'Invalid request. Please try again.';
      case 'not-found':
        return 'Hunter profile not found. Please restart the app.';
      case 'too_fast':
        return 'Please wait a moment before claiming another reward.';
      case 'internal':
        return 'Server error. Please try again later.';
      default:
        return 'Failed to claim reward. Please try again.';
    }
  }
}
