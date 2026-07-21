import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/data/repositories/leaderboard_repository.dart';
import 'package:hunter_ascend/services/rank_reward_service.dart';

/// Equips/unequips the single PUBLICLY-VISIBLE badge.
///
/// ## Why this is separate from [EquippedRewardsService]
/// Every other Hunter Rank reward type (title, border, aura, dashboardTheme,
/// reportStyle, profileEffect) stays private, stored in the mutable
/// `hunters/{uid}/equippedRewards/current` document that only the owner can
/// read (see [EquippedRewardsService]). Badges are different: they are
/// meant to be shown publicly on Profile, Dashboard, Global Rankings,
/// Compare Hunters, and Public Hunter Profile.
///
/// To display a badge on those screens with ZERO additional Firestore
/// reads, the equipped badge id is denormalized directly onto the hunter
/// document itself (`hunters/{uid}.equippedBadgeId`) — the same document
/// every one of those screens already reads for level/XP/streak/etc. This
/// service owns exactly that one field.
///
/// ## Why there is no dedicated cache or loader here
/// Unlike [EquippedRewardsService] (which needs its own `.get()` to learn
/// what's equipped), the equipped badge is already present on the
/// `HunterData` object every screen already streams via
/// [HunterRepository.watch()]. There is nothing to separately load or keep
/// in sync — reading `hunter.equippedBadgeId` IS the current state. This
/// service only performs the two write operations, using
/// [HunterRepository.getCached] (the same in-memory snapshot, not a new
/// Firestore read) purely as an idempotency check before writing.
///
/// ## Exactly one badge at a time
/// `equippedBadgeId` is a single scalar field, not a per-type map, so
/// equipping a new badge is a single-field overwrite that atomically
/// replaces (and thus "unequips") whatever badge was previously equipped —
/// there is no separate unequip-then-equip step and no way for two badges
/// to be equipped simultaneously.
///
/// ## Ownership gate
/// [equip] only *reads* [RankRewardService.isOwned] to confirm the badge is
/// actually unlocked before writing — it never mutates the ownership ledger,
/// and owned/claimed rewards remain completely private (unaffected by this
/// service).
class BadgeEquipService {
  BadgeEquipService._();
  static final BadgeEquipService instance = BadgeEquipService._();

  /// Equips [reward] as the publicly-visible badge.
  ///
  /// Validates ownership first via [RankRewardService.isOwned] — a badge
  /// that hasn't been permanently unlocked can never be equipped. Requires
  /// [reward.type] to be [RankRewardType.badge]; any other type is rejected
  /// (this service only ever handles badges — all other reward types keep
  /// using [EquippedRewardsService]).
  ///
  /// ## Idempotency guard
  /// If [reward] is already the equipped badge (per the locally-cached
  /// `HunterData` — no extra Firestore read), this is a no-op that returns
  /// `true` without writing. This mirrors the guard in [unequip] and avoids
  /// a redundant write when the button is tapped on an already-equipped
  /// badge (e.g. a stale widget rebuild or a double-tap).
  ///
  /// Returns `false` (no write performed) if the reward isn't a badge, isn't
  /// owned, or no user is signed in; `true` once the write succeeds (or was
  /// skipped because the badge was already equipped).
  Future<bool> equip(RankReward reward) async {
    if (reward.type != RankRewardType.badge) {
      debugPrint('BadgeEquipService.equip: ${reward.id} is not a badge — refusing to equip.');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    if (!RankRewardService.instance.isOwned(reward.id)) {
      debugPrint('BadgeEquipService.equip: ${reward.id} is not owned — refusing to equip.');
      return false;
    }

    // Idempotency guard: skip the write entirely if this badge is already
    // equipped. HunterRepository.getCached() is synchronous and reads the
    // same in-memory HunterData every screen already has — no extra read.
    if (HunterRepository.instance.getCached()?.equippedBadgeId == reward.id) {
      return true;
    }

    try {
      // A plain field overwrite — this single write both equips the new
      // badge AND unequips whatever badge was equipped before, since only
      // one value can ever be stored here.
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .update({'equippedBadgeId': reward.id});

      // Mark leaderboard cache as stale so Global Rankings reflects the new
      // badge on its next fetch, mirroring XpService.awardXp's same pattern.
      LeaderboardRepository.instance.markStale();

      return true;
    } catch (e) {
      debugPrint('BadgeEquipService.equip ${reward.id}: $e');
      return false;
    }
  }

  /// Unequips the currently-equipped badge (reverting to no badge shown).
  ///
  /// ## Idempotency guard
  /// If nothing is currently equipped (per the locally-cached [HunterData]
  /// — no extra Firestore read), this is a no-op that returns `true`
  /// without writing.
  Future<bool> unequip() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // Idempotency guard: skip the write entirely if no badge is equipped.
    if (HunterRepository.instance.getCached()?.equippedBadgeId == null) {
      return true;
    }

    try {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .update({'equippedBadgeId': FieldValue.delete()});

      // Mark leaderboard cache as stale so Global Rankings reflects the
      // removed badge on its next fetch, mirroring XpService.awardXp's
      // same pattern.
      LeaderboardRepository.instance.markStale();

      return true;
    } catch (e) {
      debugPrint('BadgeEquipService.unequip: $e');
      return false;
    }
  }
}
