import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _getRank(int xp) {
    if (xp < 1500) return 'E';
    if (xp < 5000) return 'D';
    if (xp < 12000) return 'C';
    if (xp < 30000) return 'B';
    if (xp < 80000) return 'A';
    return 'S';
  }

  String _getNextRank(String rank) {
    const ranks = ['E', 'D', 'C', 'B', 'A', 'S'];
    final idx = ranks.indexOf(rank);
    return idx < ranks.length - 1 ? ranks[idx + 1] : 'MAX';
  }

  int _xpForRank(String rank) {
    switch (rank) {
      case 'E': return 1500;
      case 'D': return 5000;
      case 'C': return 12000;
      case 'B': return 30000;
      case 'A': return 80000;
      default:  return 80000;
    }
  }

  int _xpStartForRank(String rank) {
    switch (rank) {
      case 'E': return 0;
      case 'D': return 1500;
      case 'C': return 5000;
      case 'B': return 12000;
      case 'A': return 30000;
      default:  return 80000;
    }
  }

  String _getHunterClass(double bmi) {
    if (bmi < 18.5) return 'AGILE HUNTER';
    if (bmi < 25)   return 'BALANCED HUNTER';
    if (bmi < 30)   return 'TANK HUNTER';
    return 'HEAVY TANK HUNTER';
  }

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'S': return const Color(0xFFFF4444);
      case 'A': return const Color(0xFFFF8800);
      case 'B': return const Color(0xFF9B59B6);
      case 'C': return const Color(0xFF3498DB);
      case 'D': return const Color(0xFF2ECC71);
      default:  return const Color(0xFF64C8FF);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF64C8FF)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final hunterName     = data['hunterName'] ?? 'Unknown Hunter';
          final xp             = (data['xp'] ?? 0) as int;
          final level          = (data['level'] ?? 1) as int;
          final duelWins       = (data['duelWins'] ?? 0) as int;
          final duelLosses     = (data['duelLosses'] ?? 0) as int;
          final questsDone     = (data['questsDone'] ?? 0) as int;
          final totalDuels     = duelWins + duelLosses;

          final height         = (data['height'] ?? 0).toDouble();
          final weight         = (data['weight'] ?? 0).toDouble();
          final startingWeight = (data['startingWeight'] ?? weight).toDouble();

          double bmi = 0;
          if (height > 0) bmi = weight / math.pow(height / 100, 2);

          final rank        = _getRank(xp);
          final nextRank    = _getNextRank(rank);
          final rankColor   = _getRankColor(rank);
          final xpStart     = _xpStartForRank(rank);
          final xpEnd       = _xpForRank(rank);
          final xpProgress  = rank == 'S'
              ? 1.0
              : (xp - xpStart) / math.max(1, xpEnd - xpStart);
          final xpToNext    = rank == 'S' ? 0 : math.max(0, xpEnd - xp);

          // Derived stats
          final str  = math.min(100, duelWins * 3 + level * 2);
          final end_ = math.min(100, level * 4 + (weight > 0 ? 10 : 0));
          final agi  = bmi > 0 && bmi < 25
              ? math.min(100, (100 - bmi * 2).round())
              : 50;
          final vit  = weight > 0 ? 65 : 40;
          final int_ = math.min(100, questsDone * 2 + level);
          final luk  = math.min(100, duelWins * 5);

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            rankColor.withOpacity(0.15),
                            const Color(0xFF0A0C14),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Back button row
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios,
                                      color: Colors.white70, size: 20),
                                ),
                              ],
                            ),
                            // Avatar
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: rankColor.withOpacity(0.5),
                                        blurRadius: 30,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                    border: Border.all(
                                        color: rankColor, width: 2.5),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 53,
                                  backgroundColor: const Color(0xFF1A1D2E),
                                  child: Icon(Icons.person,
                                      size: 60,
                                      color: rankColor.withOpacity(0.9)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ── Name — pencil icon REMOVED ──
                            Text(
                              hunterName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),

                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: rankColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: rankColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                '$rank RANK HUNTER',
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // XP bar
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rank == 'S'
                                          ? 'MAX RANK'
                                          : '$xpToNext XP to Rank $nextRank',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '$xp XP',
                                      style: const TextStyle(
                                        color: Color(0xFF64C8FF),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: xpProgress.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                    Colors.white.withOpacity(0.1),
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(rankColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            // Level / Quests / Duels row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _statPill('$level', 'LEVEL'),
                                _vDivider(),
                                _statPill('$questsDone', 'QUESTS'),
                                _vDivider(),
                                _statPill('$duelWins', 'DUELS WON'),
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

              // ── Tab bar ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF64C8FF),
                    unselectedLabelColor: Colors.white38,
                    indicatorColor: const Color(0xFF64C8FF),
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    tabs: const [
                      Tab(text: 'OVERVIEW'),
                      Tab(text: 'PHYSIQUE'),
                      Tab(text: 'HISTORY'),
                    ],
                  ),
                ),
              ),

              // ── Tab content ─────────────────────────────────────────
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [

                    // ── OVERVIEW ──────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HUNTER STATS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: HexRadarPainter(values: [
                                  str / 100.0,
                                  int_ / 100.0,
                                  vit / 100.0,
                                  agi / 100.0,
                                  luk / 100.0,
                                  end_ / 100.0,
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _statBar('STR', str,  const Color(0xFF64C8FF)),
                          _statBar('END', end_, const Color(0xFF9B59B6)),
                          _statBar('AGI', agi,  const Color(0xFF64C8FF)),
                          _statBar('VIT', vit,  const Color(0xFF2ECC71)),
                          _statBar('INT', int_, const Color(0xFF64C8FF)),
                          _statBar('LUK', luk,  const Color(0xFFFFD700)),
                          const SizedBox(height: 24),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DUEL RECORD',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                                  children: [
                                    _duelStat('$duelWins', 'WINS',
                                        const Color(0xFF2ECC71)),
                                    _duelStat('$duelLosses', 'LOSSES',
                                        const Color(0xFFE74C3C)),
                                    _duelStat(
                                      totalDuels == 0
                                          ? '0%'
                                          : '${(duelWins * 100 / totalDuels).toStringAsFixed(0)}%',
                                      'WIN RATE',
                                      const Color(0xFFFFD700),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── PHYSIQUE ──────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _card(
                            child: Column(
                              children: [
                                Text(
                                  '🔥 ${_getHunterClass(bmi)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                                  children: [
                                    _physiqueInfo('BMI',
                                        bmi.toStringAsFixed(1),
                                        Icons.monitor_heart_outlined),
                                    _physiqueInfo('START',
                                        '${startingWeight.toStringAsFixed(1)} kg',
                                        Icons.flag_outlined),
                                    _physiqueInfo('CURRENT',
                                        '${weight.toStringAsFixed(1)} kg',
                                        Icons.monitor_weight_outlined),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        weight <= startingWeight
                                            ? Icons.trending_down
                                            : Icons.trending_up,
                                        color: weight <= startingWeight
                                            ? const Color(0xFF2ECC71)
                                            : const Color(0xFFE74C3C),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(weight - startingWeight).abs().toStringAsFixed(1)} kg ${weight <= startingWeight ? "lost" : "gained"} since start',
                                        style: TextStyle(
                                          color: weight <= startingWeight
                                              ? const Color(0xFF2ECC71)
                                              : const Color(0xFFE74C3C),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF64C8FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: showUpdateWeightDialog,
                              icon: const Icon(Icons.monitor_weight),
                              label: const Text(
                                'UPDATE WEIGHT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── HISTORY — weight history inline, no separate page ──
                    _buildWeightHistoryTab(user),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Inline Weight History Tab ──────────────────────────────────────
  Widget _buildWeightHistoryTab(User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('weight_history')
          .where('uid', isEqualTo: user?.uid)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString(),
                style: const TextStyle(color: Colors.red)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF64C8FF)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_weight_outlined,
                    color: Colors.white24, size: 64),
                SizedBox(height: 16),
                Text('No weight history yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
                SizedBox(height: 8),
                Text('Update your weight in the Physique tab',
                    style: TextStyle(color: Colors.white24, fontSize: 13)),
              ],
            ),
          );
        }

        final currentWeight  = (docs.first['weight'] as num).toDouble();
        final startingWeight = (docs.last['weight']  as num).toDouble();
        final weightLost     = startingWeight - currentWeight;

        String title;
        String message;
        if (weightLost >= 20) {
          title   = "👑 Legendary Hunter";
          message = "This isn't luck. This is discipline.";
        } else if (weightLost >= 10) {
          title   = "⭐ Elite Progress";
          message = "You are becoming the person you promised yourself you'd be.";
        } else if (weightLost >= 5) {
          title   = "🏆 Transformation Begins";
          message = "Most hunters quit early. You didn't.";
        } else if (weightLost >= 3) {
          title   = "⚔️ Momentum Rising";
          message = "Your consistency is becoming visible.";
        } else if (weightLost > 0) {
          title   = "🔥 First Victories";
          message = "You've started the journey. Keep moving forward, Hunter.";
        } else {
          title   = "🌱 New Hunter";
          message = "Every Hunter starts somewhere.";
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111523),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF64C8FF).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      weightLost >= 0
                          ? "🔥 Total Lost: ${weightLost.toStringAsFixed(1)} kg"
                          : "📈 Total Gained: ${weightLost.abs().toStringAsFixed(1)} kg",
                      style: TextStyle(
                        color: weightLost >= 0
                            ? Colors.greenAccent
                            : const Color(0xFFE74C3C),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Entry list
              ...docs.map((doc) {
                final d    = doc.data() as Map<String, dynamic>;
                final w    = (d['weight'] as num).toDouble();
                final date = (d['date'] as Timestamp).toDate();
                final dateStr =
                    "${date.day.toString().padLeft(2, '0')}/"
                    "${date.month.toString().padLeft(2, '0')}/"
                    "${date.year}";

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111523),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF64C8FF).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64C8FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.monitor_weight_outlined,
                            color: Color(0xFF64C8FF), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(dateStr,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ),
                      Text(
                        '${w.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────

  Widget _statPill(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 36, width: 1, color: Colors.white12);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF111523),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: const Color(0xFF64C8FF).withOpacity(0.2)),
    ),
    child: child,
  );

  Widget _statBar(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100.0,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _duelStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _physiqueInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF64C8FF), size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  void showUpdateWeightDialog() {
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111523),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Current Weight',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: weightController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Weight in kg',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                const BorderSide(color: Color(0xFF64C8FF), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                const BorderSide(color: Color(0xFF64C8FF), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64C8FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final weight =
                double.tryParse(weightController.text);
                if (weight == null) return;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                await FirebaseFirestore.instance
                    .collection('hunters')
                    .doc(user.uid)
                    .update({'weight': weight});

                await FirebaseFirestore.instance
                    .collection('weight_history')
                    .add({
                  'uid': user.uid,
                  'weight': weight,
                  'date': Timestamp.now(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: const Text('SAVE',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// ── Hex Radar Chart ────────────────────────────────────────────────────

class HexRadarPainter extends CustomPainter {
  final List<double> values;

  const HexRadarPainter({required this.values});

  static const _labels = ['STR', 'INT', 'VIT', 'AGI', 'LUK', 'END'];

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final maxR = size.height * 0.38;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 5; ring++) {
      canvas.drawPath(_hexPath(cx, cy, maxR * ring / 5), gridPaint);
    }

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxR * math.cos(angle), cy + maxR * math.sin(angle)),
        gridPaint,
      );
    }

    final dataPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final r = maxR * values[i].clamp(0.0, 1.0);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();

    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = const Color(0xFF64C8FF).withOpacity(0.18));
    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF64C8FF).withOpacity(0.85)
          ..strokeWidth = 1.5);

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final lx = cx + (maxR + 26) * math.cos(angle);
      final ly = cy + (maxR + 26) * math.sin(angle);
      final displayValue = (values[i] * 100).round();

      _drawText(canvas, _labels[i], lx, ly - 7,
          const Color(0xFF64C8FF), 11, FontWeight.bold);
      _drawText(canvas, '$displayValue', lx, ly + 8,
          Colors.white70, 11, FontWeight.normal);
    }
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  void _drawText(Canvas canvas, String text, double x, double y,
      Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant HexRadarPainter old) =>
      old.values != values;
}