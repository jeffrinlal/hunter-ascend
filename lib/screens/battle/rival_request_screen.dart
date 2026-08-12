import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/battle/rivalry_comparison_screen.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/rivalry_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Shows a Rivalry request so the hunter can accept or decline it, or — when
/// they are the sender — review and withdraw the one they sent.
///
/// Layout and interaction deliberately follow `DuelRequestScreen`, including
/// the `_isResponding` re-entry guard and the connectivity pre-flight check,
/// so incoming Rivalry requests feel identical to incoming duel challenges.
///
/// Costs no Firestore listener: the request document is handed in by the
/// Battle Hub, which already has it from the shared badge stream.
class RivalRequestScreen extends StatefulWidget {
  const RivalRequestScreen({super.key, required this.rivalry});

  final RivalryData rivalry;

  @override
  State<RivalRequestScreen> createState() => _RivalRequestScreenState();
}

class _RivalRequestScreenState extends State<RivalRequestScreen> {
  bool _isResponding = false;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// True when this user received the request (and may accept or decline it).
  bool get _isReceiver => widget.rivalry.toUid == _myUid;

  Color get _border => HunterTheme.border;

  Future<void> _accept() async {
    if (_isResponding) return;
    if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      _snack('Internet connection required.');
      return;
    }
    setState(() => _isResponding = true);

    final result = await RivalryService.instance.accept(widget.rivalry);

    if (!mounted) return;
    setState(() => _isResponding = false);

    final accepted = result.rivalry;
    if (!result.ok || accepted == null) {
      _snack(result.message ?? 'Could not accept the rivalry.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RivalryComparisonScreen(rivalryId: accepted.id),
      ),
    );
  }

  Future<void> _decline() async {
    if (_isResponding) return;
    if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      _snack('Internet connection required.');
      return;
    }
    setState(() => _isResponding = true);

    final result = await RivalryService.instance.decline(widget.rivalry);

    if (!mounted) return;
    setState(() => _isResponding = false);

    if (!result.ok) {
      _snack(result.message ?? 'Could not decline the rivalry.');
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _cancel() async {
    if (_isResponding) return;
    if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      _snack('Internet connection required.');
      return;
    }
    setState(() => _isResponding = true);

    final result = await RivalryService.instance.cancelRequest(widget.rivalry);

    if (!mounted) return;
    setState(() => _isResponding = false);

    if (!result.ok) {
      _snack(result.message ?? 'Could not cancel the request.');
      return;
    }
    Navigator.pop(context);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    final accent = MembershipTheme.current.accent;
    final rivalry = widget.rivalry;
    final otherUid = rivalry.otherUidFor(_myUid);
    final otherName = rivalry.hunterNameFor(otherUid);
    final days = rivalry.durationDays;

    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.cardColor,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: HunterTheme.textSecondary, size: 15),
            ),
          ),
        ),
        leadingWidth: 60,
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: _isReceiver ? 'RIVALRY ' : 'REQUEST ',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            TextSpan(
              text: _isReceiver ? 'REQUEST' : 'SENT',
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  _buildHero(otherName: otherName, days: days),
                  const SizedBox(height: 24),
                  _buildRulesCard(days: days),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHero({required String otherName, required int days}) {
    final accent = MembershipTheme.current.accent;
    final heroColor = _isReceiver ? HunterTheme.danger : accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            heroColor.withValues(alpha: 0.16),
            HunterTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: heroColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: heroColor.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  heroColor.withValues(alpha: 0.22),
                  heroColor.withValues(alpha: 0.08),
                ],
              ),
              shape: BoxShape.circle,
              border:
                  Border.all(color: heroColor.withValues(alpha: 0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: heroColor.withValues(alpha: 0.25), blurRadius: 18),
              ],
            ),
            child: Icon(Icons.local_fire_department_rounded,
                color: heroColor, size: 44),
          ),
          const SizedBox(height: 16),
          Text(
            '🔥  RIVALRY',
            style: TextStyle(
              color: heroColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isReceiver
                ? '$otherName wants to become your Rival.\n'
                    'Accept to begin the $days-day Rivalry.'
                : 'Waiting for $otherName to accept.\n'
                    'The $days-day timer starts the moment they do.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: HunterTheme.border,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                '$days DAY RIVALRY',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard({required int days}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: MembershipTheme.current.gradient,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'HOW IT WORKS',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _rule(Icons.trending_up_rounded,
              'Whoever gains the most XP over $days days wins.'),
          _rule(Icons.emoji_events_rounded,
              'The winner earns +${RivalryService.winnerXpReward} XP.'),
          _rule(Icons.shield_outlined,
              'No XP is ever deducted for losing.'),
          _rule(Icons.handshake_outlined,
              'Equal progress is a draw — nobody wins.'),
        ],
      ),
    );
  }

  Widget _rule(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MembershipTheme.current.accent, size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      decoration: BoxDecoration(
        color: HunterTheme.background,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: _isReceiver
          ? Row(children: [
              Expanded(
                child: _outlineButton(
                  label: 'DECLINE',
                  icon: Icons.close_rounded,
                  color: HunterTheme.danger,
                  onTap: _decline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryButton(
                  label: 'ACCEPT',
                  icon: Icons.check_rounded,
                  onTap: _accept,
                ),
              ),
            ])
          : _outlineButton(
              label: 'CANCEL REQUEST',
              icon: Icons.close_rounded,
              color: HunterTheme.danger,
              onTap: _cancel,
            ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return GestureDetector(
      onTap: _isResponding ? null : onTap,
      child: Opacity(
        opacity: _isResponding ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    final tokens = MembershipTheme.current;
    final fg = MembershipTheme.isMax ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: _isResponding ? null : onTap,
      child: Opacity(
        opacity: _isResponding ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tokens.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tokens.accent
                    .withValues(alpha: 0.4 * HunterTheme.glowStrength),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 19),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
