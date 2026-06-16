import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class CompareHuntersScreen extends StatelessWidget {
  final String hunterUid;

  const CompareHuntersScreen({
    super.key,
    required this.hunterUid,
  });

  String _getRank(int level) {
    if (level >= 30) return 'S';
    if (level >= 20) return 'A';
    if (level >= 15) return 'B';
    if (level >= 10) return 'C';
    if (level >= 5)  return 'D';
    return 'E';
  }

  Color _getRankColor(int level) {
    if (level >= 30) return const Color(0xFFFFD700);
    if (level >= 20) return const Color(0xFFFF4444);
    if (level >= 15) return const Color(0xFFFF8800);
    if (level >= 10) return const Color(0xFF44AAFF);
    if (level >= 5)  return const Color(0xFF44DD88);
    return const Color(0xFF8898BB);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF4D7CFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4D7CFF).withOpacity(0.4)),
              ),
              child: const Icon(Icons.compare_arrows,
                  color: Color(0xFF4D7CFF), size: 17),
            ),
            const SizedBox(width: 10),
            const Text(
              'HUNTER COMPARISON',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance.collection('hunters').doc(currentUid).get(),
          FirebaseFirestore.instance.collection('hunters').doc(hunterUid).get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4D7CFF)),
            );
          }

          final myData    = snapshot.data![0].data() as Map<String, dynamic>;
          final theirData = snapshot.data![1].data() as Map<String, dynamic>;

          final myWins     = (myData['duelWins']    ?? 0) as int;
          final myLosses   = (myData['duelLosses']  ?? 0) as int;
          final myXp       = (myData['xp']          ?? 0) as int;
          final myLevel    = (myData['level']        ?? 1) as int;
          final myStreak   = (myData['streak']       ?? 0) as int;

          final theirWins   = (theirData['duelWins']   ?? 0) as int;
          final theirLosses = (theirData['duelLosses'] ?? 0) as int;
          final theirXp     = (theirData['xp']         ?? 0) as int;
          final theirLevel  = (theirData['level']      ?? 1) as int;
          final theirStreak = (theirData['streak']     ?? 0) as int;

          final myWinRate    = myWins + myLosses == 0 ? 0
              : ((myWins * 100) / (myWins + myLosses)).round();
          final theirWinRate = theirWins + theirLosses == 0 ? 0
              : ((theirWins * 100) / (theirWins + theirLosses)).round();

          final myRankColor    = _getRankColor(myLevel);
          final theirRankColor = _getRankColor(theirLevel);

          // Verdict
          String verdictText;
          Color verdictColor;
          IconData verdictIcon;
          if (theirXp > myXp) {
            verdictText  = 'This hunter outranks you. Train harder.';
            verdictColor = const Color(0xFFFF4444);
            verdictIcon  = Icons.trending_down;
          } else if (theirXp < myXp) {
            verdictText  = 'You outrank this hunter. Stay sharp.';
            verdictColor = const Color(0xFF44DD88);
            verdictIcon  = Icons.trending_up;
          } else {
            verdictText  = 'You are perfectly matched. Duel to decide.';
            verdictColor = const Color(0xFFFFD700);
            verdictIcon  = Icons.balance;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ── Hunter Headers ───────────────────────────────────
                Row(
                  children: [
                    // Me
                    Expanded(
                      child: _hunterHeader(
                        myData['hunterName'] ?? 'You',
                        myLevel,
                        myRankColor,
                        myData['profilePicture'],
                        isMe: true,
                      ),
                    ),

                    // VS badge
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1120),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF1E2D4A), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4D7CFF).withOpacity(0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: Color(0xFF4D7CFF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    // Them
                    Expanded(
                      child: _hunterHeader(
                        theirData['hunterName'] ?? 'Hunter',
                        theirLevel,
                        theirRankColor,
                        theirData['profilePicture'],
                        isMe: false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Divider ──────────────────────────────────────────
                _sectionLabel('STAT COMPARISON'),
                const SizedBox(height: 14),

                // ── Comparison Rows ──────────────────────────────────
                _compareBar(
                  label: 'LEVEL',
                  myVal: myLevel,
                  theirVal: theirLevel,
                  myColor: myRankColor,
                  theirColor: theirRankColor,
                  displayMy: 'LV.$myLevel',
                  displayTheir: 'LV.$theirLevel',
                ),
                _compareBar(
                  label: 'TOTAL XP',
                  myVal: myXp,
                  theirVal: theirXp,
                  myColor: myRankColor,
                  theirColor: theirRankColor,
                  displayMy: '$myXp',
                  displayTheir: '$theirXp',
                ),
                _compareBar(
                  label: 'DUEL WINS',
                  myVal: myWins,
                  theirVal: theirWins,
                  myColor: const Color(0xFF44DD88),
                  theirColor: const Color(0xFF44DD88),
                  displayMy: '$myWins',
                  displayTheir: '$theirWins',
                ),
                _compareBar(
                  label: 'LOSSES',
                  myVal: myLosses,
                  theirVal: theirLosses,
                  myColor: const Color(0xFFFF4444),
                  theirColor: const Color(0xFFFF4444),
                  displayMy: '$myLosses',
                  displayTheir: '$theirLosses',
                  lowerIsBetter: true,
                ),
                _compareBar(
                  label: 'WIN RATE',
                  myVal: myWinRate,
                  theirVal: theirWinRate,
                  myColor: const Color(0xFFFFD700),
                  theirColor: const Color(0xFFFFD700),
                  displayMy: '$myWinRate%',
                  displayTheir: '$theirWinRate%',
                ),
                _compareBar(
                  label: 'STREAK',
                  myVal: myStreak,
                  theirVal: theirStreak,
                  myColor: Colors.orange,
                  theirColor: Colors.orange,
                  displayMy: '${myStreak}d',
                  displayTheir: '${theirStreak}d',
                ),

                const SizedBox(height: 24),

                // ── Verdict Card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: verdictColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: verdictColor.withOpacity(0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: verdictColor.withOpacity(0.08),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: verdictColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(verdictIcon, color: verdictColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          verdictText,
                          style: TextStyle(
                            color: verdictColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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

  // ── Hunter Header ────────────────────────────────────────────────
  Widget _hunterHeader(
      String name,
      int level,
      Color rankColor,
      String? profilePicture,
      {required bool isMe}
      ) {
    final rank = _getRank(level);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: rankColor.withOpacity(0.35), blurRadius: 16),
                ],
                color: const Color(0xFF0D1120),
              ),
              child: profilePicture != null &&
                  profilePicture.isNotEmpty
                  ? ClipOval(
                child: Image.memory(
                  base64Decode(profilePicture),
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              )
                  : Icon(
                Icons.person,
                color: rankColor,
                size: 38,
              ),
            ),
            Positioned(
              bottom: 0,
              right: isMe ? null : 0,
              left: isMe ? 0 : null,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF070B14),
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor, width: 1.5),
                ),
                child: Center(
                  child: Text(rank,
                      style: TextStyle(
                          color: rankColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? const Color(0xFF4D7CFF) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: rankColor.withOpacity(0.3)),
          ),
          child: Text(
            'LV.$level',
            style: TextStyle(
                color: rankColor,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Compare Bar ──────────────────────────────────────────────────
  Widget _compareBar({
    required String label,
    required num myVal,
    required num theirVal,
    required Color myColor,
    required Color theirColor,
    required String displayMy,
    required String displayTheir,
    bool lowerIsBetter = false,
  }) {
    final total = myVal + theirVal;
    final myFraction  = total == 0 ? 0.5 : (myVal / total).toDouble();
    final myWins      = lowerIsBetter ? myVal < theirVal : myVal > theirVal;
    final theirWins   = lowerIsBetter ? theirVal < myVal : theirVal > myVal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2D4A), width: 1),
      ),
      child: Column(
        children: [
          // Label + values
          Row(
            children: [
              // My value
              SizedBox(
                width: 60,
                child: Text(
                  displayMy,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: myWins ? myColor : Colors.white54,
                    fontSize: 14,
                    fontWeight: myWins ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              // Label center
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Their value
              SizedBox(
                width: 60,
                child: Text(
                  displayTheir,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theirWins ? theirColor : Colors.white54,
                    fontSize: 14,
                    fontWeight: theirWins ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: (myFraction * 100).round(),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: myWins
                          ? myColor
                          : myColor.withOpacity(0.35),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 100 - (myFraction * 100).round(),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: theirWins
                          ? theirColor
                          : theirColor.withOpacity(0.35),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Expanded(child: Container(height: 1,
          color: Colors.white.withOpacity(0.06))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
      ),
      Expanded(child: Container(height: 1,
          color: Colors.white.withOpacity(0.06))),
    ]);
  }
}