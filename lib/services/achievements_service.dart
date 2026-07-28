import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/achievements_catalog.dart';
import 'package:hunter_ascend/data/models/achievement.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/widgets/achievement_unlocked_dialog.dart';

/// Resolves achievement unlock state from the hunter's existing stats,
/// permanently claims newly-satisfied achievements in Firestore, and awards
/// their XP reward exactly once.
///
/// ## Persistence (Firestore is the source of truth)
/// Every claimed achievement is written to
/// `hunters/{uid}/unlockedAchievements/{achievementId}` — the SAME
/// create-only-subcollection pattern already used by `RankRewardService`
/// for permanent rank rewards:
/// - `create` succeeds at most once per achievement (Firestore rules make a
///   second attempt fail as an `update`), so a duplicate claim — even from
///   two devices/sessions racing each other — is structurally impossible.
/// - This survives app restart, reinstall, and device change, because it
///   lives in Firestore rather than SharedPreferences.
///
/// An in-memory `Set<String>` mirrors the current user's claimed IDs purely
/// for fast, synchronous UI reads (matching `RankRewardService`'s pattern);
/// it is populated by a one-time `.get()` per signed-in user and is never the
/// source of truth for duplicate prevention — Firestore's create-only rule is.
///
/// ## Exactly-once XP
/// Each claim is a two-step, crash-safe sequence:
/// 1. `create` the claim doc with `xpAwarded: false`.
/// 2. Award the achievement's XP via [XpService.awardXp] (which already
///    handles level-up atomically).
/// 3. Flip `xpAwarded` to `true` (the ONLY update ever allowed on this doc).
///
/// If step 2/3 fails (e.g. the app is killed mid-flow), the claim doc is left
/// with `xpAwarded: false`. The very next [evaluate] call for that user
/// detects and finishes any such pending award before processing new
/// achievements — so XP is never lost and never duplicated, even across a
/// crash. If the XP transaction itself fails immediately, the claim doc is
/// rolled back (deleted, which the rules only permit while `xpAwarded` is
/// still false) so the achievement can be retried on the next evaluation
/// instead of being permanently stuck "claimed but unpaid".
///
/// ## Background evaluation vs. celebration UI
/// [evaluate] is context-free and safe to call from a background listener
/// (e.g. every time the hunter document updates) — it never touches the UI.
/// [showPendingUnlockDialogs] is the separate, explicit step that drains the
/// queue and displays the "Achievement Unlocked" dialog through the shared
/// [MilestoneService] queue, so achievement celebrations never overlap with
/// level-up / rank-up / other milestone dialogs.
class AchievementsService {
  AchievementsService._();
  static final AchievementsService instance = AchievementsService._();

  static const String _subcollectionName = 'unlockedAchievements';

  /// Achievement ids permanently claimed by the currently-loaded user.
  final Set<String> _ownedIds = {};

  /// Achievement ids whose claim doc exists but whose XP award did not yet
  /// complete (crash/failure recovery — see class doc).
  final Set<String> _pendingXpAwardIds = {};

  /// Achievements newly unlocked and awaiting a celebration dialog.
  final List<Achievement> _pendingUnlocks = [];

  bool _loaded = false;
  String? _loadedForUid;
  bool _evaluating = false;
  Future<void>? _loadingFuture;

  bool _authListenerBound = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<HunterData?>? _hunterSub;
  String? _boundUid;

  // ── Public: lifecycle ────────────────────────────────────────────────────

