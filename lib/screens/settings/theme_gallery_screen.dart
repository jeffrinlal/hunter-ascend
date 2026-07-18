import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/screens/profile/membership_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Theme Gallery screen: displays all available dark themes grouped by
/// membership tier. Tapping a theme opens a preview bottom sheet; locked
/// themes show an upgrade dialog.
class ThemeGalleryScreen extends StatelessWidget {
  const ThemeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: HunterTheme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: HunterTheme.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: HunterTheme.primary,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'PREMIUM THEMES',
                          style: TextStyle(
                            color: HunterTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: Text(
                      'Customize your hunter experience',
                      style: TextStyle(
                        color: HunterTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Theme list ──
            Expanded(
              child: ValueListenableBuilder<AppTheme>(
                valueListenable: ThemeService.instance.activeThemeNotifier,
                builder: (context, activeTheme, _) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildSection(context, 'FREE', MembershipTier.basic, activeTheme),
                      const SizedBox(height: 20),
                      _buildSection(context, 'PRO', MembershipTier.pro, activeTheme),
                      const SizedBox(height: 20),
                      _buildSection(context, 'MAX', MembershipTier.max, activeTheme),
                      const SizedBox(height: 20),
                      _SpecialThemesSection(activeTheme: activeTheme),
                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String label,
    MembershipTier tier,
    AppTheme activeTheme,
  ) {
    final themes = ThemeRegistry.themesForTier(tier);
    if (themes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 12),
        ...themes.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThemeCard(
                themeData: t,
                isActive: t.theme == activeTheme,
                onTap: () => _onThemeTap(context, t),
              ),
            )),
      ],
    );
  }

  void _onThemeTap(BuildContext context, AppThemeData themeData) {
    final canAccess = ThemeService.instance.canAccess(themeData);
    if (canAccess) {
      _showPreviewSheet(context, themeData);
    } else {
      _showUpgradeDialog(context, themeData);
    }
  }

