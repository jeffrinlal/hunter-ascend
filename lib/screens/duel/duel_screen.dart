import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/achievement_unlocked_dialog.dart';

/// Live 1v1 duel screen: shows progress, countdown, and result for [duelId].
class DuelScreen extends StatefulWidget {
  final String duelId;

  const DuelScreen({super.key, required this.duelId});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => HunterTheme.primary;
  static Color get _blueDim => HunterTheme.border;
  static Color get _border => HunterTheme.border;
  // ── Active quest timer state ──────────────────────────────
  String? activeQuestName;
  int activeQuestXp = 0;
  DateTime? questEndTime;
  Timer? _countdownTimer;
  bool _completingActiveQuest = false;
  // The calendar day for which _checkDailyReset has already run. Prevents
  // repeated execution on every StreamBuilder emission while still allowing
  // the check to re-fire if the screen stays open across midnight.
  String _lastResetCheckDay = '';
  // Guards the auto-completion path so it runs at most once per device.
  bool _completingDuel = false;
  // Session-level re-entrancy guard for the duel XP grant. Prevents the
  // post-frame award from being scheduled repeatedly across the many stream
  // emissions/rebuilds of a completed duel. Cross-session/device idempotency
  // is enforced separately by the per-player flag on the duel document.
  bool _duelXpHandled = false;
  Duration remaining = Duration.zero;

  // ── Ad ──────────────────────────────────────────────────
  BannerAd? bannerAd;
  bool isBannerReady = false;

  // Cached stream (stable identity across rebuilds).
  late final Stream<DocumentSnapshot> _duelStream = FirebaseFirestore.instance
      .collection('duels')
      .doc(widget.duelId)
      .snapshots();

  @override
  void initState() {
    super.initState();
    loadBannerAd();
    _restoreActiveQuest();
  }

  // ── Restore active quest timer from hunter profile ─────────
  Future<void> _restoreActiveQuest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    if (!doc.exists) return;
    if (!mounted) return;

    final data = doc.data()!;
    final activeDuelId = data['activeDuelQuestDuelId'];
    if (activeDuelId != widget.duelId) return;

    final questName = data['activeDuelQuestName'];
    final questXp = data['activeDuelQuestXp'];
    final endTimeStamp = data['activeDuelQuestEndTime'] as Timestamp?;

    if (questName == null || endTimeStamp == null) return;

    final endTime = endTimeStamp.toDate();
    if (DateTime.now().isAfter(endTime)) {
      setState(() {
        activeQuestName = questName;
        activeQuestXp = questXp ?? 0;
        questEndTime = endTime;
        remaining = Duration.zero;
      });
      return;
    }

