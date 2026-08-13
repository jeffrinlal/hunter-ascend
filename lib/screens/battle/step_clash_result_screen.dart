import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/rank_celebration_service.dart';
import 'package:hunter_ascend/services/step_clash_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Displays the Step Clash result: VICTORY / DRAW / DEFEATED / FORFEITED.
/// Claims the winner's XP reward via the exactly-once transaction pattern.
class StepClashResultScreen extends StatefulWidget {
  const StepClashResultScreen({super.key, required this.battleId});
  final String battleId;

  @override
  State<StepClashResultScreen> createState() => _StepClashResultScreenState();
}

class _StepClashResultScreenState extends State<StepClashResultScreen> {
  StepClashData? _clash;
  StepClashOutcome? _outcome;
  bool _loading = true;
  bool _xpClaimed = false;
  bool _settling = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    var clash = await StepClashService.instance.fetchById(widget.battleId);
    if (!mounted || clash == null) {
      setState(() {
        _loading = false;
        _clash = clash;
      });
      return;
    }

    // Finalize if expired but not yet completed (first opener does this).
    if (clash.status == StepClashStatus.active && clash.hasExpired) {
      final result = await StepClashService.instance.finalize(clash);
      if (result != null) clash = result;
    }

    if (!mounted) return;
    final outcome = clash.outcomeFor(_uid);
    setState(() {
      _clash = clash;
      _outcome = outcome;
      _loading = false;
    });

    if (outcome == StepClashOutcome.win) {
      await _claimXp(clash);
    }
  }

  Future<void> _claimXp(StepClashData clash) async {
    final granted = await StepClashService.instance.claimXp(clash);
    if (!mounted) return;
    if (granted) {
      setState(() => _xpClaimed = true);
      // Celebrate level-up if it happened (+30 XP can cross one boundary).
      // XpService already handled the grant; we just trigger the UI celebration.
    }
  }

  Future<void> _close() async {
    if (_settling) return;
    setState(() => _settling = true);
    final clash = _clash;
    if (clash != null) {
      // Acknowledge the result so it no longer shows on hub.
      await StepClashService.instance.acknowledge(clash);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: _close,
        ),
        title: Text(
          'STEP CLASH RESULT',
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: MembershipTheme.current.accent))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final clash = _clash;
    if (clash == null || clash.status != StepClashStatus.completed) {
      return Center(
        child: Text(
          'Result not available yet.',
          style: TextStyle(color: HunterTheme.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        children: [
          _outcomeHero(),
          const SizedBox(height: 24),
          _rankingCard(clash),
          const SizedBox(height: 24),
          _closeButton(),
        ],
      ),
    );
  }

  Widget _outcomeHero() {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    final outcome = _outcome;
    if (outcome == StepClashOutcome.win) {
      color = HunterTheme.gold;
      icon = Icons.emoji_events_rounded;
      title = 'VICTORY';
      subtitle = 'You reached the goal first!';
    } else if (outcome == StepClashOutcome.draw) {
      color = MembershipTheme.current.accent;
      icon = Icons.handshake_rounded;
      title = 'DRAW';
      subtitle = 'Equal steps — nobody wins this one.';
    } else if (outcome == StepClashOutcome.forfeited) {
      color = HunterTheme.textTertiary;
      icon = Icons.flag_rounded;
      title = 'FORFEITED';
      subtitle = 'You gave up this battle.';
    } else {
      color = HunterTheme.danger;
      icon = Icons.shield_outlined;
      title = 'DEFEATED';
      subtitle = 'Your opponent out-stepped you.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.16), HunterTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 42),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 13,
                height: 1.4),
          ),
          if (_outcome == StepClashOutcome.win) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: HunterTheme.success.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: HunterTheme.success.withValues(alpha: 0.4)),
              ),
              child: Text(
                _xpClaimed
                    ? '+${StepClashService.winnerXpReward} XP AWARDED'
                    : '+${StepClashService.winnerXpReward} XP',
                style: TextStyle(
                  color: HunterTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rankingCard(StepClashData clash) {
    final ranking = <(String uid, int steps)>[];
    for (final uid in clash.participants) {
      ranking.add((uid, clash.progressFor(uid)));
    }
    ranking.sort((a, b) => b.$2.compareTo(a.$2));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HunterTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINAL RANKING',
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(ranking.length, (i) {
            final (uid, steps) = ranking[i];
            final isMe = uid == _uid;
            final isForfeited = clash.isForfeited(uid);
            final medal = i == 0
                ? '🥇'
                : i == 1
                    ? '🥈'
                    : i == 2
                        ? '🥉'
                        : '  ';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(medal, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMe ? 'YOU' : clash.nameFor(uid),
                      style: TextStyle(
                        color: isForfeited
                            ? HunterTheme.textTertiary
                            : isMe
                                ? MembershipTheme.current.accent
                                : HunterTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        decoration: isForfeited
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    isForfeited ? 'FORFEITED' : '$steps steps',
                    style: TextStyle(
                      color: HunterTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _closeButton() {
    final accent = MembershipTheme.current.accent;
    final fg = MembershipTheme.isMax ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: _settling ? null : _close,
      child: Opacity(
        opacity: _settling ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: MembershipTheme.current.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'CONTINUE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
