import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/data/models/fitness_plan.dart';

/// Result of a plan unlock claim.
class PlanUnlockResult {
  final bool success;
  final String? planId;
  final int? durationDays;
  final String? expiryDate;
  final String? error;
  final String? message;

  const PlanUnlockResult({
    required this.success,
    this.planId,
    this.durationDays,
    this.expiryDate,
    this.error,
    this.message,
  });

  /// Whether the plan was successfully unlocked.
  bool get wasUnlocked => success && expiryDate != null;
}

/// Service responsible for claiming plan unlocks after a rewarded ad.
///
/// Follows the exact same pattern as [MembershipRewardService]:
/// - Singleton instance.
/// - Writes directly to Firestore (no Cloud Functions required — Spark plan
///   compatible). Uses Firestore transactions to prevent race conditions.
/// - Uses a [ValueNotifier] to track in-progress claims.
///
/// ## Firestore path
/// `hunters/{uid}/planUnlocks/{planId}` subcollection.
///
/// ## Fields per unlock document
/// - `planId` (String): the plan's unique id.
/// - `durationDays` (int): days the unlock is valid (data-driven).
/// - `unlockedAt` (Timestamp): when the ad was completed.
/// - `expiresAt` (Timestamp): `unlockedAt + durationDays` — when access
///   expires.
///
/// ## Expiry
/// Unlike the membership ad-unlock (fixed 24h), the plan unlock duration is
/// **data-driven** — it matches the plan's own [FitnessPlan.durationDays]
/// (7, 14, 30, 60, or 90 days).
///
/// ## Security
/// - Only the authenticated user can update their own document.
/// - Firestore Security Rules enforce ownership.
class PlanShopService {
  PlanShopService._();

  /// The single shared instance.
  static final PlanShopService instance = PlanShopService._();

  /// Whether a claim is currently in progress.
  final ValueNotifier<bool> isClaiming = ValueNotifier<bool>(false);

  /// Firestore collection where hunter documents are stored.
  static const String _huntersCollection = 'hunters';

  /// Subcollection under each hunter doc for plan unlocks.
  static const String _planUnlocksSubcollection = 'planUnlocks';

  /// Claims a plan unlock after a rewarded ad has been watched.
  ///
  /// Writes `unlockedAt = now` and `expiresAt = now + plan.durationDays`
  /// to `hunters/{uid}/planUnlocks/{planId}`.
  Future<PlanUnlockResult> claimPlanUnlock(FitnessPlan plan) async {
    if (isClaiming.value) {
      return const PlanUnlockResult(
        success: false,
        error: 'claim_in_progress',
        message: 'A claim is already in progress.',
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const PlanUnlockResult(
        success: false,
        error: 'unauthenticated',
        message: 'Please sign in to claim your reward.',
      );
    }

    isClaiming.value = true;

    try {
      debugPrint('PlanShopService: claiming unlock — '
          'planId=${plan.id}, durationDays=${plan.durationDays}, uid=$uid');

      final docRef = FirebaseFirestore.instance
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_planUnlocksSubcollection)
          .doc(plan.id);

      final result =
          await FirebaseFirestore.instance.runTransaction<PlanUnlockResult>(
        (txn) async {
          final now = DateTime.now().millisecondsSinceEpoch;
          final expiryMs = now + (plan.durationDays * 24 * 60 * 60 * 1000);

          txn.set(docRef, {
            'planId': plan.id,
            'durationDays': plan.durationDays,
            'unlockedAt': Timestamp.fromMillisecondsSinceEpoch(now),
            'expiresAt': Timestamp.fromMillisecondsSinceEpoch(expiryMs),
          });

          return PlanUnlockResult(
            success: true,
            planId: plan.id,
            durationDays: plan.durationDays,
            expiryDate: DateTime.fromMillisecondsSinceEpoch(expiryMs)
                .toIso8601String(),
          );
        },
      );

      debugPrint('PlanShopService: claim result — '
          'success=${result.success}, planId=${result.planId}, '
          'expiry=${result.expiryDate}');

      return result;
    } catch (e) {
      debugPrint('PlanShopService: error — $e');
      return const PlanUnlockResult(
        success: false,
        error: 'firestore_error',
        message: 'Could not unlock plan. Please try again.',
      );
    } finally {
      isClaiming.value = false;
    }
  }

  /// Returns `true` if the plan is currently unlocked and not expired.
  Future<bool> isPlanUnlocked(String planId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_planUnlocksSubcollection)
          .doc(planId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final expiresAtRaw = data['expiresAt'];
      if (expiresAtRaw is Timestamp) {
        return expiresAtRaw.toDate().isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      debugPrint('PlanShopService.isPlanUnlocked: $e');
      return false;
    }
  }

  /// Returns a real-time stream for a single plan's unlock document.
  ///
  /// The Shop screen uses this in a [StreamBuilder] to reactively update
  /// locked/unlocked/expired state without polling. Returns an empty
  /// stream (no emissions) when there is no signed-in user so the UI
  /// safely defaults to the locked state.
  Stream<DocumentSnapshot<Map<String, dynamic>>> planUnlockStream(
      String planId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection(_huntersCollection)
        .doc(uid)
        .collection(_planUnlocksSubcollection)
        .doc(planId)
        .snapshots();
  }

  /// Parses an unlock snapshot into a typed state.
  ///
  /// Returns `null` when there is no valid unlock document.
  /// Callers should also check [PlanUnlockState.isExpired] / [isActive].
  static PlanUnlockState? stateFromSnapshot(
      DocumentSnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null || !snapshot.exists) return null;

    final data = snapshot.data()!;
    final expiresAtRaw = data['expiresAt'];
    if (expiresAtRaw is! Timestamp) return null;

    final expiresAt = expiresAtRaw.toDate();
    final unlockedAtRaw = data['unlockedAt'];
    final unlockedAt = unlockedAtRaw is Timestamp
        ? unlockedAtRaw.toDate()
        : DateTime.now();

    final isExpired = expiresAt.isBefore(DateTime.now());

    return PlanUnlockState(
      unlockedAt: unlockedAt,
      expiresAt: expiresAt,
      isExpired: isExpired,
    );
  }
}

/// Typed snapshot of a plan's current unlock state.
class PlanUnlockState {
  final DateTime unlockedAt;
  final DateTime expiresAt;
  final bool isExpired;

  const PlanUnlockState({
    required this.unlockedAt,
    required this.expiresAt,
    required this.isExpired,
  });

  /// Whether the plan is currently viewable (unlocked and not expired).
  bool get isActive => !isExpired;
}
