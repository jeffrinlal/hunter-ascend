import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';

/// Standalone daily-quests screen used by the Quests tab in the bottom nav.
///
/// Reuses DashboardScreen's existing daily-quest section via
/// [DashboardScreen.questsOnly] (single source of truth — no quest/Firebase
/// logic duplicated). The hunter's goals are read from Firestore and passed to
/// DashboardScreen's required parameters.
class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() => _data = doc.data());
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B2B)),
        ),
      );
    }
    return DashboardScreen(
      questsOnly: true,
      fatLoss: _data!['fatLoss'] ?? false,
      discipline: _data!['discipline'] ?? false,
      muscleGain: _data!['muscleGain'] ?? false,
      selfImprovement: _data!['selfImprovement'] ?? false,
    );
  }
}
