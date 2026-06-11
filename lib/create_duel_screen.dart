import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'duel_history_screen.dart';

class CreateDuelScreen extends StatefulWidget {
  const CreateDuelScreen({super.key});

  @override
  State<CreateDuelScreen> createState() => _CreateDuelScreenState();
}

class _CreateDuelScreenState extends State<CreateDuelScreen> {
  final TextEditingController hunterIdController = TextEditingController();
  final TextEditingController questController = TextEditingController();
  List<Map<String, dynamic>> duelQuests = [];

  void addQuest() {
    String questName = questController.text.trim();
    if (questName.isEmpty) return;

    bool alreadyExists = duelQuests.any(
          (quest) =>
      quest['name'].toString().toLowerCase() == questName.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quest already added")),
      );
      return;
    }

    if (duelQuests.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 10 quests allowed")),
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

    if (hunterIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a Hunter ID")),
      );
      return;
    }

    if (duelQuests.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimum 4 quests required")),
      );
      return;
    }

    if (hunterIdController.text.trim() == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot challenge yourself")),
      );
      return;
    }

    final targetHunter = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(hunterIdController.text.trim())
        .get();

    if (!targetHunter.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hunter not found")),
      );
      return;
    }

    // ── Optimised active-duel check (two targeted queries) ────────
    final opponentId = hunterIdController.text.trim();

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

    await FirebaseFirestore.instance.collection('duel_requests').add({
      'fromUid': user.uid,
      'toUid': opponentId,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0C14),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            Icon(Icons.close, color: Color(0xFFE74C3C), size: 20),
            SizedBox(width: 8),
            Text(
              'Create Duel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF64C8FF)),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0510),
                    Color(0xFF2A0A1A),
                    Color(0xFF0A0C2A),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFE74C3C).withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE74C3C).withOpacity(0.15),
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
                      color: const Color(0xFFE74C3C).withOpacity(0.12),
                      border: Border.all(
                          color: const Color(0xFFE74C3C).withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.sports_kabaddi,
                        color: Color(0xFFE74C3C), size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'DUEL ARENA',
                    style: TextStyle(
                      color: Colors.white,
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
                      color: Colors.white.withOpacity(0.55),
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
                    _sectionLabel('YOUR HUNTER ID'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111523),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF64C8FF).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fingerprint,
                              color: Color(0xFF64C8FF), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              FirebaseAuth.instance.currentUser?.uid ?? '',
                              style: const TextStyle(
                                color: Color(0xFF64C8FF),
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(
                                text:
                                FirebaseAuth.instance.currentUser?.uid ??
                                    '',
                              ));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Hunter ID copied!')),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                const Color(0xFF64C8FF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF64C8FF)
                                        .withOpacity(0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.copy,
                                      color: Color(0xFF64C8FF), size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'COPY',
                                    style: TextStyle(
                                      color: Color(0xFF64C8FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Opponent Hunter ID ─────────────────────────
                    _sectionLabel('OPPONENT HUNTER ID'),
                    const SizedBox(height: 8),
                    _darkTextField(
                      controller: hunterIdController,
                      hint: 'Paste Hunter ID here',
                      icon: Icons.person_search,
                    ),

                    const SizedBox(height: 20),

                    // ── Add Quest ──────────────────────────────────
                    _sectionLabel('ADD QUEST'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _darkTextField(
                            controller: questController,
                            hint: 'Quest name',
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
                              color: const Color(0xFF64C8FF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF64C8FF)
                                      .withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.add,
                                color: Color(0xFF64C8FF)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Quest list header ──────────────────────────
                    Row(
                      children: [
                        _sectionLabel('CUSTOM DUEL QUESTS'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: duelQuests.length < 4
                                ? const Color(0xFFE74C3C).withOpacity(0.12)
                                : const Color(0xFF2ECC71).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: duelQuests.length < 4
                                  ? const Color(0xFFE74C3C).withOpacity(0.4)
                                  : const Color(0xFF2ECC71).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${duelQuests.length}/10',
                            style: TextStyle(
                              color: duelQuests.length < 4
                                  ? const Color(0xFFE74C3C)
                                  : const Color(0xFF2ECC71),
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
                          color: const Color(0xFF111523),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_task,
                                color: Colors.white24, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Add at least 4 quests to challenge',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 13),
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
                          color: const Color(0xFF111523),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE74C3C).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                const Color(0xFFE74C3C).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.gps_fixed,
                                  color: Color(0xFFE74C3C), size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quest['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Mission Objective',
                                    style: TextStyle(
                                      color: Colors.white38,
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
                                const Color(0xFF2ECC71).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF2ECC71)
                                        .withOpacity(0.3)),
                              ),
                              child: const Text(
                                '+50 XP',
                                style: TextStyle(
                                  color: Color(0xFF2ECC71),
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
                                  const Color(0xFFE74C3C).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Color(0xFFE74C3C), size: 16),
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
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF1A1D2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: duelQuests.length >= 4
                            ? const Color(0xFFE74C3C)
                            : Colors.white12,
                      ),
                    ),
                    elevation: duelQuests.length >= 4 ? 8 : 0,
                    shadowColor: const Color(0xFFE74C3C).withOpacity(0.4),
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
      style: const TextStyle(
        color: Colors.white54,
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
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF64C8FF), size: 20),
        filled: true,
        fillColor: const Color(0xFF111523),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: const Color(0xFF64C8FF).withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF64C8FF), width: 1.5),
        ),
      ),
    );
  }
}