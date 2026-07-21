import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/data/rank_rewards_catalog.dart';
import 'package:hunter_ascend/services/rank_reward_service.dart';

// NOTE ON LIVE UI REFRESH: this service now extends [ChangeNotifier] and
// notifies listeners on every equip/unequip and on load/clear, mirroring
// [RankRewardService]'s notifier so both halves of the Rewards tab's data
// (ownership + equipped state) can drive the same live UI refresh via a
// single [ListenableBuilder]/[Listenable.merge]. No behavior, persistence,
// or ownership-gating change.

/// Tracks the player's CURRENTLY EQUIPPED cosmetic per [RankRewardType],
/// for every type EXCEPT [RankRewardType.badge].
///
/// ## Badges are handled separately
/// The badge type is deliberately excluded from this service. Badges are
/// meant to be shown publicly (Profile, Dashboard, Global Rankings, Compare
/// Hunters, Public Hunter Profile), so they are equipped via the much
/// simpler [BadgeEquipService], which writes a single denormalized
/// `equippedBadgeId` field directly on the hunter document instead of this
/// service's private, owner-only-readable `equippedRewards` subcollection.
/// [equip]/[unequip] both refuse [RankRewardType.badge] — see their doc
/// comments.
///
/// ## Ownership vs. equipped — why these are two separate services
/// [RankRewardService] is the permanent ownership ledger: once a reward is
/// granted it is written ONCE to `hunters/{uid}/rankRewards/{rewardId}` and
/// that record is never updated or deleted again (enforced by the Firestore
/// rules — `create`-only, no `update`, no `delete`).
///
/// This service is the OPPOSITE by design: it stores which single reward is
/// currently *active* per type (one title, one border, one aura, one
/// dashboard theme, one report style, one profile effect — badge excluded,
/// see above), in a single mutable document —
/// `hunters/{uid}/equippedRewards/current`. Equipping a different unlocked
/// cosmetic is a normal, frequent, freely-repeatable action, so this
/// document supports `update` (see firestore.rules).
///
/// Equipping/unequipping here NEVER writes to `rankRewards` — ownership
/// records are completely untouched by cosmetic switches. Conversely,
/// [RankRewardService] never writes to `equippedRewards` — granting a reward
/// does not auto-equip it, keeping the two concerns fully decoupled.
///
/// ## Ownership gate
/// [equip] only *reads* [RankRewardService.isOwned] to validate that the
/// requested reward is actually unlocked before writing — it never mutates
/// ownership state, and [RankRewardService]'s granting logic is completely
/// unaware this service exists.
class EquippedRewardsService extends ChangeNotifier {
  EquippedRewardsService._();
  static final EquippedRewardsService instance = EquippedRewardsService._();

  static const String _subcollectionName = 'equippedRewards';
  static const String _docId = 'current';

  /// `RankRewardType.name` -> equipped reward id, for the currently-loaded
  /// user. A type with no entry means "nothing equipped" (default look).
  final Map<String, String> _equipped = {};

  bool _loaded = false;
  String? _loadedForUid;

