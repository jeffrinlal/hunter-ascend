import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'dart:io';

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
      case 'S': return HunterTheme.danger;
      case 'A': return HunterTheme.primary;
      case 'B': return HunterTheme.purple;
      case 'C': return HunterTheme.info;
      case 'D': return HunterTheme.successAlt;
      default:  return HunterTheme.primary;
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
      backgroundColor: HunterTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: HunterTheme.primary),
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
                            HunterTheme.background,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios,
                                    color: HunterTheme.textSecondary,
                                    size: 20,
                                  ),
                                ),

                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.settings,
                                    color: HunterTheme.textSecondary,
                                    size: 24,
                                  ),
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
                                GestureDetector(
                                  onTap: _uploadProfilePicture,
                                  child: CircleAvatar(
                                    radius: 53,
                                    backgroundColor: HunterTheme.cardColor,
                                    backgroundImage: data['profilePicture'] != null
                                        ? MemoryImage(base64Decode(data['profilePicture']))
                                        : null,
                                    child: data['profilePicture'] == null
                                        ? Icon(Icons.person,
                                        size: 60,
                                        color: rankColor.withOpacity(0.9))
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _uploadProfilePicture,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: HunterTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: HunterTheme.background,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.black,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ── Name — pencil icon REMOVED ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  hunterName,
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: hunterName),
                                    );

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Hunter name copied!'),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.copy,
                                    color: HunterTheme.primary,
                                    size: 18,
                                  ),
                                ),
                              ],
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
                                        color: HunterTheme.textPrimary.withOpacity(0.65),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '$xp XP',
                                      style: TextStyle(
                                        color: HunterTheme.primary,
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
                                    HunterTheme.textPrimary.withOpacity(0.1),
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
                          color: HunterTheme.textPrimary.withOpacity(0.08)),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: HunterTheme.primary,
                    unselectedLabelColor: HunterTheme.textTertiary,
                    indicatorColor: HunterTheme.primary,
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
                          Text(
                            'MUSCLE MAP',
                            style: TextStyle(
                              color: HunterTheme.textSecondary,
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your physique, powered by hunter stats',
                            style: TextStyle(
                              color: HunterTheme.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: SizedBox(
                              height: 380,
                              width: double.infinity,
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: MuscleMapPainter(
                                  str: str.toDouble(),
                                  end: end_.toDouble(),
                                  agi: agi.toDouble(),
                                  vit: vit.toDouble(),
                                  intel: int_.toDouble(),
                                  luk: luk.toDouble(),
                                  glow: HunterTheme.primary,
                                  silhouette:
                                      HunterTheme.textPrimary.withOpacity(0.10),
                                  inactive:
                                      HunterTheme.textPrimary.withOpacity(0.20),
                                  label: HunterTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _muscleLegend('STR', 'Chest + Arms', str),
                          _muscleLegend('VIT', 'Core / Abs', vit),
                          _muscleLegend('AGI', 'Legs', agi),
                          _muscleLegend('INT', 'Head', int_),
                          _muscleLegend('END', 'Full Body', end_),
                          _muscleLegend('LUK', 'Aura', luk),
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
                                  style: TextStyle(
                                    color: HunterTheme.gold,
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
                                    color: HunterTheme.textPrimary.withOpacity(0.05),
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
                                            ? HunterTheme.successAlt
                                            : HunterTheme.dangerAlt,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(weight - startingWeight).abs().toStringAsFixed(1)} kg ${weight <= startingWeight ? "lost" : "gained"} since start',
                                        style: TextStyle(
                                          color: weight <= startingWeight
                                              ? HunterTheme.successAlt
                                              : HunterTheme.dangerAlt,
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
                                backgroundColor: HunterTheme.primary,
                                foregroundColor: Colors.white,
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
          return Center(
            child: CircularProgressIndicator(color: HunterTheme.primary),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_weight_outlined,
                    color: HunterTheme.textFaint, size: 64),
                SizedBox(height: 16),
                Text('No weight history yet',
                    style: TextStyle(color: HunterTheme.textTertiary, fontSize: 16)),
                SizedBox(height: 8),
                Text('Update your weight in the Physique tab',
                    style: TextStyle(color: HunterTheme.textFaint, fontSize: 13)),
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
                  color: HunterTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HunterTheme.primary.withOpacity(0.5)),
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
                            : HunterTheme.dangerAlt,
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
                        style: TextStyle(color: HunterTheme.textSecondary)),
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
                    color: HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: HunterTheme.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunterTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.monitor_weight_outlined,
                            color: HunterTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(dateStr,
                            style: TextStyle(
                                color: HunterTheme.textSecondary, fontSize: 13)),
                      ),
                      Text(
                        '${w.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
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
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 36, width: 1, color: Color(0x1FFF6B2B));

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: HunterTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: HunterTheme.primary.withOpacity(0.2)),
    ),
    child: child,
  );

  Widget _muscleLegend(String stat, String muscle, int value) {
    final pct = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              stat,
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      muscle,
                      style: TextStyle(
                        color: HunterTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$value%',
                      style: TextStyle(
                        color: HunterTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: HunterTheme.textPrimary.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HunterTheme.primary.withOpacity(0.4 + pct * 0.6),
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

  Widget _physiqueInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: HunterTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }
  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (picked == null) return;

    final file = File(picked.path);

    // Compress to max 15KB
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 200,
      minHeight: 200,
      quality: 30,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) return;

    // Convert to base64
    final base64Image = base64Encode(compressed);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .update({'profilePicture': base64Image});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile picture updated!')),
      );
    }
  }

  void showUpdateWeightDialog() {
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: HunterTheme.cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Update Current Weight',
              style: TextStyle(color: HunterTheme.textPrimary)),
          content: TextField(
            controller: weightController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: HunterTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Weight in kg',
              hintStyle: TextStyle(color: HunterTheme.textTertiary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: HunterTheme.primary, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: HunterTheme.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL',
                  style: TextStyle(color: HunterTheme.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HunterTheme.primary,
                foregroundColor: Colors.white,
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
      ..color = HunterTheme.textPrimary.withOpacity(0.08)
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
          ..color = HunterTheme.primary.withOpacity(0.18));
    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = HunterTheme.primary.withOpacity(0.85)
          ..strokeWidth = 1.5);

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final lx = cx + (maxR + 26) * math.cos(angle);
      final ly = cy + (maxR + 26) * math.sin(angle);
      final displayValue = (values[i] * 100).round();

      _drawText(canvas, _labels[i], lx, ly - 7,
          HunterTheme.primary, 11, FontWeight.bold);
      _drawText(canvas, '$displayValue', lx, ly + 8,
          HunterTheme.textSecondary, 11, FontWeight.normal);
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


// ── AI Muscle Body Map ──────────────────────────────────────────────────
//
// Front-view silhouette whose muscle groups glow based on existing Firestore
// stats (read-only). Mapping:
//   STR -> Chest + Arms   END -> Full-body base tint   AGI -> Legs
//   VIT -> Core/Abs       INT -> Head                  LUK -> Aura sparkles
class MuscleMapPainter extends CustomPainter {
  final double str, end, agi, vit, intel, luk;
  final Color glow;       // active muscle glow (#FF6B2B in light)
  final Color silhouette; // body base
  final Color inactive;   // low-stat muscle
  final Color label;      // text labels

  MuscleMapPainter({
    required this.str,
    required this.end,
    required this.agi,
    required this.vit,
    required this.intel,
    required this.luk,
    required this.glow,
    required this.silhouette,
    required this.inactive,
    required this.label,
  });

  Color _muscle(double pct) =>
      Color.lerp(inactive, glow, pct.clamp(0.0, 1.0))!;

  void _fill(Canvas c, Path p, Color color, {double glowSigma = 0}) {
    if (glowSigma > 0.5) {
      c.drawPath(
        p,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
      );
    }
    c.drawPath(p, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _sparkle(Canvas c, Offset o, double r, Color col) {
    final p = Paint()
      ..color = col
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r * 0.25, o.dy - r * 0.25)
      ..lineTo(o.dx + r, o.dy)
      ..lineTo(o.dx + r * 0.25, o.dy + r * 0.25)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r * 0.25, o.dy + r * 0.25)
      ..lineTo(o.dx - r, o.dy)
      ..lineTo(o.dx - r * 0.25, o.dy - r * 0.25)
      ..close();
    c.drawPath(path, p);
  }

  void _text(Canvas c, String s, Offset o) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: label,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    final strP = (str / 100).clamp(0.0, 1.0);
    final agiP = (agi / 100).clamp(0.0, 1.0);
    final vitP = (vit / 100).clamp(0.0, 1.0);
    final intP = (intel / 100).clamp(0.0, 1.0);
    final endP = (end / 100).clamp(0.0, 1.0);
    final lukP = (luk / 100).clamp(0.0, 1.0);

    // ── Body part paths ──
    final head = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, h * 0.085), radius: h * 0.055));
    final neck = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, h * 0.155), width: w * 0.07, height: h * 0.045),
          const Radius.circular(4)));
    final torso = Path()
      ..moveTo(cx - w * 0.20, h * 0.19)
      ..lineTo(cx + w * 0.20, h * 0.19)
      ..lineTo(cx + w * 0.15, h * 0.50)
      ..lineTo(cx - w * 0.15, h * 0.50)
      ..close();
    final leftArm = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.285, h * 0.195, w * 0.085, h * 0.30),
          Radius.circular(w * 0.04)));
    final rightArm = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + w * 0.20, h * 0.195, w * 0.085, h * 0.30),
          Radius.circular(w * 0.04)));
    final leftLeg = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - w * 0.145, h * 0.50, w * 0.12, h * 0.42),
          Radius.circular(w * 0.05)));
    final rightLeg = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + w * 0.025, h * 0.50, w * 0.12, h * 0.42),
          Radius.circular(w * 0.05)));
    final chestL = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(cx - w * 0.085, h * 0.255),
          width: w * 0.16,
          height: h * 0.085));
    final chestR = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(cx + w * 0.085, h * 0.255),
          width: w * 0.16,
          height: h * 0.085));
    final abs = Path();
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 2; col++) {
        final ax = cx + (col == 0 ? -w * 0.055 : w * 0.005);
        final ay = h * 0.335 + row * h * 0.052;
        abs.addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(ax, ay, w * 0.05, h * 0.042),
            const Radius.circular(3)));
      }
    }

    // ── 1. Base silhouette (END tints the whole body) ──
    final baseColor = Color.lerp(silhouette, glow, endP * 0.30)!;
    for (final p in [head, neck, torso, leftArm, rightArm, leftLeg, rightLeg]) {
      _fill(canvas, p, baseColor);
    }

    // ── 2. Muscle overlays ──
    _fill(canvas, head, _muscle(intP).withOpacity(0.85), glowSigma: 6 * intP); // INT
    _fill(canvas, chestL, _muscle(strP), glowSigma: 10 * strP);                // STR
    _fill(canvas, chestR, _muscle(strP), glowSigma: 10 * strP);
    _fill(canvas, leftArm, _muscle(strP * 0.9), glowSigma: 8 * strP);
    _fill(canvas, rightArm, _muscle(strP * 0.9), glowSigma: 8 * strP);
    _fill(canvas, abs, _muscle(vitP), glowSigma: 8 * vitP);                    // VIT
    _fill(canvas, leftLeg, _muscle(agiP), glowSigma: 10 * agiP);               // AGI
    _fill(canvas, rightLeg, _muscle(agiP), glowSigma: 10 * agiP);

    // Outline for definition
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = glow.withOpacity(0.25);
    for (final p in [head, torso, leftArm, rightArm, leftLeg, rightLeg]) {
      canvas.drawPath(p, stroke);
    }

    // ── 3. LUK aura sparkles ──
    final sparkN = (lukP * 8).round();
    final spots = [
      Offset(cx - w * 0.34, h * 0.12),
      Offset(cx + w * 0.34, h * 0.16),
      Offset(cx - w * 0.32, h * 0.56),
      Offset(cx + w * 0.33, h * 0.50),
      Offset(cx - w * 0.06, h * 0.02),
      Offset(cx + w * 0.30, h * 0.82),
      Offset(cx - w * 0.34, h * 0.80),
      Offset(cx + w * 0.12, h * 0.01),
    ];
    for (int i = 0; i < sparkN && i < spots.length; i++) {
      _sparkle(canvas, spots[i], w * 0.02, glow.withOpacity(0.5 + lukP * 0.5));
    }

    // ── 4. Labels (percentage out of 100) ──
    _text(canvas, 'INT ${intel.round()}%', Offset(cx + w * 0.12, h * 0.04));
    _text(canvas, 'STR ${str.round()}%', Offset(cx - w * 0.49, h * 0.24));
    _text(canvas, 'VIT ${vit.round()}%', Offset(cx + w * 0.17, h * 0.40));
    _text(canvas, 'AGI ${agi.round()}%', Offset(cx - w * 0.49, h * 0.66));
    _text(canvas, 'END ${end.round()}%', Offset(cx - w * 0.49, h * 0.04));
    _text(canvas, 'LUK ${luk.round()}%', Offset(cx + w * 0.17, h * 0.82));
  }

  @override
  bool shouldRepaint(covariant MuscleMapPainter old) =>
      old.str != str ||
      old.end != end ||
      old.agi != agi ||
      old.vit != vit ||
      old.intel != intel ||
      old.luk != luk ||
      old.glow != glow ||
      old.silhouette != silhouette ||
      old.inactive != inactive ||
      old.label != label;
}
