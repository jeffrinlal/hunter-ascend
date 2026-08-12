import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/rank_celebration_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';
import 'package:hunter_ascend/services/rivalry_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// The Rivalry outcome screen: VICTORY, DRAW or DEFEATED.
///
/// ## Finalization
/// Opening this screen is what finalizes an expired rivalry. The transaction
/// lives in [RivalryService.finalizeIfExpired] and asserts the rivalry is still
/// active, so whichever participant opens the app first computes the verdict
/// once and both users then read the same stored result. Nothing is ever
/// recomputed.
///
/// ## Winner
/// +[RivalryService.winnerXpReward] XP through the existing `XpService`,
/// gated by a write-once flag on the shared rivalry document so two devices
/// opening the result simultaneously cannot both grant it.
///
/// ## Loser — HARD GATE
/// No XP is deducted. The result is only completed by a genuine rewarded-ad
/// callback. There is no continue button and no bypass:
/// * the 5-second countdown gates the BUTTON, never the reward;
/// * closing the ad early completes nothing;
/// * a failed load or a failed show completes nothing;
/// * leaving the screen completes nothing — the result stays pending and the
///   Battle Hub keeps offering it until an ad is actually watched.
class RivalryResultScreen extends StatefulWidget {
  const RivalryResultScreen({super.key, required this.rivalryId});

  final String rivalryId;

  @override
  State<RivalryResultScreen> createState() => _RivalryResultScreenState();
}

class _RivalryResultScreenState extends State<RivalryResultScreen> {
  /// Seconds the WATCH AD button stays disabled. Purely a UI delay — it is not
  /// part of the completion claim, so a rebuild or an app restart simply
  /// re-runs it with no effect on the result state.
  static const int _countdownSeconds = 5;

  RivalryData? _rivalry;
  RivalryOutcome? _outcome;

  bool _loading = true;
  String? _error;

  /// True when THIS session performed the winner's +50 XP grant.
  bool _xpGrantedNow = false;

  int _countdown = _countdownSeconds;
  Timer? _countdownTimer;

