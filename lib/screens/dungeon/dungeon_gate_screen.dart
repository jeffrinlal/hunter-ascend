import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_coming_soon_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_play_screen.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_session_manager.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Gate Entry screen — the immersive moment between choosing a gate in the
/// Dungeon Lobby and stepping into the dungeon.
///
/// Presentation only: animated gate, name, rank, difficulty, lore, ENTER
/// DUNGEON and BACK. ENTER DUNGEON routes to the Phase 4 play screen for
/// the E-Rank gate and to the placeholder for higher gates. Everything a
/// later phase needs to inject (objectives, AI-generated dungeon, rewards,
/// daily reset, progress) arrives through the [spec] descriptor — the
/// screen itself won't need redesigning.
class DungeonGateScreen extends StatefulWidget {
  const DungeonGateScreen({super.key, required this.spec});

  final DungeonGateSpec spec;

  @override
  State<DungeonGateScreen> createState() => _DungeonGateScreenState();
}

class _DungeonGateScreenState extends State<DungeonGateScreen>
    with TickerProviderStateMixin {
  /// Guards ENTER DUNGEON against double-taps while the AI request is in
  /// flight — one press = at most one generation attempt.
  bool _entering = false;

  // ── Animations (existing app idioms: fade-in entry, reverse-repeat pulse,
  //    fixed-seed CustomPainter particles) ─────────────────────────────────
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _entranceController,
    curve: Curves.easeOut,
  );

  /// Breathing loop — drives the gate's scale AND its glow strength so the
  /// portal feels alive.
  late final AnimationController _breathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  /// Slow linear loop for the rising ember particles.
  late final AnimationController _emberController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathController.dispose();
    _emberController.dispose();
    super.dispose();
  }

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
    final rank = dungeonGateRank(widget.spec);

    return MembershipScaffold(
      appBar: const MembershipAppBar(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(_entrance),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(child: _buildGateVisual(rank)),
                  const SizedBox(height: 24),
                  _buildGateTitle(rank),
                  const SizedBox(height: 12),
                  _buildInfoChips(rank),
                  const SizedBox(height: 18),
                  Text(
                    widget.spec.lore,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HunterTheme.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  MembershipButton.primary(
                    'ENTER DUNGEON',
                    onTap: () => _enterDungeon(context),
                    expanded: true,
                    icon: Icons.door_front_door_rounded,
                  ),
                  const SizedBox(height: 10),
                  MembershipButton.secondary(
                    'BACK',
                    onTap: () => Navigator.of(context).pop(),
                    expanded: true,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// ENTER DUNGEON → Phase 4 gameplay exists for the E-Rank gate only;
  /// higher-rank gates keep the Phase 3 placeholder until their phases
  /// ship. pushReplacement keeps the stack flat (lobby → play), so BACK /
  /// RETURN on the play screen lands on the Dungeon Lobby.
  ///
  /// Session creation is delegated to [DungeonSessionManager]: the AI
  /// dungeon is generated ONLY on this press and only when today's
  /// dungeon does not exist yet (one generation per dungeon per day),
  /// snapshots are captured ONCE immediately afterwards and tracking
  /// starts — all outside any widget lifecycle.
  Future<void> _enterDungeon(BuildContext context) async {
    final isERank = widget.spec.letter == 'E';
    if (!isERank) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DungeonComingSoonScreen(spec: widget.spec),
        ),
      );
      return;
    }
    if (_entering) return;
    _entering = true;

    await DungeonSessionManager.instance.enterDungeon(gate: widget.spec);
    if (!mounted) return;
    _entering = false;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DungeonPlayScreen(spec: widget.spec),
      ),
    );
  }

  // ── Presentation helpers ───────────────────────────────────────────────

  /// Large animated gate: ambient bloom, rising embers and a breathing
  /// rank-colored portal with a soft glow.
  Widget _buildGateVisual(HunterRank rank) {
    final Color rankColor = rank.color;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient bloom behind the portal (breathes with the gate).
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final t = _breathController.value;
            return Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    rankColor.withOpacity(0.10 + 0.08 * t),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
        // Rising ember particles.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _emberController,
              builder: (context, _) => CustomPaint(
                painter: _GateEmberPainter(
                  progress: _emberController.value,
                  color: rankColor,
                ),
              ),
            ),
          ),
        ),
        // Breathing portal.
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final t = _breathController.value;
            return Transform.scale(
              scale: 1.0 + 0.04 * t,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      rankColor.withOpacity(0.34),
                      rankColor.withOpacity(0.12),
                      HunterTheme.background.withOpacity(0.9),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: rankColor.withOpacity(0.65),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withOpacity(
                        (0.35 + 0.3 * t) * HunterTheme.glowStrength,
                      ),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.spec.letter,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: rankColor.withOpacity(0.6),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGateTitle(HunterRank rank) {
    return Column(
      children: [
        Text(
          widget.spec.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${rank.label} Gate'.toUpperCase(),
          style: TextStyle(
            color: rank.color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChips(HunterRank rank) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _InfoChip(label: rank.label, color: rank.color),
        const SizedBox(width: 10),
        _InfoChip(
          label: widget.spec.difficulty.toUpperCase(),
          color: HunterTheme.textSecondary,
        ),
      ],
    );
  }
}

/// Small rounded info chip (rank / difficulty) for the gate entry screen.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Lightweight rising-ember painter (same fixed-seed CustomPainter idiom as
/// the app's existing sparkle/confetti painters). Embers drift upward and
/// fade in/out on a loop.
class _GateEmberPainter extends CustomPainter {
  _GateEmberPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static final List<_Ember> _embers = _generateEmbers();

  static List<_Ember> _generateEmbers() {
    final rng = math.Random(7);
    return List.generate(
      16,
      (_) => _Ember(
        x: rng.nextDouble(),
        speed: 0.5 + rng.nextDouble() * 0.8,
        size: 1.5 + rng.nextDouble() * 2.5,
        phase: rng.nextDouble(),
        drift: (rng.nextDouble() - 0.5) * 0.06,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in _embers) {
      // Looping vertical position: rises from bottom to top, then wraps.
      final t = (progress * e.speed + e.phase) % 1.0;
      final y = size.height * (1.0 - t);
      final x = size.width * (e.x + e.drift * t);
      // Fade in near the bottom, fade out near the top.
      final opacity = (math.sin(t * math.pi) * 0.5).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x, y),
        e.size,
        Paint()..color = color.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GateEmberPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _Ember {
  const _Ember({
    required this.x,
    required this.speed,
    required this.size,
    required this.phase,
    required this.drift,
  });

  final double x;
  final double speed;
  final double size;
  final double phase;
  final double drift;
}
