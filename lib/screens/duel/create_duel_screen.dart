import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/duel/duel_history_screen.dart';

/// Form to create/send a duel challenge to another hunter.
class CreateDuelScreen extends StatefulWidget {
  final String? hunterName;

  const CreateDuelScreen({
    super.key,
    this.hunterName,
  });

  @override
  State<CreateDuelScreen> createState() => _CreateDuelScreenState();
}

class _CreateDuelScreenState extends State<CreateDuelScreen> {
  final TextEditingController hunterNameController = TextEditingController();
  final TextEditingController questController = TextEditingController();
  List<Map<String, dynamic>> duelQuests = [];
  @override
  void initState() {
    super.initState();

    if (widget.hunterName != null) {
      hunterNameController.text = widget.hunterName!;
    }
  }

  @override
  void dispose() {
    hunterNameController.dispose();
    questController.dispose();
    super.dispose();
  }

  void addQuest() {
    String questName = questController.text.trim();
    if (questName.isEmpty) return;

    bool alreadyExists = duelQuests.any(
          (quest) =>
      quest['name'].toString().toLowerCase() == questName.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mission already added")),
      );
      return;
    }

    if (duelQuests.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 10 missions allowed")),
      );
      return;
    }

    setState(() {
      duelQuests.add({'name': questName, 'xp': 50});
    });
    questController.clear();
  }

  void deleteQuest(int index) {
    setState(() {
      duelQuests.removeAt(index);
    });
  }

  Future<void> _submitDuel() async {
    // ── Auth check first ──────────────────────────────────────────
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to challenge")),
      );
      return;
    }

    if (hunterNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a Hunter Name")),
      );
      return;
    }

    if (duelQuests.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum 4 missions required")),
      );
      return;
    }


    final targetResult = await FirebaseFirestore.instance
        .collection('hunters')
        .where(
      'hunterName',
      isEqualTo: hunterNameController.text.trim(),
    )
        .limit(1)
        .get();

    if (targetResult.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hunter not found")),
      );
      return;
    }

    final targetHunter = targetResult.docs.first;
    final opponentId = targetHunter.id;
    if (opponentId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot challenge yourself")),
      );
      return;
    }

    // ── Optimised active-duel check (two targeted queries) ────────


    final activeDuelAsPlayer1 = await FirebaseFirestore.instance
        .collection('duels')
        .where('player1', isEqualTo: opponentId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    final activeDuelAsPlayer2 = await FirebaseFirestore.instance
        .collection('duels')
        .where('player2', isEqualTo: opponentId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    final targetHasActiveDuel =
        activeDuelAsPlayer1.docs.isNotEmpty ||
            activeDuelAsPlayer2.docs.isNotEmpty;

    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('duel_requests')
        .where('toUid', isEqualTo: opponentId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (targetHasActiveDuel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hunter is already in a duel")),
      );
      return;
    }

    if (pendingSnapshot.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hunter already has a pending challenge")),
      );
      return;
    }

    final myHunterDoc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    final myHunterName =
        myHunterDoc.data()?['hunterName'] ?? 'Unknown';

    await FirebaseFirestore.instance.collection('duel_requests').add({
      'fromUid': user.uid,
      'toUid': opponentId,

      'fromHunterName': myHunterName,
      'toHunterName': targetHunter['hunterName'],

      'status': 'pending',
      'duelQuests': duelQuests,
      'createdAt': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚔️ Duel challenge sent!")),
      );
      Navigator.pop(context);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.close, color: HunterTheme.dangerAlt, size: 20),
            SizedBox(width: 8),
            Text(
              'Create Duel',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: HunterTheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DuelHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // ── Arena banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HunterTheme.pinkSurface,
                    HunterTheme.roseSurface,
                    HunterTheme.background,
                  ],
                ),
                border: Border.all(
                  color: HunterTheme.dangerAlt.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HunterTheme.dangerAlt.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HunterTheme.dangerAlt.withOpacity(0.12),
                      border: Border.all(
                          color: HunterTheme.dangerAlt.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.sports_kabaddi,
                        color: HunterTheme.dangerAlt, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'DUEL ARENA',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a rivalry and challenge another Hunter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HunterTheme.textPrimary.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Your Hunter ID ─────────────────────────────
                    _sectionLabel('YOUR HUNTER NAME'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: HunterTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fingerprint,
                              color: HunterTheme.primary, size: 20),
                          const SizedBox(width: 10),
                        Expanded(
                          child: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('hunters')
                                .doc(FirebaseAuth.instance.currentUser!.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Text(
                                  'Loading...',
                                  style: TextStyle(color: HunterTheme.textTertiary),
                                );
                              }

                              final data =
                              snapshot.data!.data() as Map<String, dynamic>?;

                              return SelectableText(
                                data?['hunterName'] ?? 'Unknown Hunter',
                                style: TextStyle(
                                  color: HunterTheme.primary,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              );
                            },
                          ),
                        ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Opponent Hunter ID ─────────────────────────
                    _sectionLabel('OPPONENT HUNTER NAME'),
                    const SizedBox(height: 8),
                    _darkTextField(
                      controller: hunterNameController,
                      hint: 'Enter Hunter Name',
                      icon: Icons.person_search,
                    ),

                    const SizedBox(height: 20),

                    // ── Add Quest ──────────────────────────────────
                    _sectionLabel('ADD MISSION'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _darkTextField(
                            controller: questController,
                            hint: 'Mission name',
                            icon: Icons.gps_fixed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: addQuest,
                          child: Container(
                            width: 48,
                            height: 52,
                            decoration: BoxDecoration(
                              color: HunterTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: HunterTheme.primary
                                      .withOpacity(0.4)),
                            ),
                            child: Icon(Icons.add,
                                color: HunterTheme.primary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Quest list header ──────────────────────────
                    Row(
                      children: [
                        _sectionLabel('CUSTOM DUEL MISSIONS'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: duelQuests.length < 4
                                ? HunterTheme.dangerAlt.withOpacity(0.12)
                                : HunterTheme.successAlt.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: duelQuests.length < 4
                                  ? HunterTheme.dangerAlt.withOpacity(0.4)
                                  : HunterTheme.successAlt.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${duelQuests.length}/10',
                            style: TextStyle(
                              color: duelQuests.length < 4
                                  ? HunterTheme.dangerAlt
                                  : HunterTheme.successAlt,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Minimum quest hint
                    if (duelQuests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: HunterTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: HunterTheme.textPrimary.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_task,
                                color: HunterTheme.textFaint, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Add at least 4 missions to challenge',
                              style: TextStyle(
                                  color: HunterTheme.textTertiary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // Quest items
                    ...List.generate(duelQuests.length, (index) {
                      final quest = duelQuests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: HunterTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HunterTheme.dangerAlt.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                HunterTheme.dangerAlt.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.gps_fixed,
                                  color: HunterTheme.dangerAlt, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quest['name'],
                                    style: TextStyle(
                                      color: HunterTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mission Objective',
                                    style: TextStyle(
                                      color: HunterTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                HunterTheme.successAlt.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: HunterTheme.successAlt
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                '+50 XP',
                                style: TextStyle(
                                  color: HunterTheme.successAlt,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => deleteQuest(index),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                  HunterTheme.dangerAlt.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    color: HunterTheme.dangerAlt, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Challenge button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: duelQuests.length >= 4
                        ? HunterTheme.dangerAlt
                        : HunterTheme.cardColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: duelQuests.length >= 4
                            ? HunterTheme.dangerAlt
                            : Color(0x1FFF6B2B),
                      ),
                    ),
                    elevation: duelQuests.length >= 4 ? 8 : 0,
                    shadowColor: HunterTheme.dangerAlt.withOpacity(0.4),
                  ),
                  onPressed: _submitDuel,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.close, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'CHALLENGE HUNTER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: HunterTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: HunterTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: HunterTheme.primary, size: 20),
        filled: true,
        fillColor: HunterTheme.cardColor,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: HunterTheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HunterTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}