    setState(() {
      activeQuestName = questName;
      activeQuestXp = questXp ?? 0;
      questEndTime = endTime;
      remaining = endTime.difference(DateTime.now());
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final now = DateTime.now();
      if (questEndTime == null) return;
      final diff = questEndTime!.difference(now);
      if (diff.isNegative) {
        setState(() => remaining = Duration.zero);
      } else {
        setState(() => remaining = diff);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    bannerAd?.dispose();
    super.dispose();
  }

  void loadBannerAd() {
    // Max tier hides banner ads entirely — skip the load so nothing is
    // requested or rendered for those hunters.
    if (!MembershipService.instance.showBannerAds) return;

    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() => isBannerReady = true);
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint("DUEL BANNER FAILED: $error");
        ad.dispose();
        bannerAd = null;
        // Retry once after a short delay.
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && bannerAd == null) _retryBannerAd();
          });
        }
      },
    );
    bannerAd!.load();
  }

  void _retryBannerAd() {
    if (!MembershipService.instance.showBannerAds) return;
    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() => isBannerReady = true);
      },
      onAdFailedToLoad: (ad, error) {
        debugPrint("DUEL BANNER RETRY FAILED: $error");
        ad.dispose();
        bannerAd = null;
      },
    );
    bannerAd!.load();
  }

  Future<void> updateDuelStats(Map<String, dynamic> duel, String winnerUid) async {
    String loserUid = winnerUid == duel['player1'] ? duel['player2'] : duel['player1'];
    await FirebaseFirestore.instance.collection('hunters').doc(winnerUid).update({'duelWins': FieldValue.increment(1)});
    await FirebaseFirestore.instance.collection('hunters').doc(loserUid).update({'duelLosses': FieldValue.increment(1)});
  }

  // ── Duel XP integration ───────────────────────────────────
  // Grants Hunter progression XP for a COMPLETED duel exactly once per player:
  //   • Winner  → +100 XP via the shared XpService (reuses level-up, daily/
  //               weekly XP, and leaderboard invalidation — no logic copied).
  //   • Loser   → −20 XP, safely clamped to 0, level never reduced.
  //   • Draw    → no change for either player.
  //
  // Idempotency: a per-player flag on the duel document (playerNXpAwarded,
  // mirroring the existing playerNViewedResult flags) is claimed inside a
  // transaction. Only the single invocation — across rebuilds, stream
  // emissions, multiple listeners, network retries, app restarts and devices —
  // that flips the flag false→true proceeds to grant XP. If the grant fails the
  // flag is rolled back so the reward is retried later, never duplicated.
  //
  // XP is only ever written to the LOCAL hunter's OWN document. This is
  // mandatory: the Firestore rules permit cross-user hunter writes solely for
  // duelWins/duelLosses, never xp. Duel score, winner logic, completion,
  // counters and history are left completely untouched.
  Future<void> _applyDuelXpOnce(Map<String, dynamic> duel) async {
    if (_duelXpHandled) return;
    _duelXpHandled = true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _duelXpHandled = false;
      return;
    }
    if (duel['status'] != 'completed') {
      _duelXpHandled = false;
      return;
    }

    final bool isP1 = duel['player1'] == uid;
    final bool isP2 = duel['player2'] == uid;
    if (!isP1 && !isP2) return; // not a participant — nothing to grant

    final String winnerUid = (duel['winner'] ?? '').toString();
    if (winnerUid.isEmpty) return; // draw — no XP for either side

    final String flagField = isP1 ? 'player1XpAwarded' : 'player2XpAwarded';
    final duelRef =
        FirebaseFirestore.instance.collection('duels').doc(widget.duelId);

    // ── Idempotency gate: atomically claim this player's XP for this duel ──
    bool claimed = false;
    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(duelRef);
        if (!snap.exists) return;
        final d = snap.data() as Map<String, dynamic>;
        if (d['status'] != 'completed') return; // safety re-check
        if (d[flagField] == true) return; // already granted — skip
        txn.update(duelRef, {flagField: true});
        claimed = true;
      });
    } catch (e) {
      debugPrint('applyDuelXp gate: $e');
      _duelXpHandled = false; // transient failure — allow a later retry
      return;
    }

    if (!claimed) return; // another device/session already granted it

    // ── Apply the outcome to the LOCAL hunter only ──
    final bool won = winnerUid == uid;
    try {
      if (won) {
        // +100 XP through the existing service — reuses all level-up, daily/
        // weekly and leaderboard logic. No level-up logic is duplicated.
        final result = await XpService.instance.awardXp(amount: 100);
        if (result == null) throw Exception('awardXp returned null');

        // A +100 award (< 500 XP per level) can cross at most one level
        // boundary, so the previous level is exactly result.level - 1. Reuse
        // the existing multi-level celebration helper for the level-up UI.
        if (result.leveledUp && mounted) {
          MilestoneService.celebrateLevelUps(
              context, result.level - 1, result.level);
        }
      } else {
        // Loser: safely deduct 20 XP from the current progress.
        await _deductXpSafely(uid, 20);
      }

      // Immediately re-run the existing achievement evaluation so any
      // achievement newly satisfied by this duel's XP/level/rank/stat changes
      // (level, rank, XP, duel or hidden) unlocks and celebrates right now,
      // without waiting for the user to open the Achievements screen.
      await _evaluateAchievementsNow();
    } catch (e) {
      debugPrint('applyDuelXp grant: $e');
      // Roll back the claim so the reward can be retried, preventing a
      // permanently-lost reward while still guaranteeing no duplicates.
      try {
        await duelRef.update({flagField: false});
      } catch (_) {}
      _duelXpHandled = false;
    }
  }

  /// Safely subtracts [amount] XP from a hunter's current in-level XP progress
  /// without ever going negative and without changing their level. Mirrors the
  /// existing discipline-penalty pattern and only writes the caller's OWN
  /// document. Examples: 320 → 300, 12 → 0, 0 → 0.
  Future<void> _deductXpSafely(String uid, int amount) async {
    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      final int curXp = (d['xp'] ?? 0) as int;
      final int newXp = (curXp - amount).clamp(0, 999999);
      // Only 'xp' is touched — 'level' is intentionally left unchanged.
      txn.update(ref, {'xp': newXp});
    });
  }

  /// Re-runs the shared achievement evaluation for the local hunter and shows
  /// the standard celebration dialog for anything newly unlocked. This reuses
  /// [AchievementsService] and [AchievementUnlockedDialog] exactly as the
  /// Achievements screen does — no achievement logic is duplicated here. The
  /// service only queues achievements that cross their threshold for the first
  /// time (and never on the initial baseline pass), so this is safe to call on
  /// every duel completion without producing spurious or repeated unlocks.
  Future<void> _evaluateAchievementsNow() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Read the freshly-updated hunter document so evaluation sees the new
      // xp / level and the duelWins / duelLosses written on completion.
      final snap = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .get();
      if (!snap.exists) return;

      final hunter = HunterData.fromFirestore(snap.data()!);
      await AchievementsService.instance.ensureLoaded();
      AchievementsService.instance.evaluate(hunter);

      // Funnel each unlock through the shared MilestoneService queue so the
      // achievement dialogs never overlap with each other or with the level-up
      // celebration — they play sequentially after any level-up dialog.
      final unlocked = AchievementsService.instance.takePendingUnlocks();
      for (final achievement in unlocked) {
        if (!mounted) break;
        MilestoneService.enqueue(
          context,
          (ctx) => AchievementUnlockedDialog.show(ctx, achievement: achievement),
        );
      }
    } catch (e) {
      debugPrint('evaluateAchievementsNow: $e');
    }
  }

  // ── Auto-complete duel when its time is up ────────────────
  // Runs OUTSIDE build() (scheduled via a post-frame callback) and is guarded
  // so it executes at most once per device. A Firestore transaction re-reads
  // the duel and only transitions it when status is still "active", so two
  // devices racing to finish the same duel can never both complete it.
  Future<void> _autoCompleteDuel(String duelId) async {
    if (_completingDuel) return;
    _completingDuel = true;

    final duelRef = FirebaseFirestore.instance.collection('duels').doc(duelId);
    String winnerUid = '';
    Map<String, dynamic>? completedDuel; // non-null only if THIS call completed the duel

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        // Reset on every attempt — the transaction body may be retried, and
        // only the values from the final committed attempt must survive.
        winnerUid = '';
        completedDuel = null;

        final snap = await txn.get(duelRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;

        // Only complete if still active — this is the atomic check that
        // prevents duplicate completion across builds and across devices.
        if (data['status'] != 'active') return;
        if ((data['winner'] ?? '').toString().isNotEmpty) return;

        // Re-verify the duel is actually over using the stored schema fields.
        final startDate = (data['startDate'] as Timestamp).toDate();
        final daysPassed = DateTime.now().difference(startDate).inDays;
        final daysRemaining = data['durationDays'] - daysPassed;
        if (daysRemaining > 0) return;

        // Winner calculation — unchanged from the original logic.
        if ((data['player1Score'] ?? 0) > (data['player2Score'] ?? 0)) {
          winnerUid = data['player1'];
        } else if ((data['player2Score'] ?? 0) > (data['player1Score'] ?? 0)) {
          winnerUid = data['player2'];
        }

        txn.update(duelRef, {
          'status': 'completed',
          'winner': winnerUid,
          'player1ViewedResult': false,
          'player2ViewedResult': false,
        });

        // Marks that this transaction performed the completion.
        completedDuel = data;
      });

      // Only the device whose transaction actually flipped active -> completed
      // reaches here with completedDuel set, so stats update at most once.
      // A tie leaves winnerUid empty — skip updateDuelStats to avoid doc('').
      if (completedDuel != null && winnerUid.isNotEmpty) {
        await updateDuelStats(completedDuel!, winnerUid);

        // Celebrate if the local hunter won.
        final localUid = FirebaseAuth.instance.currentUser?.uid;
        if (winnerUid == localUid && mounted) {
          MilestoneService.show(
            context,
            type: MilestoneType.duelVictory,
            title: 'Duel Victory!',
            subtitle: 'Another hunter has fallen. Victory is yours.',
          );
        }
      }
    } catch (e) {
      debugPrint("autoCompleteDuel: $e");
      _completingDuel = false; // allow a retry on a transient failure
    }
  }

  // ── Daily reset — clears completedToday at midnight ────────
  Future<void> _checkDailyReset(Map<String, dynamic> duel) async {
    final today = DateTime.now().toString().substring(0, 10);
    if ((duel['lastResetDate'] ?? '') == today) return; // already reset today

    // Use a transaction to re-read the latest duel state and only reset if
    // lastResetDate is still not today. This prevents two devices from both
    // performing the reset simultaneously and overwriting each other's
    // completedToday lists.
    final duelRef = FirebaseFirestore.instance.collection('duels').doc(widget.duelId);
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(duelRef);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;

      // Another device already performed today's reset — nothing to do.
      if ((data['lastResetDate'] ?? '') == today) return;

      txn.update(duelRef, {
        'player1CompletedToday': [],
        'player2CompletedToday': [],
        'lastResetDate': today,
      });
    });
  }

  // ── Quest timer logic ─────────────────────────────────────
  void _startQuestTimer(String questName, int xp, int minutes) {
    final endTime = DateTime.now().add(Duration(minutes: minutes));

    setState(() {
      activeQuestName = questName;
      activeQuestXp = xp;
      questEndTime = endTime;
      remaining = Duration(minutes: minutes);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeDuelQuestDuelId': widget.duelId,
        'activeDuelQuestName': questName,
        'activeDuelQuestXp': xp,
        'activeDuelQuestEndTime': Timestamp.fromDate(endTime),
      });
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final now = DateTime.now();
      if (questEndTime == null) return;
      final diff = questEndTime!.difference(now);
      if (diff.isNegative) {
        setState(() => remaining = Duration.zero);
      } else {
        setState(() => remaining = diff);
      }
    });
  }

  Future<void> _cancelActiveQuest() async {
    _countdownTimer?.cancel();
    setState(() {
      activeQuestName = null;
      activeQuestXp = 0;
      questEndTime = null;
      remaining = Duration.zero;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        'activeDuelQuestDuelId': FieldValue.delete(),
        'activeDuelQuestName': FieldValue.delete(),
        'activeDuelQuestXp': FieldValue.delete(),
        'activeDuelQuestEndTime': FieldValue.delete(),
      });
    }
  }

  // ── Show time-selection dialog ────────────────────────────
  void _showStartQuestDialog(String questName, int xp) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.1), blurRadius: 24)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _blueDim,
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.timer_outlined, color: _blue, size: 28),
            ),
            const SizedBox(height: 16),
            Text("START MISSION", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Text(questName, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("XP based on time chosen", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 20),
            Text("Choose a time to complete this mission", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [2, 4, 6, 10, 15, 30, 45, 60].map((mins) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  int boostedXp;
                  if (mins >= 60)      boostedXp = 50;
                  else if (mins >= 45) boostedXp = 40;
                  else if (mins >= 30) boostedXp = 30;
                  else if (mins >= 15) boostedXp = 20;
                  else if (mins>=10)   boostedXp = 15;
                  else if (mins>=5)   boostedXp = 10;
                  else if (mins>=4)   boostedXp = 5;
                  else                 boostedXp = 3;
                  _startQuestTimer(questName, boostedXp, mins);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _blueDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("$mins min", style: TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        "+${mins >= 60
                            ? 50
                            : mins >= 45
                            ? 40
                            : mins >= 30
                            ? 30
                            : mins >= 15
                            ? 20
                            : mins >= 10
                            ? 15
                            : mins >= 6
                            ? 10
                            : mins >= 4
                            ? 5
                            : 3} XP",
                        style: TextStyle(
                          color: HunterTheme.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HunterTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HunterTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: HunterTheme.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You must wait for the timer to finish before you can complete this mission.",
                    style: TextStyle(color: HunterTheme.gold, fontSize: 11, height: 1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                child: Center(child: Text("CANCEL", style: TextStyle(color: HunterTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Complete quest ────────────────────────────────────────
  Future<void> _completeActiveQuest(Map<String, dynamic> duel) async {
    if (remaining > Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Timer not finished yet — mission cannot be completed.")),
      );
      return;
    }

    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    if (_completingActiveQuest) return;
    if (!await ConnectivityService.isOnline()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
      return;
    }
    _completingActiveQuest = true;
    try {
      final bool ip1 = duel['player1'] == u.uid;
      final String cf = ip1 ? 'player1CompletedToday' : 'player2CompletedToday';
      final String sf = ip1 ? 'player1Score' : 'player2Score';
      final String? questName = activeQuestName;
      final int questXp = activeQuestXp;

      // Atomic completion (mirrors _autoCompleteDuel's transaction style): re-read
      // the duel and only add the quest + increment the score if it is not already
      // in completedToday. arrayUnion is idempotent but FieldValue.increment is
      // not, so this prevents the same account completing the same duel quest on
      // two devices from incrementing the score twice.
      final duelRef = FirebaseFirestore.instance.collection('duels').doc(widget.duelId);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(duelRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List done = (data[cf] ?? []) as List;
        if (done.contains(questName)) return; // already completed — skip increment
        txn.update(duelRef, {
          cf: FieldValue.arrayUnion([questName]),
          sf: FieldValue.increment(questXp),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$activeQuestName completed!")),
        );
      }
      await _cancelActiveQuest();
    } catch (e) {
      debugPrint("completeActiveQuest: $e");
    } finally {
      _completingActiveQuest = false;
    }
  }

  // ── Active quest card ─────────────────────────────────────
  Widget _buildActiveQuestCard(Map<String, dynamic> duel) {
    final bool ready = remaining == Duration.zero;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withValues(alpha: 0.5), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue.withValues(alpha: 0.10), _card],
        ),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.2 * HunterTheme.glowStrength), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Text("⚡ ACTIVE MISSION ⚡", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(
          ready ? "Status: Ready to Complete" : "Status: In Progress",
          style: TextStyle(color: ready ? HunterTheme.success : HunterTheme.gold, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(activeQuestName ?? "", textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: HunterTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text("Reward: +$activeQuestXp XP", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _blueDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ready ? HunterTheme.success.withValues(alpha: 0.5) : _blue.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ready ? Icons.check_circle_outline : Icons.timer_outlined, color: ready ? HunterTheme.success : _blue, size: 22),
            const SizedBox(width: 10),
            Text(
              ready ? "TIME'S UP!" : formatMinutesSeconds(remaining),
              style: TextStyle(color: ready ? HunterTheme.success : HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ready ? _blue : _blueDim,
              foregroundColor: ready ? Colors.black : HunterTheme.textTertiary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _completeActiveQuest(duel),
            child: Text(
              "COMPLETE MISSION",
              style: TextStyle(color: ready ? Colors.black : HunterTheme.textTertiary, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cancelActiveQuest,
          child: Text("Cancel mission", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, decoration: TextDecoration.underline)),
        ),
        if (isBannerReady) ...[
          const SizedBox(height: 12),
          Center(child: SizedBox(
            key: const ValueKey('duel_banner_ad'),
            width: bannerAd!.size.width.toDouble(),
            height: bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: bannerAd!),
          )),
        ],
      ]),
    );
  }

  // ── "All done for today" card ─────────────────────────────
  Widget _buildAllDoneCard() {
    // Calculate time until midnight
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final timeLeft = midnight.difference(now);
    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HunterTheme.success.withValues(alpha: 0.4), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HunterTheme.success.withValues(alpha: 0.10), _card],
        ),
        boxShadow: [BoxShadow(color: HunterTheme.success.withValues(alpha: 0.10 * HunterTheme.glowStrength), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HunterTheme.success.withValues(alpha: 0.2), HunterTheme.success.withValues(alpha: 0.06)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: HunterTheme.success.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.check_circle_outline, color: HunterTheme.success, size: 32),
        ),
        const SizedBox(height: 14),
        Text(
          "ALL MISSIONS DONE FOR TODAY",
          style: TextStyle(color: HunterTheme.success, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          "Great work Hunter! Come back tomorrow\nto continue your battle.",
          textAlign: TextAlign.center,
          style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _blueDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.nightlight_round, color: HunterTheme.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(
              "Next reset in $h:$m",
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.cardColor,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: HunterTheme.textSecondary, size: 15),
            ),
          ),
        ),
        leadingWidth: 60,
        title: RichText(
          text: TextSpan(children: [
            TextSpan(text: "HUNTER ", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
            TextSpan(text: "RIVALRY", style: TextStyle(color: _blue, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _duelStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _blue));
          }

          final duel = snapshot.data!.data() as Map<String, dynamic>;

          // ── Daily reset check (once per calendar day) ──
          final _today = DateTime.now().toString().substring(0, 10);
          if (_lastResetCheckDay != _today) {
            _lastResetCheckDay = _today;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkDailyReset(duel);
            });
          }

          // ── Cancelled ──
          if (duel['status'] == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Duel has been cancelled")),
              );
            });
            return const SizedBox();
          }

          final user      = FirebaseAuth.instance.currentUser;
          final isPlayer1 = duel['player1'] == user?.uid;
          final List completedToday = isPlayer1
              ? (duel['player1CompletedToday'] ?? [])
              : (duel['player2CompletedToday'] ?? []);
          final List allQuests = (duel['duelQuests'] ?? []) as List;
          final bool allDoneToday = allQuests.isNotEmpty &&
              allQuests.every((q) => completedToday.contains(q['name']));

          // ── Completed result screen ──
          if (duel['status'] == 'completed') {
            final String winnerUid = (duel['winner'] ?? '').toString();
            final bool won = winnerUid == user?.uid && winnerUid.isNotEmpty;
            final bool draw = winnerUid.isEmpty;
            final String vField = isPlayer1 ? 'player1ViewedResult' : 'player2ViewedResult';

            if (duel[vField] == false) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({vField: true});
              });
            }

            // Grant this completed duel's Hunter XP exactly once for the local
            // player (winner +100 via XpService / loser −20 safely). Guarded by
            // _duelXpHandled + a per-player flag so repeated stream emissions,
            // rebuilds, retries and multiple devices never double-award.
            WidgetsBinding.instance.addPostFrameCallback((_) => _applyDuelXpOnce(duel));

            // Determine result visuals.
            final Color resultColor = draw
                ? HunterTheme.gold
                : (won ? HunterTheme.goldBright : HunterTheme.danger);
            final IconData resultIcon = draw
                ? Icons.balance
                : (won ? Icons.emoji_events : Icons.close);
            final String resultTitle = draw
                ? 'DRAW'
                : (won ? 'VICTORY' : 'DEFEATED');
            final String resultMessage = draw
                ? 'Equally matched. Challenge again to decide.'
                : (won ? 'You have proven your worth, Hunter.' : 'Train harder. Rise again.');

            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    resultColor.withValues(alpha: 0.20),
                    resultColor.withValues(alpha: 0.05),
                    _bg,
                  ],
                  stops: const [0.0, 0.35, 0.75],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Layered glowing result medallion.
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [resultColor.withValues(alpha: 0.22), resultColor.withValues(alpha: 0.04)],
                          ),
                          border: Border.all(color: resultColor.withValues(alpha: 0.55), width: 2),
                          boxShadow: [
                            BoxShadow(color: resultColor.withValues(alpha: 0.35 * HunterTheme.glowStrength), blurRadius: 40, spreadRadius: 4),
                          ],
                        ),
                        child: Icon(resultIcon, color: resultColor, size: 76),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        resultTitle,
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        resultMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textSecondary, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 36),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: HunterTheme.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: _blue.withValues(alpha: 0.4 * HunterTheme.glowStrength), blurRadius: 16, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: const Text(
                            "RETURN TO BASE",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // ── Active duel ──
          final startDate     = (duel['startDate'] as Timestamp).toDate();
          final daysPassed    = DateTime.now().difference(startDate).inDays;
          final currentDay    = daysPassed + 1;
          final daysRemaining = duel['durationDays'] - daysPassed;

          // Auto-complete when time is up. The write is deferred out of build()
          // and runs through a guarded transaction (see _autoCompleteDuel).
          if (daysRemaining <= 0 && duel['status'] == 'active' && (duel['winner'] ?? '').toString().isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _autoCompleteDuel(widget.duelId);
            });
          }

          final myScore  = isPlayer1 ? (duel['player1Score'] ?? 0) : (duel['player2Score'] ?? 0);
          final oppScore = isPlayer1 ? (duel['player2Score'] ?? 0) : (duel['player1Score'] ?? 0);
          final myName   = (isPlayer1 ? duel['player1Name'] : duel['player2Name'])?.toString() ?? 'You';
          final oppName  = (isPlayer1 ? duel['player2Name'] : duel['player1Name'])?.toString() ?? 'Opponent';
          final total    = myScore + oppScore;
          final myRatio  = total == 0 ? 0.0 : myScore / total;
          final oppRatio = total == 0 ? 0.0 : oppScore / total;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Cancel request banner ──
                if (duel['cancelStatus'] == 'pending' && duel['cancelRequestedBy'] != user?.uid)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HunterTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.5), width: 1.2),
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.warning_amber_rounded, color: HunterTheme.danger, size: 20),
                        SizedBox(width: 8),
                        Text("CANCEL REQUEST RECEIVED", style: TextStyle(color: HunterTheme.danger, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async => await FirebaseFirestore.instance
                                .collection('duels').doc(widget.duelId).update({'status': 'cancelled'}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: HunterTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: HunterTheme.success.withValues(alpha: 0.4)),
                              ),
                              child: Center(child: Text("ACCEPT", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.bold, letterSpacing: 1))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async => await FirebaseFirestore.instance
                                .collection('duels').doc(widget.duelId).update({'cancelRequestedBy': '', 'cancelStatus': ''}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: HunterTheme.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4)),
                              ),
                              child: Center(child: Text("DECLINE", style: TextStyle(color: HunterTheme.danger, fontWeight: FontWeight.bold, letterSpacing: 1))),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),

                // ── Day progress card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [HunterTheme.gold.withValues(alpha: 0.10), _card],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: HunterTheme.gold.withValues(alpha: 0.28), width: 1.4),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: HunterTheme.isDark ? 0.18 : 0.04), blurRadius: 14, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("CURRENT DAY", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text("DAY $currentDay", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: HunterTheme.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: HunterTheme.gold.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.timer_outlined, color: HunterTheme.gold, size: 16),
                          const SizedBox(width: 6),
                          Text("$daysRemaining DAYS LEFT", style: TextStyle(color: HunterTheme.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(children: [
                        Container(height: 8, color: _blueDim),
                        FractionallySizedBox(
                          widthFactor: (currentDay / duel['durationDays']).clamp(0.0, 1.0).toDouble(),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [HunterTheme.gold, HunterTheme.goldBright]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text("$currentDay / ${duel['durationDays']} days", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── Score battle card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_blue.withValues(alpha: 0.07), _card],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _blue.withValues(alpha: 0.28), width: 1.4),
                    boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.10 * HunterTheme.glowStrength), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.sports_kabaddi_rounded, color: _blue, size: 18),
                      const SizedBox(width: 8),
                      Text("ACTIVE RIVALRY", style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    ]),
                    const SizedBox(height: 20),
                    // ── You ──
                    Row(children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _blue.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "$myName (You)",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("$myScore XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(children: [
                        Container(height: 10, color: _blueDim),
                        FractionallySizedBox(
                          widthFactor: myRatio.toDouble().clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: HunterTheme.primaryGradient),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Container(height: 1, color: _border)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: HunterTheme.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.35)),
                        ),
                        child: Text("VS", style: TextStyle(color: HunterTheme.danger, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                      Expanded(child: Container(height: 1, color: _border)),
                    ]),
                    const SizedBox(height: 18),
                    // ── Opponent ──
                    Row(children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: HunterTheme.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "$oppName (Opponent)",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(color: HunterTheme.danger, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("$oppScore XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(children: [
                        Container(height: 10, color: HunterTheme.danger.withValues(alpha: 0.12)),
                        FractionallySizedBox(
                          widthFactor: oppRatio.toDouble().clamp(0.0, 1.0),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [HunterTheme.danger, HunterTheme.dangerAlt]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Active quest card (timer) ──
                if (activeQuestName != null) _buildActiveQuestCard(duel),

                // ── All done today card ──
                if (allDoneToday && activeQuestName == null) _buildAllDoneCard(),

                // ── Shared quests header ──
                Row(children: [
                  Text("Shared Missions", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${completedToday.length}/${allQuests.length}",
                      style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Quest tiles ──
                ...allQuests.map((quest) {
                  final bool done = completedToday.contains(quest['name']);
                  final bool isCurrentActive = activeQuestName == quest['name'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: done
                            ? HunterTheme.success.withValues(alpha: 0.4)
                            : isCurrentActive
                            ? _blue.withValues(alpha: 0.6)
                            : _border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: done ? HunterTheme.success.withValues(alpha: 0.1) : _blueDim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          done ? Icons.check_circle_outline : Icons.gps_fixed,
                          color: done ? HunterTheme.success : _blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            quest['name'],
                            style: TextStyle(
                              color: done ? HunterTheme.textTertiary : HunterTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text("XP based on time", style: TextStyle(color: HunterTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: HunterTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text("DONE", style: TextStyle(color: HunterTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else if (isCurrentActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                          child: Text("IN PROGRESS", style: TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else if (allDoneToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                            child: Text("TOMORROW", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        else
                          GestureDetector(
                            onTap: activeQuestName != null
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("⚠️ Finish your current active mission first.")))
                                : () => _showStartQuestDialog(quest['name'], quest['xp']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeQuestName != null ? _blueDim : _blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "START",
                                style: TextStyle(color: activeQuestName != null ? HunterTheme.textTertiary : HunterTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                    ]),
                  );
                }),

                const SizedBox(height: 20),

                // ── Request cancel button ──
                if (duel['cancelStatus'] != 'pending')
                  GestureDetector(
                    onTap: () async {
                      final startDate = (duel['startDate'] as Timestamp).toDate();
                      if (DateTime.now().difference(startDate).inHours > 24) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cancel available only during first 24 hours")),
                        );
                        return;
                      }
                      final u = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
                        'cancelRequestedBy': u?.uid,
                        'cancelStatus': 'pending',
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cancel request sent")),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: HunterTheme.danger.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cancel_outlined, color: HunterTheme.danger, size: 18),
                        SizedBox(width: 8),
                        Text("REQUEST CANCEL DUEL", style: TextStyle(color: HunterTheme.danger, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
                      ]),
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }
}