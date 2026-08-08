import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/widgets/battle_mode_card.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_lobby_screen.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Battle Hub — the entry point for all battle modes, hosted behind the
/// Duels bottom-nav tab.
///
/// Phase 2 is UI + navigation only:
///
/// * FITNESS DUELS (PvP) → pushes the existing [CreateDuelScreen] untouched.
/// * DUNGEONS (PvE)      → pushes [DungeonLobbyScreen] (gate selection).
/// * Weekly Raids / Guild Battles / World Boss → disabled teaser cards.
///
/// The mode list is intentionally declarative (see [_themedBuild]) so future
/// phases only add/flip cards — no restructuring needed. No backend logic,
/// Firestore changes or new services belong here.
class BattleHubScreen extends StatelessWidget {
  const BattleHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const SizedBox(height: 6),
            _buildHero(),
            const SizedBox(height: 26),

            // ── Active modes ─────────────────────────────────────────────
            BattleModeCard(
              emoji: '⚔️',
              title: 'FITNESS DUELS',
              description:
                  'Challenge real hunters in competitive fitness battles.',
              tag: 'PvP',
              onEnter: () => _openFitnessDuels(context),
            ),
            const SizedBox(height: 14),
            BattleModeCard(
              emoji: '🕳',
              title: 'DUNGEONS',
              description:
                  'Complete PvE fitness adventures and conquer dangerous gates.',
              tag: 'PvE',
              onEnter: () => _openDungeons(context),
            ),

            // ── Upcoming modes (Phase 1: presentation only) ─────────────
            const SizedBox(height: 32),
            _buildSectionHeader('COMING SOON'),
            const SizedBox(height: 12),
            const BattleHubTeaserCard(emoji: '👹', title: 'Weekly Raids'),
            const SizedBox(height: 10),
            const BattleHubTeaserCard(emoji: '🛡', title: 'Guild Battles'),
            const SizedBox(height: 10),
            const BattleHubTeaserCard(emoji: '🌍', title: 'World Boss'),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// ENTER on the Fitness Duels card → the existing duel feature, reused
  /// as-is in its standalone (pushed) presentation.
  void _openFitnessDuels(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateDuelScreen(pushed: true)),
    );
  }

  /// ENTER on the Dungeons card → the Dungeon Lobby (Gate Selection
  /// Center). Dungeon gameplay itself lands in Phase 3.
  void _openDungeons(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DungeonLobbyScreen()),
    );
  }

  // ── Presentation helpers ───────────────────────────────────────────────

  Widget _buildHero() {
    final tokens = MembershipTheme.current;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tokens.gradient,
              ).createShader(bounds),
              child: const Text(
                'BATTLE HUB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your battle.',
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: MembershipTheme.current.gradient,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 12,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
