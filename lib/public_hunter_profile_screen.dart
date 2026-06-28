import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'compare_hunters_screen.dart';
import 'create_duel_screen.dart';

class PublicHunterProfileScreen extends StatelessWidget {
  final String hunterUid;

  const PublicHunterProfileScreen({
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

  String _getRankTitle(int level) {
    if (level >= 30) return 'S RANK HUNTER';
    if (level >= 20) return 'A RANK HUNTER';
    if (level >= 15) return 'B RANK HUNTER';
    if (level >= 10) return 'C RANK HUNTER';
    if (level >= 5)  return 'D RANK HUNTER';
    return 'E RANK HUNTER';
  }

  Color _getRankColor(int level) {
    if (level >= 30) return HunterTheme.gold;
    if (level >= 20) return HunterTheme.danger;
    if (level >= 15) return HunterTheme.primary;
    if (level >= 10) return HunterTheme.primary;
    if (level >= 5)  return HunterTheme.success;
    return HunterTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .doc(hunterUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: HunterTheme.primary),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final level    = (data['level'] ?? 1) as int;
          final xp       = (data['xp'] ?? 0) as int;
          final wins     = (data['duelWins'] ?? 0) as int;
          final losses   = (data['duelLosses'] ?? 0) as int;
          final name     = data['hunterName'] ?? 'Unknown Hunter';
          final streak   = (data['streak'] ?? 0) as int;
          final rank     = _getRank(level);
          final rankTitle= _getRankTitle(level);
          final rankColor= _getRankColor(level);
          final total    = wins + losses;
          final winRate  = total == 0 ? 0 : ((wins * 100) / total).round();

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Background glow
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            rankColor.withOpacity(0.12),
                            HunterTheme.background,
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Back button
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios,
                                      color: HunterTheme.textSecondary, size: 20),
                                ),
                                const Spacer(),
                                // Rank pill top right
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: rankColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    rankTitle,
                                    style: TextStyle(
                                      color: rankColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Avatar + rank badge
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer glow ring
                                Container(
                                  width: 116, height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: rankColor.withOpacity(0.4),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                    border: Border.all(
                                        color: rankColor, width: 2.5),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: HunterTheme.cardColor,
                                  backgroundImage: data['profilePicture'] != null
                                      ? MemoryImage(
                                    base64Decode(data['profilePicture']),
                                  )
                                      : null,
                                  child: data['profilePicture'] == null
                                      ? const Icon(Icons.person, size: 50)
                                      : null,
                                ),
                                // Rank letter badge bottom-right
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      color: HunterTheme.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: rankColor, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: rankColor.withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        rank,
                                        style: TextStyle(
                                          color: rankColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Name
                            Text(
                              name,
                              style: const TextStyle(
                                color: HunterTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Level · Streak row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _infoPill(
                                    Icons.bolt, 'LV.$level', HunterTheme.primary),
                                const SizedBox(width: 10),
                                _infoPill(Icons.local_fire_department,
                                    '$streak DAY STREAK', Colors.orange),
                                const SizedBox(width: 10),
                                _infoPill(Icons.star,
                                    '$xp XP', HunterTheme.success),
                              ],
                            ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Stats Section ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // Section label
                      _sectionLabel('DUEL RECORD'),
                      const SizedBox(height: 12),

                      // Win / Loss / Rate row
                      Row(
                        children: [
                          Expanded(child: _duelStatCard(
                              '$wins', 'WINS', HunterTheme.success)),
                          const SizedBox(width: 10),
                          Expanded(child: _duelStatCard(
                              '$losses', 'LOSSES', HunterTheme.danger)),
                          const SizedBox(width: 10),
                          Expanded(child: _duelStatCard(
                              '$winRate%', 'WIN RATE', HunterTheme.gold)),
                        ],
                      ),

                      const SizedBox(height: 24),
                      _sectionLabel('HUNTER INFO'),
                      const SizedBox(height: 12),

                      // Info tiles
                      _infoRow(Icons.bolt, 'Level', 'LV.$level',
                          HunterTheme.primary),
                      _infoRow(Icons.emoji_events, 'Total XP', '$xp XP',
                          HunterTheme.success),
                      _infoRow(Icons.local_fire_department, 'Streak',
                          '$streak Days', Colors.orange),
                      _infoRow(Icons.sports_kabaddi, 'Total Duels',
                          '$total', HunterTheme.primary),

                      const SizedBox(height: 28),

                      // ── Action Buttons ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HunterTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompareHuntersScreen(
                                  hunterUid: hunterUid,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.compare_arrows, size: 20),
                          label: const Text(
                            'COMPARE HUNTERS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HunterTheme.danger.withOpacity(0.12),
                            foregroundColor: HunterTheme.danger,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                  color: HunterTheme.danger, width: 1.5),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateDuelScreen(
                                  hunterName: data['hunterName'],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sports_kabaddi, size: 20),
                          label: const Text(
                            'CHALLENGE HUNTER',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────

  Widget _infoPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
              color: HunterTheme.primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _duelStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunterTheme.border, width: 1),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}