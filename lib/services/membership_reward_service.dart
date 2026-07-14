import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Service responsible for claiming membership rewards after a rewarded ad.
///
/// Writes directly to Firestore (no Cloud Functions required — Spark plan
/// compatible). Uses Firestore transactions to prevent race conditions.
///
/// Logic:
/// - Pro: 1 rewarded ad = +1 day membership immediately.
/// - Max: 2 rewarded ads = +1 day membership.
///   - 1st ad: sets pendingMaxRewardAds = 1, no extension yet.
///   - 2nd ad: resets pendingMaxRewardAds = 0, extends +1 day.
///
/// Security:
/// - Only the authenticated user can update their own document.
/// - Firestore Security Rules enforce ownership.
class MembershipRewardService {
  MembershipRewardService._();

  /// The single shared instance.
  static final MembershipRewardService instance = MembershipRewardService._();

  /// Whether a claim is currently in progress.
  final ValueNotifier<bool> isClaiming = ValueNotifier<bool>(false);

  /// Number of milliseconds in one day.
  static const int _oneDayMs = 24 * 60 * 60 * 1000;

  /// Maximum time (ms) allowed between first and second Max ad (24 hours).
  static const int _maxPendingExpiryMs = 24 * 60 * 60 * 1000;

  /// Claims a membership reward after a rewarded ad has been watched.
  ///
  /// [membershipType] must be `"pro"` or `"max"`.
  Future<RewardClaimResult> claimReward(String membershipType) async {
    if (isClaiming.value) {
      return const RewardClaimResult(
        success: false,
        error: 'claim_in_progress',
        message: 'A claim is already in progress.',
      );
    }

    if (membershipType != 'pro' && membershipType != 'max') {
      return const RewardClaimResult(
        success: false,
        error: 'invalid_type',
        message: 'Invalid membership type.',
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RewardClaimResult(
        success: false,
        error: 'unauthenticated',
        message: 'Please sign in to claim your reward.',
      );
    }

    isClaiming.value = true;

    try {
      debugPrint('MembershipRewardService: claiming reward — '
          'type=$membershipType, uid=$uid');

      final docRef =
          FirebaseFirestore.instance.collection('hunters').doc(uid);

      final result = await FirebaseFirestore.instance
          .runTransaction<RewardClaimResult>((txn) async {
        final snapshot = await txn.get(docRef);

        if (!snapshot.exists) {
          return const RewardClaimResult(
            success: false,
            error: 'not_found',
            message: 'Hunter profile not found. Please restart the app.',
          );
        }

        final data = snapshot.data()!;
        final now = DateTime.now().millisecondsSinceEpoch;
        final currentType = (data['membershipType'] ?? 'basic').toString();
        final currentExpiryRaw = data['membershipExpiry'];
        final pendingMax = (data['pendingMaxRewardAds'] ?? 0) as int;
        final pendingStartedAtRaw = data['pendingMaxRewardStartedAt'];

        // Parse current expiry.
        int? currentExpiryMs;
        if (currentExpiryRaw is Timestamp) {
          currentExpiryMs = currentExpiryRaw.millisecondsSinceEpoch;
        }

        // Determine base time for extension.
        // Only extend from existing expiry when the SAME tier is active
        // and not expired. Switching tiers always starts fresh from now.
        int baseTimeMs = now;
        if (currentExpiryMs != null &&
            currentType == membershipType &&
            currentExpiryMs > now) {
          baseTimeMs = currentExpiryMs;
        }

        if (membershipType == 'pro') {
          // PRO: 1 ad = +1 day immediately.
          // Switching from Max → Pro: starts fresh from now (baseTimeMs = now).
          final newExpiryMs = baseTimeMs + _oneDayMs;
          final newExpiry =
              Timestamp.fromMillisecondsSinceEpoch(newExpiryMs);

          txn.update(docRef, {
            'membershipType': 'pro',
            'membershipExpiry': newExpiry,
            'pendingMaxRewardAds': 0,
            'pendingMaxRewardStartedAt': null,
          });

          return RewardClaimResult(
            success: true,
            membershipType: 'pro',
            expiryDate: DateTime.fromMillisecondsSinceEpoch(newExpiryMs)
                .toIso8601String(),
            pendingAds: 0,
          );
        } else {
          // MAX: 2 ads = +1 day.

          // Check pending expiry (24h window).
          int effectivePending = pendingMax;
          if (effectivePending > 0 && pendingStartedAtRaw is Timestamp) {
            final startedAtMs =
                pendingStartedAtRaw.millisecondsSinceEpoch;
            if (now - startedAtMs > _maxPendingExpiryMs) {
              effectivePending = 0; // Expired — reset.
            }
          }

          // If switching from pro, reset pending.
          if (currentType == 'pro') {
            effectivePending = 0;
          }

          if (effectivePending < 1) {
            // First ad — record pending, no extension.
            // Clear membershipExpiry when switching tiers so the second
            // ad starts fresh from now (not from old tier's expiry).
            final Map<String, dynamic> updateData = {
              'membershipType': 'max',
              'pendingMaxRewardAds': 1,
              'pendingMaxRewardStartedAt':
                  Timestamp.fromMillisecondsSinceEpoch(now),
            };
            // If switching FROM a different tier, clear the old expiry.
            if (currentType != 'max') {
              updateData['membershipExpiry'] = null;
            }
            txn.update(docRef, updateData);

            return const RewardClaimResult(
              success: true,
              membershipType: 'max',
              pendingAds: 1,
              message:
                  'First ad completed. Watch one more to earn +1 day.',
            );
          } else {
            // Second ad — grant +1 day.
            final newExpiryMs = baseTimeMs + _oneDayMs;
            final newExpiry =
                Timestamp.fromMillisecondsSinceEpoch(newExpiryMs);

            txn.update(docRef, {
              'membershipType': 'max',
              'membershipExpiry': newExpiry,
              'pendingMaxRewardAds': 0,
              'pendingMaxRewardStartedAt': null,
            });

            return RewardClaimResult(
              success: true,
              membershipType: 'max',
              expiryDate:
                  DateTime.fromMillisecondsSinceEpoch(newExpiryMs)
                      .toIso8601String(),
              pendingAds: 0,
            );
          }
        }
      });

      // Reload membership to reflect changes in UI.
      if (result.success) {
        await MembershipService.instance.reload();
      }

      debugPrint('MembershipRewardService: claim result — '
          'success=${result.success}, type=${result.membershipType}, '
          'pending=${result.pendingAds}, expiry=${result.expiryDate}');

      return result;
    } catch (e) {
      debugPrint('MembershipRewardService: error — $e');
      return const RewardClaimResult(
        success: false,
        error: 'firestore_error',
        message: 'Could not update membership. Please try again.',
      );
    } finally {
      isClaiming.value = false;
    }
  }
}
