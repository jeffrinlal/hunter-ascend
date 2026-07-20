import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Premium "Rank Up" celebration dialog.
///
/// Presentation only — this widget never computes rank itself. It is handed
/// the already-resolved previous and new [HunterRank] (from [RankService],
/// the single source of truth) and simply displays them with a short,
/// lightweight scale/fade/glow/slide animation sequence.
///
/// Designed to be shown via [RankCelebrationService] through the shared
/// [MilestoneService] queue — not instantiated directly by screens.
class RankUpDialog extends StatefulWidget {
  final HunterRank previousRank;
  final HunterRank newRank;

  /// Optional extra line shown below the standard ascension message — used
  /// when a single XP gain crossed multiple Hunter Ranks at once (e.g.
  /// "You advanced through multiple Hunter Ranks."). `null` for a normal,
  /// single-tier rank up.
  final String? subtitle;

  const RankUpDialog({
    super.key,
    required this.previousRank,
    required this.newRank,
    this.subtitle,
  });

  /// Shows the celebration dialog and completes when it is dismissed.
  static Future<void> show(
    BuildContext context, {
    required HunterRank previousRank,
    required HunterRank newRank,
    String? subtitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) => RankUpDialog(
        previousRank: previousRank,
        newRank: newRank,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<RankUpDialog> createState() => _RankUpDialogState();
}

class _RankUpDialogState extends State<RankUpDialog> with TickerProviderStateMixin {
  // ── Lightweight, short entrance animation (scale + fade + slide) ──
  late final AnimationController _entrance;
  // ── Continuous glow pulse on the new rank's emblem ──
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = widget.newRank.color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: FadeTransition(
        opacity: _entrance,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: rc.withOpacity(0.55), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: rc.withOpacity(0.30 * HunterTheme.glowStrength),
                    blurRadius: 36,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRibbon(rc),
                  const SizedBox(height: 20),
                  _buildTransition(),
                  const SizedBox(height: 22),
                  _buildEmblem(rc),
                  const SizedBox(height: 18),
                  _buildTitles(rc),
                  const SizedBox(height: 24),
                  _buildContinueButton(rc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── "RANK UP" ribbon ──
  Widget _buildRibbon(Color rc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.keyboard_double_arrow_up_rounded, color: rc, size: 16),
        const SizedBox(width: 8),
        Text(
          'RANK UP',
          style: TextStyle(
            color: rc,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.keyboard_double_arrow_up_rounded, color: rc, size: 16),
      ],
    );
  }

  // ── Previous rank -> new rank pill row ──
  Widget _buildTransition() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: _rankPill(widget.previousRank, dim: true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded,
              color: HunterTheme.textTertiary, size: 16),
        ),
        Flexible(child: _rankPill(widget.newRank, dim: false)),
      ],
    );
  }

  Widget _rankPill(HunterRank rank, {required bool dim}) {
    final c = dim ? HunterTheme.textTertiary : rank.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(dim ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.withOpacity(dim ? 0.25 : 0.45)),
      ),
      child: Text(
        rank.letter,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Glowing rank emblem (letter/code medallion) ──
  Widget _buildEmblem(Color rc) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value; // 0..1
        return Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [rc.withOpacity(0.36), rc.withOpacity(0.10)],
            ),
            border: Border.all(color: rc.withOpacity(0.75), width: 2.2),
            boxShadow: [
              BoxShadow(
                color: rc.withOpacity((0.32 + 0.28 * t) * HunterTheme.glowStrength),
                blurRadius: 26 + 12 * t,
                spreadRadius: 1.5 + 1.5 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Center(
        child: Text(
          widget.newRank.letter,
          style: TextStyle(
            color: rc,
            fontSize: widget.newRank.letter.length > 1 ? 30 : 42,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ── New rank title + premium display title ──
  Widget _buildTitles(Color rc) {
    final showDisplayTitle = widget.newRank.displayTitle != widget.newRank.longTitle;
    return Column(
      children: [
        Text(
          widget.newRank.longTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        if (showDisplayTitle) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: rc.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: rc.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: rc, size: 12),
                const SizedBox(width: 6),
                Text(
                  widget.newRank.displayTitle,
                  style: TextStyle(
                    color: rc,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'You have ascended beyond ${widget.previousRank.label}.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContinueButton(Color rc) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text(
          'CONTINUE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: rc,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          elevation: 4,
          shadowColor: rc.withOpacity(0.4),
        ),
      ),
    );
  }
}
