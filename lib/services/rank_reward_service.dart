import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/data/rank_rewards_catalog.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Grants and tracks permanent Hunter Rank rewards.
///
/// ## What this service does NOT do
/// - It never computes rank or level — it only *reads* the level already
///   resolved by [HunterData]/[RankService] (`RankService` remains the single
///   source of truth for rank calculation).
/// - It never touches `xp`/`level`/any XP field. Rewards are stored
///   completely separately from progression, in a dedicated Firestore
///   subcollection: `hunters/{uid}/rankRewards/{rewardId}`.
///
/// ## How permanence + no-duplicates is guaranteed
/// The Firestore rules make `rankRewards` a `create`-only subcollection (no
/// `update`, no `delete`). Combined with using the reward's stable [id] as
/// the document ID, this means:
/// - A reward can be granted (created) exactly once, ever.
/// - If two devices/sessions race to grant the same reward, only the FIRST
///   `create` succeeds server-side — Firestore itself rejects the second as
///   an `update` (since the doc now exists), so duplicates are structurally
///   impossible even without any local locking.
/// - Rewards can never be silently removed by a later sync (no `update`, no
///   `delete` — permanent by construction).
///
/// ## Automatic granting (no manual triggers, no migration needed)
/// This service binds to [FirebaseAuth.authStateChanges] (mirroring
/// [MembershipService]'s proven pattern) and, for the signed-in user, taps
/// into the ALREADY-ACTIVE [HunterRepository.watch] stream — no new Firestore
/// `.snapshots()` listener is created. Every time the hunter document updates
/// (including the very first load), it re-syncs rewards for the current
/// level, so:
/// - New players unlock rewards the moment they cross a rank threshold.
/// - Existing players automatically receive every reward they already
///   qualify for on their very next data refresh — no admin script, no
///   Firestore migration.
class RankRewardService {
  RankRewardService._();
  static final RankRewardService instance = RankRewardService._();

  static const String _subcollectionName = 'rankRewards';

  /// Reward IDs already owned by the currently-loaded user (permanent).
  final Set<String> _ownedRewardIds = {};

  /// Reward id -> the `grantedAt` timestamp read back from Firestore, for the
  /// currently-loaded user. Populated purely from the existing `grantedAt`
  /// field already written by [_grantReward] — no new Firestore field, no
  /// change to what is stored or how granting works. Used by
  /// [grantedAtFor] so reward-inventory UI can show "unlocked on ...".
  final Map<String, DateTime> _grantedAt = {};

  bool _loaded = false;
  String? _loadedForUid;
  int _lastSyncedLevel = -1;
  bool _syncing = false;

  /// The in-flight ownership load, if any — lets concurrent callers (e.g.
  /// multiple widgets calling `ensureLoadedForCurrentUser`/`syncForLevel` on
  /// the same frame) await the SAME Firestore read instead of each issuing
  /// their own redundant `.get()`.
  Future<void>? _loadingFuture;

  bool _authListenerBound = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<HunterData?>? _hunterSub;
  String? _boundUid;

  // ── Public: lifecycle ───────────────────────────────────────────────────

