import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Premium theme gallery (reached from Settings).
///
/// Every theme renders a live preview using its own palette, so each reads as
/// a distinct visual experience rather than an accent swap. Applying a theme
/// that is not already active requires watching one rewarded ad (reusing the
/// app's existing [RewardedAdManager]); the active theme — and the default
/// Dark theme — apply for free. Successful ad completion applies + persists
/// the theme immediately via [ThemeService].
class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  /// Reuses the app's existing rewarded-ad manager (no new ad system).
  late final RewardedAdManager _adManager;

  /// Bumped whenever the ad status changes, so open dialogs can react to
  /// load/ready/unavailable transitions without touching the manager.
  final ValueNotifier<int> _adTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _adManager = RewardedAdManager(
      onAdStatusChanged: () {
        if (!mounted) return;
        setState(() {});
        _adTick.value++;
      },
    );
    _adManager.loadAd();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _adTick.dispose();
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
    return MembershipScaffold(
      body: Stack(
        children: [
          // Subtle premium backdrop wash tinted by the membership accent.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MembershipTheme.current.accent.withOpacity(0.10),
                    HunterTheme.background,
                  ],
                  stops: const [0.0, 0.42],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                Expanded(
                  child: ValueListenableBuilder<AppTheme>(
                    valueListenable: ThemeService.instance.activeThemeNotifier,
                    builder: (context, activeTheme, _) {
                      final themes = ThemeRegistry.allThemes;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 640 ? 3 : 2;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: themes.length,
                            itemBuilder: (context, i) {
                              final t = themes[i];
                              return _ThemePreviewCard(
                                themeData: t,
                                isActive: t.theme == activeTheme,
                                onTap: () => _onThemeTap(t),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.cardColor,
                border: Border.all(color: HunterTheme.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: HunterTheme.textSecondary, size: 15),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: MembershipTheme.current.gradient,
              ),
              boxShadow: [
                BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.35 * HunterTheme.glowStrength), blurRadius: 14),
              ],
            ),
            child: Icon(Icons.palette_rounded,
                color: MembershipTheme.isMax ? Colors.white : Colors.black,
                size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'THEMES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Give your app a whole new identity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: HunterTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tap handling ───────────────────────────────────────────────────────

  Future<void> _onThemeTap(AppThemeData t) async {
    // Skin vs Premium Theme mutual exclusivity: if a Skin is currently the
    // active appearance, selecting ANY Premium Theme — even one that is
    // already stored as the underlying active theme — means the user wants
    // to switch away from the Skin, and that must be confirmed first. This
    // re-validates the skin's expiry as a side effect, so an already-expired
    // skin never triggers the dialog (nothing to switch away from).
    final skinActive = await SkinService.instance.isSkinAppearanceActiveNow();
    if (!mounted) return;
    if (skinActive) {
      _showSkinThemeConflictDialog(t);
      return;
    }

    _continueThemeTap(t);
  }

  void _continueThemeTap(AppThemeData t) {
    // Point 6: the currently active theme never re-prompts.
    if (ThemeService.instance.isActive(t.theme)) return;

    // The default Dark theme is always free to (re)apply.
    if (t.theme == AppTheme.dark) {
      _applyTheme(t);
      return;
    }

    _showApplyDialog(t);
  }

  // ── Skin vs Premium Theme conflict dialog ────────────────────────────────

  void _showSkinThemeConflictDialog(AppThemeData t) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: HunterTheme.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: MembershipTheme.current.accent, size: 32),
              const SizedBox(height: 14),
              Text(
                'Choose Your Appearance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Skin and Premium Theme cannot be used together.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HunterTheme.textPrimary,
                    side: BorderSide(color: HunterTheme.border, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Continue with Skin',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    // Deactivate the Skin visually only — its selection and
                    // remaining unlock time are left completely untouched.
                    await SkinService.instance.suppressForTheme();
                    if (!mounted) return;
                    // Proceed exactly as a normal (no-skin) theme tap would:
                    // free themes apply instantly, ad-gated themes still
                    // require watching the ad as usual.
                    _continueThemeTap(t);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MembershipTheme.current.accent,
                    foregroundColor: MembershipTheme.isMax ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Use Premium Theme',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyTheme(AppThemeData t) async {
    await ThemeService.instance.applyTheme(t.theme);
    if (!mounted) return;
    setState(() {});
    _showSnack('${t.name} theme applied');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Premium ad-unlock dialog ─────────────────────────────────────────────

  void _showApplyDialog(AppThemeData t) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: HunterTheme.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live theme preview.
              _ThemePreview(themeData: t, height: 150),
              const SizedBox(height: 18),
              Text(
                t.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Ad hint pill.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: MembershipTheme.current.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline_rounded, color: MembershipTheme.current.accent, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Watch one quick ad to apply this theme',
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Reactive Watch-Ad button (rebuilds as ad state changes).
              ValueListenableBuilder<int>(
                valueListenable: _adTick,
                builder: (context, _, __) {
                  final ready = _adManager.isReady;
                  final unavailable = _adManager.isUnavailable;
                  final String label = ready
                      ? 'Watch Ad & Apply'
                      : unavailable
                          ? 'Ad Unavailable — Retry'
                          : 'Preparing Ad…';
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (ready) {
                          Navigator.pop(ctx);
                          _watchAdAndApply(t);
                        } else if (unavailable) {
                          _adManager.retry();
                        }
                        // While loading: no-op (button acts as a status label).
                      },
                      icon: Icon(
                        ready
                            ? Icons.play_arrow_rounded
                            : unavailable
                                ? Icons.refresh_rounded
                                : Icons.hourglass_top_rounded,
                        size: 20,
                      ),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MembershipTheme.current.accent,
                        foregroundColor: MembershipTheme.isMax ? Colors.white : Colors.black,
                        disabledBackgroundColor: HunterTheme.border,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Maybe Later',
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _watchAdAndApply(AppThemeData t) {
    _adManager.showAd(
      onRewardEarned: () async {
        // Ad completed successfully → apply + persist immediately.
        await ThemeService.instance.applyTheme(t.theme);
        if (!mounted) return;
        setState(() {});
        _showSnack('${t.name} theme applied');
      },
      // Dismissed without earning the reward → keep the current theme.
      onAdDismissed: () {},
      onAdFailed: () {
        if (!mounted) return;
        _showSnack('Ad could not be shown. Please try again.');
      },
    );
  }
}

// ── Theme preview card (grid item) ─────────────────────────────────────────

class _ThemePreviewCard extends StatelessWidget {
  final AppThemeData themeData;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.themeData,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? MembershipTheme.current.accent.withOpacity(0.75) : HunterTheme.border,
            width: isActive ? 1.8 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: MembershipTheme.current.accent.withOpacity(0.20 * HunterTheme.glowStrength),
                blurRadius: 16,
                spreadRadius: 0.5,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ThemePreview(themeData: themeData)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    themeData.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (isActive)
                  Icon(Icons.check_circle_rounded, color: MembershipTheme.current.accent, size: 18)
                else if (themeData.theme == AppTheme.dark)
                  Icon(Icons.brightness_2_rounded, color: HunterTheme.textTertiary, size: 15)
                else
                  Icon(Icons.play_circle_outline_rounded, color: HunterTheme.textTertiary, size: 17),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live theme preview (renders using the theme's OWN palette) ──────────────

/// A miniature "app" rendered entirely in [themeData]'s palette so the user
/// previews the real feel of the theme (background, card, accent gradient,
/// avatar frame, progress bar, chip) — not just a color dot.
class _ThemePreview extends StatelessWidget {
  final AppThemeData themeData;
  final double? height;

  const _ThemePreview({required this.themeData, this.height});

  @override
  Widget build(BuildContext context) {
    final t = themeData;
    final grad = t.effectiveHeroGradient;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: t.background,
          border: Border.all(color: t.border, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            // Accent wash in the corner (theme gradient).
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [t.primary.withOpacity(0.35), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + name rows.
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: grad),
                        ),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: t.card),
                          child: Icon(Icons.person, color: t.primary, size: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _bar(t.textPrimary, 46, 6),
                          const SizedBox(height: 4),
                          _bar(t.textSecondary, 30, 5),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Progress bar in the theme gradient.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 6, color: t.border),
                        FractionallySizedBox(
                          widthFactor: 0.66,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: grad),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Mini card / chip row.
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: t.border),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 20,
                        width: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