  void _showPreviewSheet(BuildContext context, AppThemeData themeData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ThemePreviewSheet(themeData: themeData),
    );
  }

  void _showUpgradeDialog(BuildContext context, AppThemeData themeData) {
    final tierName =
        themeData.requiredTier == MembershipTier.max ? 'MAX' : 'PRO';
    final icon =
        themeData.requiredTier == MembershipTier.max ? '\u{1F451}' : '\u2B50';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HunterTheme.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text(
                '$tierName Required',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Unlock Premium Themes\nUpgrade to $tierName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MembershipScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HunterTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Upgrade',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: HunterTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textPrimary.withOpacity(0.35),
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Theme Card ────────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final AppThemeData themeData;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.themeData,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !ThemeService.instance.canAccess(themeData);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? HunterTheme.primary.withOpacity(0.6)
                : HunterTheme.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Color preview circles ──
            _colorPreview(),
            const SizedBox(width: 14),
            // ── Name + tier badge ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    themeData.name,
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _tierBadge(),
                ],
              ),
            ),
            // ── Status indicator ──
            if (isActive)
              Icon(Icons.check_circle, color: HunterTheme.primary, size: 20)
            else if (isLocked)
              Icon(Icons.lock, color: HunterTheme.textFaint, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _colorPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(themeData.primary),
        const SizedBox(width: 4),
        _dot(themeData.background),
        const SizedBox(width: 4),
        _dot(themeData.card),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: HunterTheme.border,
          width: 1,
        ),
      ),
    );
  }

  Widget _tierBadge() {
    // Special themes show a different badge.
    if (themeData.isAdRewardTheme) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: HunterTheme.purpleLight.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: HunterTheme.purpleLight.withOpacity(0.3), width: 0.5),
        ),
        child: Text(
          '\u2B50 SPECIAL',
          style: TextStyle(
            color: HunterTheme.purpleLight,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
    }

    final tier = themeData.requiredTier;
    String label;
    Color color;
    switch (tier) {
      case MembershipTier.basic:
        label = 'FREE';
        color = HunterTheme.success;
      case MembershipTier.pro:
        label = 'PRO';
        color = HunterTheme.info;
      case MembershipTier.max:
        label = 'MAX';
        color = HunterTheme.gold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Theme Preview Bottom Sheet ────────────────────────────────────────────────

class _ThemePreviewSheet extends StatelessWidget {
  final AppThemeData themeData;

  const _ThemePreviewSheet({required this.themeData});

  @override
  Widget build(BuildContext context) {
    final isActive =
        ThemeService.instance.activeThemeNotifier.value == themeData.theme;

    return Container(
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: HunterTheme.primary.withOpacity(0.3), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: HunterTheme.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Preview card (simulates how the theme looks) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeData.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeData.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeData.card,
                        border: Border.all(color: themeData.primary, width: 1.5),
                      ),
                      child: Icon(Icons.person, color: themeData.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hunter Name',
                          style: TextStyle(
                            color: themeData.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'LEVEL 25',
                          style: TextStyle(
                            color: themeData.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeData.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: themeData.border, width: 1),
                      ),
                      child: Text(
                        '320 / 500 XP',
                        style: TextStyle(
                          color: themeData.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // XP bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.64,
                    minHeight: 6,
                    backgroundColor: themeData.border,
                    valueColor: AlwaysStoppedAnimation<Color>(themeData.primary),
                  ),
                ),
                const SizedBox(height: 12),
                // Mock mission tile
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeData.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: themeData.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: themeData.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Daily Mission',
                        style: TextStyle(
                          color: themeData.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+25 XP',
                        style: TextStyle(
                          color: themeData.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Theme name ──
          Text(
            themeData.name,
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          // ── Description ──
          Text(
            themeData.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),

          // ── Tier badge ──
          _previewTierBadge(themeData.requiredTier),

          const SizedBox(height: 20),

          // ── Apply button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActive
                  ? null
                  : () async {
                      await ThemeService.instance.applyTheme(themeData.theme);
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isActive ? HunterTheme.border : HunterTheme.primary,
                disabledBackgroundColor: HunterTheme.border,
                foregroundColor: Colors.white,
                disabledForegroundColor: HunterTheme.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isActive ? 'Currently Active' : 'Apply Theme',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // Extra bottom padding for devices with navigation gestures.
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }

  Widget _previewTierBadge(MembershipTier tier) {
    // For ad-reward themes, show special badge instead of tier.
    if (themeData.isAdRewardTheme) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: HunterTheme.purpleLight.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HunterTheme.purpleLight.withOpacity(0.3), width: 0.5),
        ),
        child: Text(
          '\u2B50 SPECIAL',
          style: TextStyle(
            color: HunterTheme.purpleLight,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    String label;
    Color color;
    switch (tier) {
      case MembershipTier.basic:
        label = 'FREE';
        color = HunterTheme.success;
      case MembershipTier.pro:
        label = '\u2B50 PRO';
        color = HunterTheme.info;
      case MembershipTier.max:
        label = '\u{1F451} MAX';
        color = HunterTheme.gold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Special Themes Section ────────────────────────────────────────────────────

/// Displays the "SPECIAL THEMES" section with ad-reward-gated themes.
/// Shows lock/availability status and handles the unlock flow.
class _SpecialThemesSection extends StatefulWidget {
  final AppTheme activeTheme;
  const _SpecialThemesSection({required this.activeTheme});

  @override
  State<_SpecialThemesSection> createState() => _SpecialThemesSectionState();
}

class _SpecialThemesSectionState extends State<_SpecialThemesSection> {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  // Cache unlock status per theme for synchronous rendering.
  final Map<AppTheme, DateTime?> _expiryCache = {};

  @override
  void initState() {
    super.initState();
    _loadExpiryData();
    _preloadAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadExpiryData() async {
    for (final t in ThemeRegistry.specialThemes) {
      final expiry = await ThemeService.instance.getSpecialThemeExpiry(t.theme);
      if (mounted) setState(() => _expiryCache[t.theme] = expiry);
    }
  }

  void _preloadAd() {
    _isAdLoading = true;
    RewardedAd.load(
      adUnitId: AppConstants.streakRecoveryRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (mounted) setState(() => _isAdLoading = false);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Special theme ad failed to load: $error');
          if (mounted) setState(() => _isAdLoading = false);
        },
      ),
    );
  }

  bool _isUnlocked(AppTheme theme) {
    final expiry = _expiryCache[theme];
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  String _formatExpiry(DateTime expiry) {
    final now = DateTime.now();
    final remaining = expiry.difference(now);
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours >= 1) {
      return 'Available for ${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return 'Available for ${remaining.inMinutes}m';
  }

  void _onSpecialThemeTap(AppThemeData themeData) {
    if (_isUnlocked(themeData.theme)) {
      // Already unlocked — show preview and allow apply.
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ThemePreviewSheet(themeData: themeData),
      );
    } else {
      // Locked — show ad unlock dialog.
      _showAdUnlockDialog(themeData);
    }
  }

  void _showAdUnlockDialog(AppThemeData themeData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HunterTheme.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glass icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HunterTheme.purpleLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HunterTheme.purpleLight.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.auto_awesome,
                    color: HunterTheme.purpleLight, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                themeData.name,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Watch a rewarded ad to unlock\n${themeData.name} for 24 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_rewardedAd == null)
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _showRewardedAd(themeData);
                        },
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: Text(
                    _rewardedAd == null ? 'Loading Ad...' : 'Watch Ad',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HunterTheme.primary,
                    disabledBackgroundColor: HunterTheme.border,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: HunterTheme.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
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

  void _showRewardedAd(AppThemeData themeData) {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _preloadAd(); // Preload next ad.
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _preloadAd();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad failed to show. Please try again.')),
          );
        }
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) async {
      await ThemeService.instance.unlockSpecialTheme(themeData.theme);
      await _loadExpiryData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${themeData.name} unlocked for 24 hours!'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final specialThemes = ThemeRegistry.specialThemes;
    if (specialThemes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: HunterTheme.purpleLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SPECIAL THEMES',
              style: TextStyle(
                color: HunterTheme.textPrimary.withOpacity(0.35),
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...specialThemes.map((t) {
          final unlocked = _isUnlocked(t.theme);
          final expiry = _expiryCache[t.theme];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _onSpecialThemeTap(t),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HunterTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (widget.activeTheme == t.theme)
                        ? HunterTheme.primary.withOpacity(0.6)
                        : HunterTheme.border,
                    width: (widget.activeTheme == t.theme) ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Color preview
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _colorDot(t.primary),
                        const SizedBox(width: 4),
                        _colorDot(t.background),
                        const SizedBox(width: 4),
                        _colorDot(t.card),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                              color: HunterTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (unlocked && expiry != null)
                            Text(
                              _formatExpiry(expiry),
                              style: TextStyle(
                                color: HunterTheme.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: HunterTheme.purpleLight.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: HunterTheme.purpleLight.withOpacity(0.3),
                                    width: 0.5),
                              ),
                              child: Text(
                                '\u2B50 SPECIAL',
                                style: TextStyle(
                                  color: HunterTheme.purpleLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.activeTheme == t.theme)
                      Icon(Icons.check_circle,
                          color: HunterTheme.primary, size: 20)
                    else if (!unlocked)
                      Icon(Icons.play_circle_outline,
                          color: HunterTheme.textFaint, size: 18)
                    else
                      Icon(Icons.check_circle_outline,
                          color: HunterTheme.success, size: 18),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: HunterTheme.border, width: 1),
      ),
    );
  }
}
