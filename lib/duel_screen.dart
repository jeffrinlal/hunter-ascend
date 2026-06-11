import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuelScreen extends StatelessWidget {
  final String duelId;

  const DuelScreen({super.key, required this.duelId});

  static const _bg      = Color(0xFF070B14);
  static const _card    = Color(0xFF0D1120);
  static const _blue    = Color(0xFF4D7CFF);
  static const _blueDim = Color(0xFF1A2A4A);
  static const _border  = Color(0xFF1E2D4A);

  Future<void> updateDuelStats(Map<String, dynamic> duel, String winnerUid) async {
    String loserUid = winnerUid == duel['player1'] ? duel['player2'] : duel['player1'];
    await FirebaseFirestore.instance.collection('hunters').doc(winnerUid).update({'duelWins': FieldValue.increment(1)});
    await FirebaseFirestore.instance.collection('hunters').doc(loserUid).update({'duelLosses': FieldValue.increment(1)});
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
        stream: FirebaseFirestore.instance.collection('duels').doc(duelId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          final duel = snapshot.data!.data() as Map<String, dynamic>;

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
              ? duel['player1CompletedToday']
              : duel['player2CompletedToday'];

          // ── Completed result screen ──
          if (duel['status'] == 'completed') {
            final bool won      = duel['winner'] == user?.uid;
            final String vField = isPlayer1 ? 'player1ViewedResult' : 'player2ViewedResult';

            if (duel[vField] == false) {
              FirebaseFirestore.instance.collection('duels').doc(duelId).update({vField: true});
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
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(14),
                        ),
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
          final startDate    = (duel['startDate'] as Timestamp).toDate();
          final daysPassed   = DateTime.now().difference(startDate).inDays;
          final currentDay   = daysPassed + 1;
          final daysRemaining = duel['durationDays'] - daysPassed;

          // Auto-complete when time is up
          if (daysRemaining <= 0 && duel['status'] == 'active' && (duel['winner'] ?? '').toString().isEmpty) {
            String winnerUid = '';
            if ((duel['player1Score'] ?? 0) > (duel['player2Score'] ?? 0)) winnerUid = duel['player1'];
            else if ((duel['player2Score'] ?? 0) > (duel['player1Score'] ?? 0)) winnerUid = duel['player2'];
            FirebaseFirestore.instance.collection('duels').doc(duelId).update({
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
                        Text(
                          "CANCEL REQUEST RECEIVED",
                          style: TextStyle(color: Color(0xFFFF4444), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async => await FirebaseFirestore.instance
                                .collection('duels').doc(duelId).update({'status': 'cancelled'}),
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
                                .collection('duels').doc(duelId).update({'cancelRequestedBy': '', 'cancelStatus': ''}),
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
                        Text(
                          "DAY $currentDay",
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
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
                          Text(
                            "$daysRemaining DAYS LEFT",
                            style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
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
                      child: Text(
                        "$currentDay / ${duel['durationDays']} days",
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
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
                    const Text(
                      "⚔  ACTIVE RIVALRY",
                      style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 20),

                    // YOU row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(8)),
                        child: const Text("YOU", style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(
                        "$myScore XP",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: myRatio.toDouble(),
                        minHeight: 10,
                        backgroundColor: _blueDim,
                        valueColor: const AlwaysStoppedAnimation<Color>(_blue),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // VS divider
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

                    // OPPONENT row
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("OPPONENT", style: TextStyle(color: Color(0xFFFF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(
                        "$oppScore XP",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: oppRatio.toDouble(),
                        minHeight: 10,
                        backgroundColor: const Color(0xFFFF4444).withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4444)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                // ── Shared quests header ──
                Row(children: [
                  const Text("Shared Quests", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${(duel['duelQuests'] as List).length}",
                      style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),

                const SizedBox(height: 12),

                // ── Quest tiles ──
                ...(duel['duelQuests'] as List).map((quest) {
                  final bool done = completedToday.contains(quest['name']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: done ? const Color(0xFF44DD88).withValues(alpha: 0.4) : _border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: done
                              ? const Color(0xFF44DD88).withValues(alpha: 0.1)
                              : _blueDim,
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
                          Text(
                            "+${quest['xp']} XP",
                            style: const TextStyle(color: Color(0xFF44DD88), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ]),
                      ),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF44DD88).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text("DONE", style: TextStyle(color: Color(0xFF44DD88), fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      else
                        GestureDetector(
                          onTap: () {
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
                                      child: const Icon(Icons.gps_fixed, color: _blue, size: 28),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text("COMPLETE QUEST", style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                    const SizedBox(height: 10),
                                    Text(
                                      quest['name'],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    Text("+${quest['xp']} XP", style: const TextStyle(color: Color(0xFF44DD88), fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 24),
                                    Row(children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 13),
                                            decoration: BoxDecoration(
                                              color: _blueDim,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _border),
                                            ),
                                            child: const Center(child: Text("CANCEL", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1))),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () async {
                                            final u = FirebaseAuth.instance.currentUser;
                                            if (u == null) return;
                                            final bool ip1 = duel['player1'] == u.uid;
                                            final String cf = ip1 ? 'player1CompletedToday' : 'player2CompletedToday';
                                            await FirebaseFirestore.instance.collection('duels').doc(duelId).update({
                                              cf: FieldValue.arrayUnion([quest['name']]),
                                              ip1 ? 'player1Score' : 'player2Score': FieldValue.increment(quest['xp']),
                                            });
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("${quest['name']} completed!")),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 13),
                                            decoration: BoxDecoration(
                                              color: _blue,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Center(child: Text("COMPLETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ]),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text("COMPLETE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                      await FirebaseFirestore.instance.collection('duels').doc(duelId).update({
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
                        Text(
                          "REQUEST CANCEL DUEL",
                          style: TextStyle(color: Color(0xFFFF4444), fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
                        ),
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