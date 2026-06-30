import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/utils/hunter_calculations.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';

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
  // Guards the auto-completion path so it runs at most once per device.
  bool _completingDuel = false;
  Duration remaining = Duration.zero;

  // ── Ad ──────────────────────────────────────────────────
  BannerAd? bannerAd;
  bool isBannerReady = false;

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
    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.dashboardBannerAdUnitId,
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() => isBannerReady = true);
      },
      onAdFailedToLoad: (ad, error) { debugPrint("BANNER FAILED: $error"); ad.dispose(); },
    );
    bannerAd!.load();
  }

  Future<void> updateDuelStats(Map<String, dynamic> duel, String winnerUid) async {
    String loserUid = winnerUid == duel['player1'] ? duel['player2'] : duel['player1'];
    await FirebaseFirestore.instance.collection('hunters').doc(winnerUid).update({'duelWins': FieldValue.increment(1)});
    await FirebaseFirestore.instance.collection('hunters').doc(loserUid).update({'duelLosses': FieldValue.increment(1)});
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

    await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
      'player1CompletedToday': [],
      'player2CompletedToday': [],
      'lastResetDate': today,
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
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "You must wait for the timer to finish before you can complete this mission.",
                    style: TextStyle(color: Colors.orange, fontSize: 11, height: 1.4),
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
        border: Border.all(color: _blue, width: 1.5),
        color: _card,
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.2), blurRadius: 16)],
      ),
      child: Column(children: [
        Text("⚡ ACTIVE MISSION ⚡", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(
          ready ? "Status: Ready to Complete" : "Status: In Progress",
          style: TextStyle(color: ready ? HunterTheme.success : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _completeActiveQuest(duel),
            child: Text(
              "COMPLETE MISSION",
              style: TextStyle(color: ready ? Colors.white : HunterTheme.textTertiary, fontWeight: FontWeight.bold, letterSpacing: 2),
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
          Center(child: SizedBox(width: bannerAd!.size.width.toDouble(), height: bannerAd!.size.height.toDouble(), child: AdWidget(ad: bannerAd!))),
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
        color: _card,
        boxShadow: [BoxShadow(color: HunterTheme.success.withValues(alpha: 0.08), blurRadius: 16)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HunterTheme.success.withValues(alpha: 0.1),
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
        stream: FirebaseFirestore.instance.collection('duels').doc(widget.duelId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _blue));
          }

          final duel = snapshot.data!.data() as Map<String, dynamic>;

          // ── Daily reset check ──
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkDailyReset(duel);
          });

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
          final List allQuests = duel['duelQuests'] as List;
          final bool allDoneToday = allQuests.isNotEmpty &&
              allQuests.every((q) => completedToday.contains(q['name']));

          // ── Completed result screen ──
          if (duel['status'] == 'completed') {
            final bool won      = duel['winner'] == user?.uid;
            final String vField = isPlayer1 ? 'player1ViewedResult' : 'player2ViewedResult';

            if (duel[vField] == false) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({vField: true});
              });
            }

            return Container(
              color: _bg,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: won
                            ? Colors.amber.withValues(alpha: 0.1)
                            : HunterTheme.danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: won
                              ? Colors.amber.withValues(alpha: 0.5)
                              : HunterTheme.danger.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        won ? Icons.emoji_events : Icons.close,
                        color: won ? Colors.amber : HunterTheme.danger,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      won ? "VICTORY" : "DEFEATED",
                      style: TextStyle(
                        color: won ? Colors.amber : HunterTheme.danger,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      won ? "You have proven your worth, Hunter." : "Train harder. Rise again.",
                      style: TextStyle(color: HunterTheme.textTertiary, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          "RETURN TO BASE",
                          style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                      ),
                    ),
                  ],
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
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("CURRENT DAY", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text("DAY $currentDay", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined, color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Text("$daysRemaining DAYS LEFT", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: currentDay / duel['durationDays'],
                        minHeight: 6,
                        backgroundColor: _blueDim,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text("$currentDay / ${duel['durationDays']} days", style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11)),
                    ),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── Score battle card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _blue.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.08), blurRadius: 20)],
                  ),
                  child: Column(children: [
                    Text("⚔  ACTIVE RIVALRY", style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                        child: Text("YOU", style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text("$myScore XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: myRatio.toDouble(), minHeight: 10,
                        backgroundColor: _blueDim,
                        valueColor: AlwaysStoppedAnimation<Color>(_blue),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Container(height: 1, color: _border)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HunterTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text("VS", style: TextStyle(color: HunterTheme.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Container(height: 1, color: _border)),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: HunterTheme.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text("OPPONENT", style: TextStyle(color: HunterTheme.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text("$oppScore XP", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: oppRatio.toDouble(), minHeight: 10,
                        backgroundColor: HunterTheme.danger.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.danger),
                      ),
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