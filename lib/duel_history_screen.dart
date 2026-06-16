import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuelHistoryScreen extends StatelessWidget {
  const DuelHistoryScreen({super.key});

  static const _bg     = Color(0xFF070B14);
  static const _card   = Color(0xFF0D1120);
  static const _blue   = Color(0xFF4D7CFF);
  static const _blueDim = Color(0xFF1A2A4A);
  static const _border = Color(0xFF1E2D4A);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
            TextSpan(
              text: "DUEL ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            TextSpan(
              text: "HISTORY",
              style: TextStyle(
                color: _blue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('duels')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _blue),
            );
          }

          final myDuels = snapshot.data!.docs.where((doc) {
            final duel = doc.data() as Map<String, dynamic>;
            return duel['player1'] == user?.uid || duel['player2'] == user?.uid;
          }).toList();

          // ── Summary counts ──
          int wins = 0, losses = 0, cancelled = 0;
          for (final doc in myDuels) {
            final duel = doc.data() as Map<String, dynamic>;
            if (duel['status'] == 'completed') {
              if (duel['winner'] == user?.uid) wins++;
              else losses++;
            } else {
              cancelled++;
            }
          }

          if (myDuels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _blueDim,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border, width: 1.5),
                    ),
                    child: const Icon(Icons.sports_kabaddi, color: _blue, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "NO DUEL HISTORY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Challenge a hunter to begin",
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Stats row ──
                Row(children: [
                  _buildStatCard("WINS",      "$wins",      const Color(0xFF44DD88), Icons.emoji_events),
                  const SizedBox(width: 10),
                  _buildStatCard("LOSSES",    "$losses",    const Color(0xFFFF4444), Icons.sports_kabaddi),
                  const SizedBox(width: 10),
                  _buildStatCard("CANCELLED", "$cancelled", Colors.white38,          Icons.cancel_outlined),
                ]),

                const SizedBox(height: 24),

                // ── Section label ──
                Row(children: [
                  const Text(
                    "Recent Duels",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      "${myDuels.length}",
                      style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),

                // ── Duel tiles ──
                ...myDuels.map((doc) {
                  final duel = doc.data() as Map<String, dynamic>;

                  String label;
                  Color accentColor;
                  IconData iconData;
                  Color iconBg;

                  if (duel['status'] == 'completed') {
                    if (duel['winner'] == user?.uid) {
                      label      = "VICTORY";
                      accentColor = const Color(0xFF44DD88);
                      iconData   = Icons.emoji_events;
                      iconBg     = const Color(0xFF44DD88).withOpacity(0.12);
                    } else {
                      label      = "DEFEATED";
                      accentColor = const Color(0xFFFF4444);
                      iconData   = Icons.whatshot;
                      iconBg     = const Color(0xFFFF4444).withOpacity(0.12);
                    }
                  } else {
                    label      = "CANCELLED";
                    accentColor = Colors.white38;
                    iconData   = Icons.cancel_outlined;
                    iconBg     = Colors.white.withOpacity(0.05);
                  }

                  // Optional: show opponent name if available
                  final bool isPlayer1 = duel['player1'] == user?.uid;
                  final String opponentName = isPlayer1
                      ? (duel['player2Name'] ?? 'Unknown')
                      : (duel['player1Name'] ?? 'Unknown');

                  // Format date
                  String dateStr = "";
                  if (duel['createdAt'] != null) {
                    final ts = (duel['createdAt'] as Timestamp).toDate();
                    dateStr = "${ts.day}/${ts.month}/${ts.year}";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(
                          duel['status'] == 'completed' ? 0.35 : 0.15,
                        ),
                        width: 1.2,
                      ),
                    ),
                    child: Row(children: [
                      // Icon circle
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                        child: Icon(iconData, color: accentColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      // Info
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          if (opponentName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              "vs $opponentName",
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ]),
                      ),
                      // Date + badge
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            duel['status'] == 'completed' ? "COMPLETED" : "CANCELLED",
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  );
                }),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ]),
      ),
    );
  }
}