  /// The in-flight load, if any. Lets concurrent callers (e.g. several
  /// widgets calling `ensureLoadedForCurrentUser` from `initState` on the
  /// same frame) await the SAME Firestore read instead of each issuing their
  /// own redundant `.get()`.
  Future<void>? _loadingFuture;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Loads the current equip selections for the signed-in user, once per
  /// user. Safe to call repeatedly and concurrently (e.g. from `initState` of
  /// multiple widgets) — only ever performs a SINGLE in-flight Firestore read
  /// per uid; overlapping callers await that same read.
  Future<void> ensureLoadedForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_loaded && _loadedForUid == uid) return;

    // Another call is already loading — await it, then re-check whether it
    // actually satisfied THIS uid (it may have been a stale load for a
    // different user, e.g. if logout/login happened mid-flight). If not,
    // fall through and start a fresh load for the current uid.
    if (_loadingFuture != null) {
      await _loadingFuture;
      if (_loaded && _loadedForUid == uid) return;
    }

    final future = _loadFor(uid);
    _loadingFuture = future;
    try {
      await future;
    } finally {
      _loadingFuture = null;
    }
  }

  Future<void> _loadFor(String uid) async {
    _equipped.clear();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .doc(_docId)
          .get();
      final data = snap.data();
      if (data != null) {
        data.forEach((key, value) {
          if (value is String) _equipped[key] = value;
        });
      }
    } catch (e) {
      debugPrint('EquippedRewardsService load: $e');
      return; // leave _loaded false so a later call retries
    }

    _loadedForUid = uid;
    _loaded = true;
    notifyListeners();
  }

  /// Clears in-memory equip state. Call on logout / account switch so the
  /// next signed-in hunter starts from a clean slate (mirrors
  /// [RankRewardService.clearCache]). Does not touch Firestore.
  void clearCache() {
    _equipped.clear();
    _loaded = false;
    _loadedForUid = null;
    notifyListeners();
    // Do NOT null out _loadingFuture here: an in-flight load for the
    // PREVIOUS user may still resolve after logout. Its `_loadFor` will
    // still write `_loadedForUid`/`_loaded`, but the next
    // `ensureLoadedForCurrentUser` call for the NEW user checks
    // `_loadedForUid == uid`, which will correctly mismatch and trigger a
    // fresh load — so a stale in-flight future can never leak another
    // user's equipped state into the new session.
  }

  // ── Read-only accessors ──────────────────────────────────────────────────

  /// The reward id currently equipped for [type], or `null` if none.
  String? equippedIdFor(RankRewardType type) => _equipped[type.name];

  /// The full [RankReward] currently equipped for [type], or `null` if none
  /// is equipped (or the stored id no longer matches a catalog entry).
  ///
  /// Resolves via the shared [kRankRewardsById] O(1) map rather than a linear
  /// scan of the catalog.
  RankReward? equippedRewardFor(RankRewardType type) {
    final id = equippedIdFor(type);
    if (id == null) return null;
    return kRankRewardsById[id];
  }

  /// Whether [reward] is the one currently equipped for its type.
  bool isEquipped(RankReward reward) => equippedIdFor(reward.type) == reward.id;

  // ── Equip / unequip ──────────────────────────────────────────────────────

  /// Equips [reward] as the active cosmetic for its type.
  ///
  /// Refuses [RankRewardType.badge] — badges are equipped exclusively via
  /// [BadgeEquipService], never through this subcollection. Validates
  /// OWNERSHIP first via [RankRewardService.isOwned] — a reward that hasn't
  /// been permanently unlocked can never be equipped. Returns `false` (no
  /// write performed) if the reward is a badge, isn't owned, or no user is
  /// signed in; `true` once the equip write succeeds.
  ///
  /// This only ever writes to `equippedRewards` — [RankRewardService]'s
  /// ownership ledger is read-only from this method's perspective and is
  /// never modified here.
  Future<bool> equip(RankReward reward) async {
    if (reward.type == RankRewardType.badge) {
      debugPrint('EquippedRewardsService.equip: badges are handled by BadgeEquipService — refusing.');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    if (!RankRewardService.instance.isOwned(reward.id)) {
      debugPrint('EquippedRewardsService.equip: ${reward.id} is not owned — refusing to equip.');
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .doc(_docId)
          .set({
        reward.type.name: reward.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: preserves every OTHER type's equipped selection

      _equipped[reward.type.name] = reward.id;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('EquippedRewardsService.equip ${reward.id}: $e');
      return false;
    }
  }

  /// Unequips whatever is currently active for [type] (reverting to the
  /// default look for that slot). A no-op if nothing is equipped for [type].
  ///
  /// Refuses [RankRewardType.badge] — see [equip].
  Future<bool> unequip(RankRewardType type) async {
    if (type == RankRewardType.badge) {
      debugPrint('EquippedRewardsService.unequip: badges are handled by BadgeEquipService — refusing.');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (!_equipped.containsKey(type.name)) return true; // already unequipped

    try {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .doc(_docId)
          .set({
        type.name: FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _equipped.remove(type.name);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('EquippedRewardsService.unequip ${type.name}: $e');
      return false;
    }
  }
}
