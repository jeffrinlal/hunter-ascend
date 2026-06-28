import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuestSelectionScreen extends StatefulWidget {
  const QuestSelectionScreen({super.key});

  @override
  State<QuestSelectionScreen> createState() => _QuestSelectionScreenState();
}

class _QuestSelectionScreenState extends State<QuestSelectionScreen>
    with TickerProviderStateMixin {
  bool fatLoss = false;
  bool discipline = false;
  bool muscleGain = false;
  bool selfImprovement = false;

  double _weight = 0;
  double _height = 0;
  int _age = 0;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _loadHunterData();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadHunterData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    setState(() {
      _weight = (data['weight'] ?? 70).toDouble();
      _height = (data['height'] ?? 170).toDouble();
      _age = data['age'] ?? 25;
    });
  }

// Path data: icon, title, subtitle, getter, setter
  List<Map<String, dynamic>> get _paths => [
    {
      'icon': Icons.local_fire_department_outlined,
      'title': 'FAT LOSS',
      'subtitle': 'Burn calories, shed weight, transform body',
      'value': fatLoss,
      'onChanged': (v) => setState(() => fatLoss = v),
    },
    {
      'icon': Icons.psychology_outlined,
      'title': 'DISCIPLINE',
      'subtitle': 'Build habits, master your mind daily',
      'value': discipline,
      'onChanged': (v) => setState(() => discipline = v),
    },
    {
      'icon': Icons.fitness_center_outlined,
      'title': 'MUSCLE GAIN',
      'subtitle': 'Grow strength, build mass, level up power',
      'value': muscleGain,
      'onChanged': (v) => setState(() => muscleGain = v),
    },
    {
      'icon': Icons.auto_awesome_outlined,
      'title': 'SELF IMPROVEMENT',
      'subtitle': 'Sharpen skills, grow as a hunter',
      'value': selfImprovement,
      'onChanged': (v) => setState(() => selfImprovement = v),
    },
  ];

  int get _selectedCount =>
      [fatLoss, discipline, muscleGain, selfImprovement]
          .where((v) => v)
          .length;

  List<Map<String, dynamic>> _generateBioQuests() {
    if (_height <= 0) return [];

    final bmi =
        _weight / ((_height / 100) * (_height / 100));

    final List<Map<String, dynamic>> quests = [];

    if (bmi >= 30) {
      quests.addAll([
        {"name": "Walk 3000 Steps", "xp": 30, "icon": Icons.directions_walk},
        {"name": "Drink 2.5L Water", "xp": 40, "icon": Icons.water_drop},
        {"name": "No Sugary Drinks Today", "xp": 50, "icon": Icons.no_drinks},
        {"name": "Eat Vegetables Today", "xp": 40, "icon": Icons.eco},
        {"name": "Sleep Before 11 PM", "xp": 30, "icon": Icons.bedtime},
        {"name": "Skip Junk Food Today", "xp": 50, "icon": Icons.no_food},
      ]);
    } else if (bmi >= 25) {
      quests.addAll([
        {"name": "Walk 5000 Steps", "xp": 40, "icon": Icons.directions_walk},
        {"name": "Drink 3L Water", "xp": 40, "icon": Icons.water_drop},
        {"name": "No Junk Food Today", "xp": 50, "icon": Icons.no_food},
        {"name": "Eat High Protein Meal", "xp": 50, "icon": Icons.restaurant},
        {"name": "Sleep 7+ Hours", "xp": 30, "icon": Icons.bedtime},
        {"name": "Avoid Late Night Snacks", "xp": 40, "icon": Icons.nights_stay},
      ]);
    } else if (bmi >= 18.5) {
      quests.addAll([
        {"name": "Walk 7000 Steps", "xp": 50, "icon": Icons.directions_walk},
        {"name": "Drink 3L Water", "xp": 40, "icon": Icons.water_drop},
        {"name": "Workout 30 Minutes", "xp": 75, "icon": Icons.fitness_center},
        {"name": "Eat 100g Protein", "xp": 50, "icon": Icons.restaurant},
        {"name": "Sleep 8 Hours", "xp": 40, "icon": Icons.bedtime},
        {"name": "No Screen 1hr Before Bed", "xp": 30, "icon": Icons.phone_android},
      ]);
    } else {
      quests.addAll([
        {"name": "Eat 3 Full Meals Today", "xp": 60, "icon": Icons.restaurant},
        {"name": "Drink 3L Water", "xp": 40, "icon": Icons.water_drop},
        {"name": "Eat 120g Protein", "xp": 75, "icon": Icons.fitness_center},
        {"name": "Sleep 8 Hours", "xp": 50, "icon": Icons.bedtime},
        {"name": "Strength Train Today", "xp": 80, "icon": Icons.fitness_center},
        {"name": "Eat Healthy Fats Today", "xp": 40, "icon": Icons.egg_alt},
      ]);
    }

    if (_age >= 40) {
      quests.removeWhere(
            (q) => q['name'] == 'Walk 7000 Steps',
      );

      quests.add({
        "name": "Walk 4000 Steps",
        "xp": 40,
        "icon": Icons.directions_walk,
      });

      quests.add({
        "name": "Stretch 10 Minutes",
        "xp": 25,
        "icon": Icons.self_improvement,
      });
    }

    if (_age >= 50) {
      quests.add({
        "name": "Light Yoga 15 Minutes",
        "xp": 30,
        "icon": Icons.self_improvement,
      });
    }

    return quests;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Grid
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPainter(),
          ),

          // Ambient top glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, _) => Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF6B2B)
                            .withOpacity(0.1 * _pulseAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, _) => _dot(_pulseAnim.value),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '[ CHOOSE YOUR PATH ]',
                          style: TextStyle(
                            color: Color(0xFFFF6B2B),
                            fontSize: 12,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, _) => _dot(_pulseAnim.value),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'HUNTER SPECIALIZATION',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Divider
                    Container(
                      width: 80,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFFFF6B2B),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B2B).withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Select all paths that apply to your mission',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A).withOpacity(0.3),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Path cards
                    Expanded(
                      child: ListView.separated(
                        itemCount: _paths.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final path = _paths[index];
                          final selected = path['value'] as bool;
                          return _PathCard(
                              icon: path['icon'] as IconData,
                              title: path['title'] as String,
                              subtitle: path['subtitle'] as String,
                              selected: selected,
                              onTap: () =>
                                  (path['onChanged'] as Function(bool))(!selected)
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Selected count indicator
                    if (_selectedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '$_selectedCount PATH${_selectedCount > 1 ? 'S' : ''} SELECTED',
                          style: const TextStyle(
                            color: Color(0xFFFF6B2B),
                            fontSize: 11,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Bottom buttons
                    Row(
                      children: [
                        // Skip


                        const SizedBox(width: 12),

                        // Generate quests
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () async {
                              if (!fatLoss &&
                                  !discipline &&
                                  !muscleGain &&
                                  !selfImprovement) {

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Select at least one path to continue.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final prefs =
                              await SharedPreferences.getInstance();
                              await prefs.setBool('hasCompletedSetup', true);

                              final uid = FirebaseAuth.instance.currentUser!.uid;

                              await FirebaseFirestore.instance
                                  .collection('hunters')
                                  .doc(uid)
                                  .update({
                                'fatLoss': fatLoss,
                                'discipline': discipline,
                                'muscleGain': muscleGain,
                                'selfImprovement': selfImprovement,
                              });
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DashboardScreen(
                                    fatLoss: fatLoss,
                                    discipline: discipline,
                                    muscleGain: muscleGain,
                                    selfImprovement: selfImprovement,
                                    bioQuests: _generateBioQuests(),
                                  ),
                                ),
                                    (route) => false,
                              );
                            },
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B2B),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B2B)
                                        .withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    color: Color(0xFFFAFAFA),
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'GENERATE MY QUESTS',
                                    style: TextStyle(
                                      color: Color(0xFFFAFAFA),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double opacity) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFF6B2B).withOpacity(opacity),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B2B).withOpacity(0.8),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

// ── Path selection card ───────────────────────────────────────────────────────

class _PathCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PathCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PathCard> createState() => _PathCardState();
}

class _PathCardState extends State<_PathCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleController;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFFF6B2B).withOpacity(0.08)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFFFF6B2B)
                  : const Color(0xFFFF6B2B).withOpacity(0.15),
              width: widget.selected ? 1.5 : 1,
            ),
            boxShadow: widget.selected
                ? [
              BoxShadow(
                color: const Color(0xFFFF6B2B).withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              // Icon box
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? const Color(0xFFFF6B2B).withOpacity(0.15)
                      : Color(0xFF1A1A1A).withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.selected
                        ? const Color(0xFFFF6B2B).withOpacity(0.5)
                        : Color(0xFF1A1A1A).withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.selected
                      ? const Color(0xFFFF6B2B)
                      : Color(0xFF1A1A1A).withOpacity(0.3),
                  size: 22,
                ),
              ),

              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.selected
                            ? const Color(0xFFFF6B2B)
                            : Color(0xFF1A1A1A).withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Color(0xFF1A1A1A).withOpacity(0.3),
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Checkbox indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? const Color(0xFFFF6B2B)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.selected
                        ? const Color(0xFFFF6B2B)
                        : Color(0xFF1A1A1A).withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: widget.selected
                      ? [
                    BoxShadow(
                      color:
                      const Color(0xFFFF6B2B).withOpacity(0.5),
                      blurRadius: 8,
                    ),
                  ]
                      : null,
                ),
                child: widget.selected
                    ? const Icon(
                  Icons.check,
                  color: Color(0xFFFAFAFA),
                  size: 14,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid background ───────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B2B).withOpacity(0.03)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}