  late final RewardedAdManager _ad = RewardedAdManager(
    onAdStatusChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Set only by the rewarded-ad SDK's reward callback. The single condition
  /// under which a loss may be completed.
  bool _rewardEarned = false;

  bool _showingAd = false;
  bool _settling = false;
  bool _settled = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Post-frame so finalization and the XP celebration dialogs have a mounted
    // context to work with — the same trigger shape the duel system uses.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ad.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final uid = _myUid;
    if (uid.isEmpty) {
      _fail('You must be signed in.');
      return;
    }

    final initial =
        await RivalryService.instance.fetchById(widget.rivalryId);
    if (initial == null || !initial.isParticipant(uid)) {
      _fail('This Rivalry no longer exists.');
      return;
    }

    // Finalize if the duration has elapsed but nobody has computed the verdict
    // yet. Returns the already-completed document when another device won the
    // race, so the result is read, never recomputed.
    RivalryData resolved = initial;
    if (initial.status == RivalryStatus.active && initial.hasExpired) {
      final finalized =
          await RivalryService.instance.finalizeIfExpired(initial);
      if (finalized != null) resolved = finalized;
    }

    if (!mounted) return;

    if (resolved.status == RivalryStatus.abandoned) {
      setState(() {
        _rivalry = resolved;
        _outcome = null;
        _loading = false;
      });
      return;
    }

    if (resolved.status != RivalryStatus.completed) {
      _fail('This Rivalry has not finished yet.');
      return;
    }

    final outcome = resolved.outcomeFor(uid);
    setState(() {
      _rivalry = resolved;
      _outcome = outcome;
      _loading = false;
    });

    if (outcome == RivalryOutcome.win) {
      await _claimXp(resolved, uid);
    } else if (outcome == RivalryOutcome.loss) {
      _ad.loadAd();
      _startCountdown();
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  /// Winner's exactly-once +50 XP. The gate is a transaction on the SHARED
  /// rivalry document, so it holds across rebuilds, app restarts and devices.
  Future<void> _claimXp(RivalryData rivalry, String uid) async {
    final result = await RivalryService.instance.claimWinnerXp(rivalry);
    if (!mounted) return;

    if (result.granted) setState(() => _xpGrantedNow = true);

    final award = result.award;
    if (award != null && award.leveledUp) {
      // Reuses the existing celebration helpers; +50 XP can cross at most one
      // level boundary, so the previous level is exactly level - 1.
      MilestoneService.celebrateLevelUps(context, award.level - 1, award.level);
      RankCelebrationService.instance.celebrateIfRankUp(
        context,
        uid: uid,
        oldLevel: award.level - 1,
        newLevel: award.level,
      );
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = _countdownSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) _countdown--;
      });
      if (_countdown <= 0) timer.cancel();
    });
  }

  // ── Loser: hard-gated rewarded ad ─────────────────────────────────────

  void _watchAd() {
    if (_countdown > 0 || _showingAd || _settling || _settled) return;

    if (!_ad.isReady) {
      // Not a bypass: retry the LOAD. The result stays incomplete until a real
      // reward callback arrives.
      _snack(_ad.isLoading
          ? 'Loading ad. Please wait a moment.'
          : 'Ad unavailable. Retrying — please try again shortly.');
      _ad.retry();
      return;
    }

    setState(() => _showingAd = true);

    _ad.showAd(
      // The ONLY path that completes a loss. Wired by RewardedAdManager to the
      // SDK's real onUserEarnedReward event, so it cannot be confused with a
      // dismissal. The Firestore write is issued here rather than on dismissal
      // so a genuinely earned reward is persisted immediately.
      onRewardEarned: () {
        _rewardEarned = true;
        _settle();
      },
      onAdDismissed: () {
        if (!mounted) return;
        setState(() => _showingAd = false);
        if (!_rewardEarned) {
          _snack('Ad closed early — the result is not complete yet.');
          return;
        }
        if (_settled) {
          Navigator.pop(context);
        } else if (!_settling) {
          // Reward genuinely earned but the write has not landed; retry it
          // without asking for another ad.
          _settle();
        }
      },
      onAdFailed: () {
        if (!mounted) return;
        setState(() => _showingAd = false);
        _snack('Ad could not be shown. Please try again.');
      },
    );
  }

  /// Removes only this user from the rivalry's `unsettledFor` list.
  ///
  /// Idempotent by construction: `arrayRemove` can be replayed safely, and once
  /// it lands the rivalry stops matching this user's query, so this screen
  /// becomes unreachable and no second reward opportunity can exist.
  Future<void> _settle({bool popOnSuccess = true}) async {
    if (!mounted) return;
    final rivalry = _rivalry;
    if (rivalry == null || _settling || _settled) return;

    // Defence in depth: a loss can only ever be settled after a real reward.
    if (_outcome == RivalryOutcome.loss && !_rewardEarned) return;

    setState(() => _settling = true);
    final ok = await RivalryService.instance.settleMySide(rivalry);
    if (!mounted) return;
    setState(() {
      _settling = false;
      _settled = ok;
    });

    if (!ok) {
      _snack('Could not save the result. Please try again.');
      return;
    }
    // Never pop out from under a full-screen ad; `onAdDismissed` pops once the
    // ad closes and sees `_settled == true`.
    if (popOnSuccess && !_showingAd) Navigator.pop(context);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'RIVALRY RESULT',
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: MembershipTheme.current.accent),
      );
    }
    if (_error != null) {
      return _centered(
        icon: Icons.error_outline_rounded,
        color: HunterTheme.danger,
        title: 'RESULT UNAVAILABLE',
        message: _error!,
      );
    }

    final rivalry = _rivalry!;
    if (rivalry.status == RivalryStatus.abandoned) {
      return _centered(
        icon: Icons.person_off_outlined,
        color: HunterTheme.danger,
        title: 'YOUR RIVAL LEFT',
        message: 'This Rivalry ended without a result because your Rival is no '
            'longer available. No XP was awarded.',
        footer: _plainButton(
          label: 'CLOSE',
          color: HunterTheme.textSecondary,
          onTap: _settling ? null : () => _settle(),
        ),
      );
    }

    final myUid = _myUid;
    final otherUid = rivalry.otherUidFor(myUid);
    final myProgress = rivalry.finalProgressFor(myUid) ?? 0;
    final rivalProgress = rivalry.finalProgressFor(otherUid) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        children: [
          _buildOutcomeHero(),
          const SizedBox(height: 24),
          _buildScoreCard(
            rivalName: rivalry.hunterNameFor(otherUid),
            myProgress: myProgress,
            rivalProgress: rivalProgress,
            days: rivalry.durationDays,
          ),
          const SizedBox(height: 24),
          _buildAction(),
        ],
      ),
    );
  }

  Widget _buildOutcomeHero() {
    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    final outcome = _outcome;
    if (outcome == RivalryOutcome.win) {
      color = HunterTheme.gold;
      icon = Icons.emoji_events_rounded;
      title = 'VICTORY';
      subtitle = 'You out-trained your Rival.';
    } else if (outcome == RivalryOutcome.draw) {
      color = MembershipTheme.current.accent;
      icon = Icons.handshake_rounded;
      title = 'DRAW';
      subtitle = 'Equal progress — nobody takes this one.';
    } else if (outcome == RivalryOutcome.loss) {
      color = HunterTheme.danger;
      icon = Icons.shield_outlined;
      title = 'DEFEATED';
      subtitle = 'Your Rival progressed further this time.';
    } else {
      color = HunterTheme.textSecondary;
      icon = Icons.help_outline_rounded;
      title = 'NO RESULT';
      subtitle = 'This Rivalry produced no outcome.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.18),
            HunterTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18 * HunterTheme.glowStrength),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border:
                  Border.all(color: color.withValues(alpha: 0.5), width: 1.6),
            ),
            child: Icon(icon, color: color, size: 46),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 26,
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
              height: 1.45,
            ),
          ),
          if (_outcome == RivalryOutcome.win) ...[
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: HunterTheme.success.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: HunterTheme.success.withValues(alpha: 0.4)),
              ),
              child: Text(
                _xpGrantedNow
                    ? '+${RivalryService.winnerXpReward} XP AWARDED'
                    : '+${RivalryService.winnerXpReward} XP ALREADY CLAIMED',
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

  Widget _buildScoreCard({
    required String rivalName,
    required int myProgress,
    required int rivalProgress,
    required int days,
  }) {
    final accent = MembershipTheme.current.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HunterTheme.border, width: 1.2),
      ),
      child: Column(
        children: [
          Text(
            'XP GAINED OVER $days DAYS',
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _scoreColumn(
                  label: 'YOU',
                  value: myProgress,
                  color: accent,
                  winning: myProgress > rivalProgress,
                ),
              ),
              Container(
                width: 1,
                height: 52,
                color: HunterTheme.border,
              ),
              Expanded(
                child: _scoreColumn(
                  label: rivalName.toUpperCase(),
                  value: rivalProgress,
                  color: HunterTheme.danger,
                  winning: rivalProgress > myProgress,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreColumn({
    required String label,
    required int value,
    required Color color,
    required bool winning,
  }) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '+$value',
          style: TextStyle(
            color: winning ? color : HunterTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'XP',
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── Action area ───────────────────────────────────────────────────────

  Widget _buildAction() {
    // Winner and draw: nothing is gated, a single acknowledgement closes it.
    if (_outcome != RivalryOutcome.loss) {
      return _plainButton(
        label: _settling ? 'SAVING...' : 'CONTINUE',
        color: MembershipTheme.current.accent,
        filled: true,
        foreground: MembershipTheme.isMax ? Colors.white : Colors.black,
        onTap: _settling ? null : () => _settle(),
      );
    }

    // The reward WAS genuinely earned but the Firestore write did not land
    // (e.g. connection dropped as the ad closed). Offer a retry of the WRITE
    // only. This is not a bypass: `_rewardEarned` is set exclusively by the ad
    // SDK's reward callback and can never be reached without a completed ad.
    if (_rewardEarned && !_settled) {
      return _plainButton(
        label: _settling ? 'SAVING...' : 'SAVE RESULT',
        color: HunterTheme.success,
        filled: true,
        foreground: Colors.black,
        onTap: _settling ? null : () => _settle(),
      );
    }

    // Loser: HARD GATE. The only route out of this state is a real rewarded-ad
    // callback. No continue, no skip, no bypass.
    final enabled = _countdown <= 0 && !_showingAd && !_settling;
    final label = _showingAd
        ? 'SHOWING AD...'
        : _settling
            ? 'SAVING...'
            : _countdown > 0
                ? 'WATCH AD ($_countdown)'
                : _ad.isReady
                    ? 'WATCH AD'
                    : _ad.isLoading
                        ? 'LOADING AD...'
                        : 'RETRY AD';

    return Column(
      children: [
        _plainButton(
          label: label,
          color: HunterTheme.danger,
          filled: true,
          foreground: Colors.white,
          onTap: enabled ? _watchAd : null,
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded,
                color: HunterTheme.textTertiary, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Watch the full ad to complete this result. Closing it early '
                'leaves the Rivalry result pending.',
                style: TextStyle(
                  color: HunterTheme.textTertiary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _plainButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool filled = false,
    Color? foreground,
  }) {
    final disabled = onTap == null;
    final fg = filled ? (foreground ?? Colors.black) : color;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: filled ? fg : color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _centered({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    Widget? footer,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 24),
              footer,
            ],
          ],
        ),
      ),
    );
  }
}
