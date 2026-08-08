import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// A single destination rendered by [MembershipBottomNav].
class MembershipNavItem {
  const MembershipNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Optional overlay badge (e.g. the duel-request dot). Rendered on top of
  /// the icon regardless of selection state.
  final Widget? badge;
}

/// Membership-aware floating bottom navigation bar.
///
/// Presentation-only — all tap handling is delegated to
/// [onDestinationSelected], so navigation behaviour is never changed.
///
/// * Basic → the existing floating bar look (primary-tinted surface, primary
///   gradient active pill).
/// * Pro   → gold-tinted surface, gold border, gold gradient active pill with
///   a warm glow.
/// * Max   → purple gradient surface, purple border + glow, purple gradient
///   active pill with a stronger neon glow and animated indicator.
class MembershipBottomNav extends StatelessWidget {
  const MembershipBottomNav({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<MembershipNavItem> items;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    final isPremium = tokens.isPremium;
    final isMax = MembershipTheme.isMax;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.accent.withOpacity(isMax ? 0.14 : isPremium ? 0.10 : 0.05),
              HunterTheme.cardColor,
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isPremium
                ? tokens.accent.withOpacity(isMax ? 0.45 : 0.35)
                : HunterTheme.border,
            width: isPremium ? tokens.cardBorderWidth : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(HunterTheme.isDark ? 0.38 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: tokens.accent.withOpacity(
                (isPremium ? 0.18 : 0.10) *
                    (isPremium ? tokens.glowStrength : HunterTheme.glowStrength),
              ),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++)
              _NavItem(
                item: items[i],
                selected: i == selectedIndex,
                tokens: tokens,
                onTap: () => onDestinationSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final MembershipNavItem item;
  final bool selected;
  final MembershipThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMax = tokens.tier == MembershipTier.max;

    // Active pill foreground: white on the deep purple Max gradient, black
    // on the bright gold/primary gradients. Inactive icons stay neutral.
    final Color activeFg = isMax ? Colors.white : Colors.black;
    final Color iconColor =
        selected ? activeFg : HunterTheme.textSecondary;

    Widget iconGlyph = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 23,
      color: iconColor,
    );
    if (item.badge != null) {
      iconGlyph = Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            selected ? item.selectedIcon : item.icon,
            size: 23,
            color: iconColor,
          ),
          Positioned(right: -3, top: -3, child: item.badge!),
        ],
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated active pill (gradient on selection).
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 20 : 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: tokens.gradient,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: tokens.accent.withOpacity(
                              0.38 * tokens.glowStrength,
                            ),
                            blurRadius: 14,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: iconGlyph,
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? tokens.accent
                      : HunterTheme.textTertiary,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