  /// Starts automatic, event-driven evaluation for the app session. Call
  /// once (e.g. in `main()`, alongside `RankRewardService.instance.start()`).
  /// Safe to call multiple times — binds its auth listener at most once.
  ///
  /// This taps into the SAME broadcast `HunterRepository.watch()` stream
  /// every screen already uses (no new Firestore `.snapshots()` listener),
  /// so ANY write to the hunter document — from any screen, at any time —
  /// automatically re-evaluates achievements. This is what guarantees "no
  /// achievement depends on opening the Achievements screen to unlock":
  /// background evaluation runs on every hunter-data change, independent of
  /// which screen is currently visible.
  void start() {
    if (_authListenerBound) return;
    _authListenerBound = true;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return; // logout handled explicitly via clearCache()
      if (_boundUid == user.uid) return;
      _bindHunterStream(user.uid);
    });

    final current = FirebaseAuth.instance.currentUser;
    if (current != null) _bindHunterStream(current.uid);
  }

  void _bindHunterStream(String uid) {
    _hunterSub?.cancel();
    _boundUid = uid;
    _hunterSub = HunterRepository.instance.watch().listen((data) {
      if (data == null) return;
      unawaited(evaluate(data));
    });
  }

  /// Clears all in-memory state. Call on logout so the next signed-in hunter
  /// starts from a clean slate (mirrors `RankRewardService.clearCache`).
  void clearCache() {
    _hunterSub?.cancel();
    _hunterSub = null;
    _boundUid = null;
    _ownedIds.clear();
    _pendingXpAwardIds.clear();
    _pendingUnlocks.clear();
    _loaded = false;
    _loadedForUid = null;
  }

  /// Ensures claimed-achievement state is loaded for the current user. Safe
  /// to call repeatedly and concurrently — only ever performs one Firestore
  /// read per signed-in user.
  Future<void> ensureLoaded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _ensureLoadedForUid(uid);
  }

  // ── Public: read-only accessors ─────────────────────────────────────────

  /// Achievements newly unlocked and awaiting a celebration dialog.
  List<Achievement> get pendingUnlocks => List.unmodifiable(_pendingUnlocks);

  /// Whether [id] is permanently claimed by the current user.
  bool isUnlocked(String id) => _ownedIds.contains(id);

  // ── Core: evaluate (background-safe, no UI) ─────────────────────────────

  /// Evaluates the whole catalog against [h] for the current signed-in user.
  /// Claims (in Firestore) and awards XP for every newly-satisfied
  /// achievement, exactly once each. Returns the resolved status for every
  /// achievement (for UI display) — always computed from the up-to-date
  /// local ownership set, so callers get a consistent snapshot even if this
  /// particular call didn't unlock anything new.
  ///
  /// Safe to call from a background listener: performs no navigation and
  /// shows no UI. Safe to call repeatedly/concurrently for the same user —
  /// re-entrant calls are coalesced via [_evaluating] so at most one claim
  /// pass runs at a time; Firestore's create-only rule is what ultimately
  /// guarantees no achievement is ever claimed or paid twice, even if this
  /// guard were somehow bypassed (e.g. two app instances on two devices).
  Future<List<AchievementStatus>> evaluate(HunterData h) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return kAchievements
          .map((a) => AchievementStatus(achievement: a, unlocked: false, progress: a.progressOf(h)))
          .toList();
    }

    await _ensureLoadedForUid(uid);

    if (!_evaluating) {
      _evaluating = true;
      try {
        // Finish any award left pending by a previous crash/failure before
        // considering new claims, so XP is never permanently stuck unpaid.
        for (final id in _pendingXpAwardIds.toList()) {
          final achievement = kAchievementsById[id];
          if (achievement != null) {
            await _finishPendingAward(uid, achievement);
          }
        }

        for (final a in kAchievements) {
          if (_ownedIds.contains(a.id)) continue;
          if (!a.isDone(h)) continue;
          // Re-check auth before each write attempt — if the user signed out
          // while a previous claim was in-flight, bail immediately instead of
          // issuing a write that will be rejected with PERMISSION_DENIED.
          if (FirebaseAuth.instance.currentUser == null) break;
          await _claimAndAward(uid, a);
        }
      } finally {
        _evaluating = false;
      }
    }

    return kAchievements
        .map((a) => AchievementStatus(
              achievement: a,
              unlocked: _ownedIds.contains(a.id),
              progress: _ownedIds.contains(a.id) ? 1.0 : a.progressOf(h),
            ))
        .toList();
  }

  /// Claims [a] for [uid] and awards its XP, exactly once, with crash-safe
  /// rollback. See the class doc for the full two-step sequence.
  Future<void> _claimAndAward(String uid, Achievement a) async {
    final ref = FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .collection(_subcollectionName)
        .doc(a.id);

    bool claimed = false;
    try {
      await ref.set({
        'achievementId': a.id,
        'rewardXp': a.rewardXp,
        'xpAwarded': false,
        'grantedAt': FieldValue.serverTimestamp(),
      });
      claimed = true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Already claimed by another device/session — not a new unlock.
        _ownedIds.add(a.id);
        return;
      }
      debugPrint('AchievementsService claim ${a.id}: $e');
      return;
    } catch (e) {
      debugPrint('AchievementsService claim ${a.id}: $e');
      return;
    }

    if (!claimed) return;
    _ownedIds.add(a.id);

    final paid = await _awardXpFor(uid, a);
    if (paid) {
      _pendingUnlocks.add(a);
    } else {
      // XP failed immediately — roll back so the next evaluation retries
      // the whole claim instead of leaving it permanently unpaid.
      try {
        await ref.delete();
        _ownedIds.remove(a.id);
      } catch (e) {
        // Rollback failed too — leave the doc as a pending award; the next
        // evaluate() call will retry paying it via _finishPendingAward.
        _pendingXpAwardIds.add(a.id);
        _pendingUnlocks.add(a);
        debugPrint('AchievementsService rollback ${a.id}: $e');
      }
    }
  }

  /// Retries the XP award for an achievement that was claimed in a previous
  /// session but never got paid (e.g. app killed between claim and award).
  Future<void> _finishPendingAward(String uid, Achievement a) async {
    final paid = await _awardXpFor(uid, a);
    if (paid) {
      _pendingXpAwardIds.remove(a.id);
      _pendingUnlocks.add(a);
    }
  }

  /// Awards [a]'s XP via the centralized [XpService] and marks the claim doc
  /// as paid. Returns `true` only once BOTH the XP award and the `xpAwarded`
  /// flag update succeed.
  Future<bool> _awardXpFor(String uid, Achievement a) async {
    if (a.rewardXp <= 0) {
      await _markPaid(uid, a.id);
      return true;
    }
    final result = await XpService.instance.awardXp(amount: a.rewardXp);
    if (result == null) return false;
    return _markPaid(uid, a.id);
  }

  Future<bool> _markPaid(String uid, String achievementId) async {
    try {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .doc(achievementId)
          .update({'xpAwarded': true});
      return true;
    } catch (e) {
      debugPrint('AchievementsService markPaid $achievementId: $e');
      _pendingXpAwardIds.add(achievementId);
      return false;
    }
  }

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
    _ownedIds.clear();
    _pendingXpAwardIds.clear();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection(_subcollectionName)
          .get();
      for (final doc in snap.docs) {
        _ownedIds.add(doc.id);
        if (doc.data()['xpAwarded'] != true) {
          _pendingXpAwardIds.add(doc.id);
        }
      }
    } catch (e) {
      debugPrint('AchievementsService load: $e');
      return; // leave _loaded false so a later call retries
    }
    _loadedForUid = uid;
    _loaded = true;
  }

  // ── Public: celebration UI ──────────────────────────────────────────────

  /// Drains [pendingUnlocks] and shows the "Achievement Unlocked" dialog for
  /// each, funneled through the shared [MilestoneService] queue so they
  /// never overlap with level-up / rank-up / other celebrations. Safe to
  /// call after every [evaluate] — a no-op when nothing is pending.
  void showPendingUnlockDialogs(BuildContext context) {
    if (_pendingUnlocks.isEmpty) return;
    final pending = List<Achievement>.from(_pendingUnlocks);
    _pendingUnlocks.clear();
    for (final achievement in pending) {
      MilestoneService.enqueue(
        context,
        (ctx) => AchievementUnlockedDialog.show(ctx, achievement: achievement),
      );
    }
  }

  /// Convenience for trigger call sites: evaluates [h] and immediately shows
  /// any newly-unlocked celebration dialogs. This is the single entry point
  /// every real trigger site (profile picture change, weight update, quest
  /// completion, run completion, sharing, etc.) should call right after its
  /// own Firestore write completes.
  Future<void> checkAndCelebrate(BuildContext context, HunterData h) async {
    await evaluate(h);
    if (!context.mounted) return;
    showPendingUnlockDialogs(context);
  }

  /// Same as [checkAndCelebrate], but fetches the current user's freshly-
  /// written hunter document itself first. This is the convenience most
  /// trigger call sites should use — it saves every call site from having
  /// to duplicate the "re-fetch the doc I just wrote so isDone() sees the
  /// NEW value" boilerplate (the same pattern already used by
  /// `duel_screen.dart`'s `_evaluateAchievementsNow`). Safe to call even if
  /// the read fails — it silently does nothing in that case rather than
  /// throwing, since a missed immediate-celebration is recovered on the very
  /// next hunter-data update via the background listener anyway.
  Future<void> checkAndCelebrateForCurrentUser(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('hunters').doc(uid).get();
      if (!snap.exists) return;
      var hunter = HunterData.fromFirestore(snap.data()!);

      // mealsLoggedCount / proteinGoalHitDays / balancedMacroDays /
      // lastProteinGoalHitDate / lastBalancedMacroDate are local-only (see
      // HunterRepository.updateNutritionAchievementLocal) and are never
      // written to Firestore, so the fresh snapshot above never carries
      // them — merge in the locally-cached values so nutrition
      // achievements evaluate against the real, current counts.
      final cached = HunterRepository.instance.getCached();
      if (cached != null) {
        hunter = hunter.copyWith(
          mealsLoggedCount: cached.mealsLoggedCount,
          proteinGoalHitDays: cached.proteinGoalHitDays,
          lastProteinGoalHitDate: cached.lastProteinGoalHitDate,
          balancedMacroDays: cached.balancedMacroDays,
          lastBalancedMacroDate: cached.lastBalancedMacroDate,
        );
      }

      if (!context.mounted) return;
      await checkAndCelebrate(context, hunter);
    } catch (e) {
      debugPrint('AchievementsService checkAndCelebrateForCurrentUser: $e');
    }
  }
}
