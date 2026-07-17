import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_registry.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/screens/profile/membership_screen.dart';

/// Theme Gallery screen: displays all available dark themes grouped by
/// membership tier. Tapping a theme opens a preview bottom sheet; locked
/// themes show an upgrade dialog.
class ThemeGalleryScreen extends StatelessWidget {
  const ThemeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
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