  /// Starts automatic rank-reward granting for the app session. Call once
  /// (e.g. in `main()`, alongside `MembershipService.instance.loadMembership()`).
  /// Safe to call multiple times — binds its auth listener at most once.
  void start() {
    if (_authListenerBound) return;
    _authListenerBound = true;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return; // logout is handled explicitly via clearCache()
      if (_boundUid == user.uid) return; // already tracking this uid
      _bindHunterStream(user.uid);
    });

    // Also bind immediately if a user is already signed in when start() is
    // called (mirrors the createHunterProfile()/loadMembership() ordering in
    // main(), where the current user is already known before this runs).
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) _bindHunterStream(current.uid);
  }

  /// Clears all in-memory state and unsubscribes from the hunter stream.
  /// Call on logout so the next signed-in hunter starts from a clean slate.
  /// The `authStateChanges` binding itself stays active so the NEXT login is
  /// picked up automatically (matches `MembershipService.clearCache`).
  void clearCache() {
    _hunterSub?.cancel();
    _hunterSub = null;
    _boundUid = null;
    _ownedRewardIds.clear();
    _grantedAt.clear();
    _loaded = false;
    _loadedForUid = null;
    _lastSyncedLevel = -1;
    // _loadingFuture is intentionally left as-is: an in-flight load for the
    // PREVIOUS user may still resolve after this call. `_ensureLoadedForUid`
    // re-checks `_loadedForUid == uid` after awaiting it, so a stale
    // in-flight future can never leak another user's ownership into the new
    // session — it just costs, at worst, one harmless extra read.
  }

  void _bindHunterStream(String uid) {
    _hunterSub?.cancel();
    _boundUid = uid;
    // Taps into the SAME broadcast stream every screen already uses — no new
    // Firestore `.snapshots()` listener is created by this service.
    _hunterSub = HunterRepository.instance.watch().listen((data) {
      if (data == null) return;
      unawaited(syncForLevel(uid, data.level));
    });
  }

  // ── Public: read-only accessors (for current + future reward UI) ───────

  /// Ensures the owned-rewards set is loaded for the current signed-in user.
  /// Safe to call repeatedly; only performs a Firestore read once per user.
  Future<void> ensureLoadedForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _ensureLoadedForUid(uid);
  }

  /// Whether [rewardId] has been permanently granted to the current user.
  bool isOwned(String rewardId) => _ownedRewardIds.contains(rewardId);

  /// Read-only view of every reward permanently owned by the current user.
  List<RankReward> get ownedRewards =>
      kRankRewards.where((r) => _ownedRewardIds.contains(r.id)).toList();

  /// All rewards defined for a given rank tier (0 = E … 11 = Ascend Legend),
  /// regardless of ownership. Useful for a future "rewards for this rank" UI.
  List<RankReward> rewardsForTier(int tier) =>
      kRankRewards.where((r) => r.rankTier == tier).toList();

  /// When [rewardId] was first granted to the current user, or `null` if it
  /// isn't owned (or the grant timestamp hasn't loaded yet). Read purely from
  /// the existing `grantedAt` field already written by [_grantReward] — this
  /// does not add any new Firestore field or alter granting rules.
  DateTime? grantedAtFor(String rewardId) => _grantedAt[rewardId];

  // ── Core: sync + grant ──────────────────────────────────────────────────

  /// Grants every reward the hunter qualifies for at [level] that they don't
  /// already own. Safe to call repeatedly (idempotent) — already-owned
  /// rewards and unchanged levels are skipped cheaply.
  Future<void> syncForLevel(String uid, int level) async {
    await _ensureLoadedForUid(uid);

    // Nothing can have changed if the level is the same as last time this
    // exact user was synced (rank tier is a pure function of level).
    if (level == _lastSyncedLevel && _loadedForUid == uid) return;
    if (_syncing) return;
    _syncing = true;
    try {
      _lastSyncedLevel = level;

      // Rank tier is resolved ENTIRELY via RankService — this service never
      // recomputes or duplicates that logic.
      final tier = RankService.instance.tierForLevel(level);

      final missing = kRankRewards.where(
        (r) => r.rankTier <= tier && !_ownedRewardIds.contains(r.id),
      );

      for (final reward in missing) {
        await _grantReward(uid, reward);
      }
    } finally {
      _syncing = false;
    }
  }

  /// Loads the set of reward IDs already owned by [uid], once per user. A
  /// one-time Firestore `.get()` — not a live listener. Safe to call
  /// concurrently: overlapping callers await the SAME in-flight read instead
  /// of each issuing their own.
  Future<void> _ensureLoadedForUid(String uid) async {
    if (_loaded && _loadedForUid == uid) return;

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
    _ownedRewardIds.clear();
    _grantedAt.clear();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .get();
      for (final doc in snap.docs) {
        _ownedRewardIds.add(doc.id);
        // Read back the EXISTING grantedAt field (already written by
        // _grantReward) purely for display — never used to gate ownership.
        final ts = doc.data()['grantedAt'];
        if (ts is Timestamp) _grantedAt[doc.id] = ts.toDate();
      }
    } catch (e) {
      debugPrint('RankRewardService load: $e');
      // Leave _loaded false so a later call retries the read instead of
      // silently treating a failed load as "nothing owned".
      return;
    }

    _loadedForUid = uid;
    _loaded = true;
    _lastSyncedLevel = -1; // force one sync pass for this freshly-loaded user
  }

  /// Permanently grants [reward] to [uid]. Uses the reward's stable [id] as
  /// the document ID so the write is naturally idempotent, and relies on the
  /// Firestore rules (create-only) to guarantee at most one grant ever
  /// succeeds, even under concurrent calls from multiple devices.
  Future<void> _grantReward(String uid, RankReward reward) async {
    final ref = FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .collection(_subcollectionName)
        .doc(reward.id);

    try {
      await ref.set({
        'rewardId': reward.id,
        'rankTier': reward.rankTier,
        'type': reward.type.name,
        'grantedAt': FieldValue.serverTimestamp(),
      });
      _ownedRewardIds.add(reward.id);
      // Record a local timestamp immediately so UI reading grantedAtFor()
      // right after a fresh grant shows a sensible date without waiting for
      // a full reload; a later _loadFor() will overwrite this with the exact
      // server timestamp once read back.
      _grantedAt[reward.id] = DateTime.now();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // The rules rejected this as an "update" — meaning the reward was
        // already granted (by another device/session). Treat as owned; this
        // is the duplicate-prevention guarantee working as intended.
        _ownedRewardIds.add(reward.id);
      } else {
        debugPrint('RankRewardService grant ${reward.id}: $e');
      }
    } catch (e) {
      debugPrint('RankRewardService grant ${reward.id}: $e');
    }
  }
}
