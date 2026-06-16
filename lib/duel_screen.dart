import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DuelScreen extends StatefulWidget {
  final String duelId;

  const DuelScreen({super.key, required this.duelId});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  static const _bg      = Color(0xFF070B14);
  static const _card    = Color(0xFF0D1120);
  static const _blue    = Color(0xFF4D7CFF);
  static const _blueDim = Color(0xFF1A2A4A);
  static const _border  = Color(0xFF1E2D4A);

  // ── Active quest timer state ──────────────────────────────
  String? activeQuestName;
  int activeQuestXp = 0;
  DateTime? questEndTime;
  Timer? _countdownTimer;
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
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5435480116436845/4995463929',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => isBannerReady = true);
        },
        onAdFailedToLoad: (ad, error) { print("BANNER FAILED: $error"); ad.dispose(); },
      ),
    );
    bannerAd!.load();
  }

  Future<void> updateDuelStats(Map<String, dynamic> duel, String winnerUid) async {
    String loserUid = winnerUid == duel['player1'] ? duel['player2'] : duel['player1'];
    await FirebaseFirestore.instance.collection('hunters').doc(winnerUid).update({'duelWins': FieldValue.increment(1)});
    await FirebaseFirestore.instance.collection('hunters').doc(loserUid).update({'duelLosses': FieldValue.increment(1)});
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
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
              child: const Icon(Icons.timer_outlined, color: _blue, size: 28),
            ),
            const SizedBox(height: 16),
            const Text("START QUEST", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Text(questName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text("XP based on time chosen", style: TextStyle(color: Color(0xFF44DD88), fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 20),
            const Text("Choose a time to complete this quest", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                      Text("$mins min", style: const TextStyle(color: _blue, fontWeight: FontWeight.bold, fontSize: 13)),
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
                        style: const TextStyle(
                          color: Color(0xFF44DD88),
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
                    "You must wait for the timer to finish before you can complete this quest.",
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
                child: const Center(child: Text("CANCEL", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1))),
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
        const SnackBar(content: Text("⚠️ Timer not finished yet — quest cannot be completed.")),
      );
      return;
    }

    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final bool ip1 = duel['player1'] == u.uid;
    final String cf = ip1 ? 'player1CompletedToday' : 'player2CompletedToday';

    await FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
      cf: FieldValue.arrayUnion([activeQuestName]),
      ip1 ? 'player1Score' : 'player2Score': FieldValue.increment(activeQuestXp),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$activeQuestName completed!")),
      );
    }
    await _cancelActiveQuest();
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
        const Text("⚡ ACTIVE QUEST ⚡", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        Text(
          ready ? "Status: Ready to Complete" : "Status: In Progress",
          style: TextStyle(color: ready ? const Color(0xFF44DD88) : Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(activeQuestName ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF44DD88).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Text("Reward: +$activeQuestXp XP", style: const TextStyle(color: Color(0xFF44DD88), fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _blueDim,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ready ? const Color(0xFF44DD88).withValues(alpha: 0.5) : _blue.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ready ? Icons.check_circle_outline : Icons.timer_outlined, color: ready ? const Color(0xFF44DD88) : _blue, size: 22),
            const SizedBox(width: 10),
            Text(
              ready ? "TIME'S UP!" : _formatDuration(remaining),
              style: TextStyle(color: ready ? const Color(0xFF44DD88) : Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
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
              "COMPLETE QUEST",
              style: TextStyle(color: ready ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _cancelActiveQuest,
          child: const Text("Cancel quest", style: TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.underline)),
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
        border: Border.all(color: const Color(0xFF44DD88).withValues(alpha: 0.4), width: 1.5),
        color: _card,
        boxShadow: [BoxShadow(color: const Color(0xFF44DD88).withValues(alpha: 0.08), blurRadius: 16)],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF44DD88).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF44DD88).withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF44DD88), size: 32),
        ),
        const SizedBox(height: 14),
        const Text(
          "ALL QUESTS DONE FOR TODAY",
          style: TextStyle(color: Color(0xFF44DD88), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          "Great work Hunter! Come back tomorrow\nto continue your battle.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
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
            const Icon(Icons.nightlight_round, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              "Next reset in $h:$m",
              style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: const TextSpan(children: [
            TextSpan(text: "HUNTER ", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          final duel = snapshot.data!.data() as Map<String, dynamic>;

          // ── Daily reset check ──
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkDailyReset(duel);
          });

          // ── Cancelled ──
          if (duel['status'] == 'cancelled') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
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
              FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({vField: true});
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
                            : const Color(0xFFFF4444).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: won
                              ? Colors.amber.withValues(alpha: 0.5)
                              : const Color(0xFFFF4444).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        won ? Icons.emoji_events : Icons.close,
                        color: won ? Colors.amber : const Color(0xFFFF4444),
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      won ? "VICTORY" : "DEFEATED",
                      style: TextStyle(
                        color: won ? Colors.amber : const Color(0xFFFF4444),
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      won ? "You have proven your worth, Hunter." : "Train harder. Rise again.",
                      style: const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(14)),
                        child: const Text(
                          "RETURN TO BASE",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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

          // Auto-complete when time is up
          if (daysRemaining <= 0 && duel['status'] == 'active' && (duel['winner'] ?? '').toString().isEmpty) {
            String winnerUid = '';
            if ((duel['player1Score'] ?? 0) > (duel['player2Score'] ?? 0)) winnerUid = duel['player1'];
            else if ((duel['player2Score'] ?? 0) > (duel['player1Score'] ?? 0)) winnerUid = duel['player2'];
            FirebaseFirestore.instance.collection('duels').doc(widget.duelId).update({
              'status': 'completed', 'winner': winnerUid,
              'player1ViewedResult': false, 'player2ViewedResult': false,
            });
            updateDuelStats(duel, winnerUid);
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
                      color: const Color(0xFFFF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.5), width: 1.2),
                    ),
                    child: Column(children: [
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4444), size: 20),
                        SizedBox(width: 8),
                        Text("CANCEL REQUEST RECEIVED", style: TextStyle(color: Color(0xFFFF4444), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
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
                                color: const Color(0xFF44DD88).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF44DD88).withValues(alpha: 0.4)),
                              ),
                              child: const Center(child: Text("ACCEPT", style: TextStyle(color: Color(0xFF44DD88), fontWeight: FontWeight.bold, letterSpacing: 1))),
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
                                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.4)),
                              ),
                              child: const Center(child: Text("DECLINE", style: TextStyle(color: Color(0xFFFF4444), fontWeight: FontWeight.bold, letterSpacing: 1))),
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
                        const Text("CURRENT DAY", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text("DAY $currentDay", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                      child: Text("$currentDay / ${duel['durationDays']} days", style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
                    const Text("⚔  ACTIVE RIVALRY", style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                        child: const Text("YOU", style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text("$myScore XP", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: myRatio.toDouble(), minHeight: 10,
                        backgroundColor: _blueDim,
                        valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: Container(height: 1, color: _border)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.3)),
                        ),
                        child: const Text("VS", style: TextStyle(color: Color(0xFFFF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Container(height: 1, color: _border)),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFFF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text("OPPONENT", style: TextStyle(color: Color(0xFFFF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text("$oppScore XP", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: oppRatio.toDouble(), minHeight: 10,
                        backgroundColor: const Color(0xFFFF4444).withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4444)),
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
                  const Text("Shared Quests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${completedToday.length}/${allQuests.length}",
                      style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
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
                            ? const Color(0xFF44DD88).withValues(alpha: 0.4)
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
                          color: done ? const Color(0xFF44DD88).withValues(alpha: 0.1) : _blueDim,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          done ? Icons.check_circle_outline : Icons.gps_fixed,
                          color: done ? const Color(0xFF44DD88) : _blue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            quest['name'],
                            style: TextStyle(
                              color: done ? Colors.white38 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text("XP based on time", style: TextStyle(color: Color(0xFF44DD88), fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF44DD88).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text("DONE", style: TextStyle(color: Color(0xFF44DD88), fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else if (isCurrentActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                          child: const Text("IN PROGRESS", style: TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else if (allDoneToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                            child: const Text("TOMORROW", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                        else
                          GestureDetector(
                            onTap: activeQuestName != null
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("⚠️ Finish your current active quest first.")))
                                : () => _showStartQuestDialog(quest['name'], quest['xp']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: activeQuestName != null ? _blueDim : _blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "START",
                                style: TextStyle(color: activeQuestName != null ? Colors.white38 : Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Cancel request sent")),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4444).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.35), width: 1.2),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cancel_outlined, color: Color(0xFFFF4444), size: 18),
                        SizedBox(width: 8),
                        Text("REQUEST CANCEL DUEL", style: TextStyle(color: Color(0xFFFF4444), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
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