import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Theme/hunter_theme.dart';
import 'dashboard_screen.dart';
import 'quest_screen.dart';
import 'global_rankings_screen.dart';
import 'profile_screen.dart';
import 'duel_screen.dart';
import 'duel_request_screen.dart';
import 'create_duel_screen.dart';

/// Persistent shell hosting the main app screens behind a bottom NavigationBar.
/// Tabs: Home (Dashboard), Quests, Leaderboard, Duels, Profile.
/// Login + onboarding (Awakening/Assessment) are NOT wrapped by this shell.
class MainShell extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;

  const MainShell({
    super.key,
    this.fatLoss = false,
    this.discipline = false,
    this.muscleGain = false,
    this.selfImprovement = false,
    this.bioQuests = const [],
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final List<Widget> _tabs = [
    DashboardScreen(
      fatLoss: widget.fatLoss,
      discipline: widget.discipline,
      muscleGain: widget.muscleGain,
      selfImprovement: widget.selfImprovement,
      bioQuests: widget.bioQuests,
    ),
    const QuestScreen(),
    const GlobalRankingsScreen(),
    const SizedBox.shrink(), // Duels = push action (see _openDuels)
    const ProfileScreen(),
  ];

  // Preserves the original Dashboard duel-routing behavior verbatim:
  // active duel -> DuelScreen, pending request -> DuelRequestScreen,
  // otherwise -> CreateDuelScreen. Pushed as a route (keeps its own AppBar).
  Future<void> _openDuels() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final duelSnapshot = await FirebaseFirestore.instance
        .collection('duels')
        .where('participants', arrayContains: user.uid)
        .limit(1)
        .get();
    bool hasActiveDuel = false;
    String? duelId;
    if (duelSnapshot.docs.isNotEmpty) {
      final doc = duelSnapshot.docs.first;
      final data = doc.data();
      bool isPlayer1 = data['player1'] == user.uid;
      bool shouldShowResult = data['status'] == 'completed' &&
          ((isPlayer1 && data['player1ViewedResult'] == false) ||
              (!isPlayer1 && data['player2ViewedResult'] == false));
      if (data['status'] == 'active' || shouldShowResult) {
        hasActiveDuel = true;
        duelId = doc.id;
      }
    }
    if (!mounted) return;
    if (hasActiveDuel) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DuelScreen(duelId: duelId!)));
      return;
    }
    final pendingRequest = await FirebaseFirestore.instance
        .collection('duel_requests')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (!mounted) return;
    if (pendingRequest.docs.isNotEmpty) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DuelRequestScreen()));
      return;
    }
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CreateDuelScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final inactive = HunterTheme.textSecondary;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          border: Border(
            top: BorderSide(
              color: HunterTheme.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: HunterTheme.cardColor,
            indicatorColor: HunterTheme.primary.withOpacity(0.14),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected)
                    ? HunterTheme.primary
                    : inactive,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? HunterTheme.primary
                    : inactive,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            height: 66,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              if (i == 3) {
                _openDuels();
                return;
              }
              setState(() => _index = i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Quests',
              ),
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: 'Leaderboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_kabaddi),
                label: 'Duels',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
