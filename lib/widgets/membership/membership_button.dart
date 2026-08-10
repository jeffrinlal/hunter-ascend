import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Button kinds matching the app-wide button language established by
/// [PremiumDialogButton]: primary = gradient fill, secondary = neutral
/// outline, destructive = danger-tinted.
enum MembershipButtonKind { primary, secondary, destructive }

/// Membership-aware button.
///
/// * Basic → stock primary gradient + black text (the existing app-wide
///   button language).
/// * Pro   → gold gradient + black text + warm gold glow.
/// * Max   → purple gradient + white text + purple neon glow.
///
/// Secondary and destructive kinds keep their existing neutral/danger look
/// on every tier, with premium tiers adding a subtle accent border.
class MembershipButton extends StatelessWidget {
  const MembershipButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = MembershipButtonKind.primary,
    this.icon,
    this.expanded = false,
    this.compact = false,
  });

  const MembershipButton.primary(
    this.label, {
    super.key,
    required this.onTap,
    this.icon,
    this.expanded = false,
    this.compact = false,
  }) : kind = MembershipButtonKind.primary;

  const MembershipButton.secondary(
    this.label, {
    super.key,
    required this.onTap,
    this.icon,
    this.expanded = false,
    this.compact = false,
  }) : kind = MembershipButtonKind.secondary;

  const MembershipButton.destructive(
    this.label, {
    super.key,
    required this.onTap,
    this.icon,
    this.expanded = false,
    this.compact = false,
  }) : kind = MembershipButtonKind.destructive;

  final String label;
  final VoidCallback? onTap;
  final MembershipButtonKind kind;
  final IconData? icon;

  /// Stretch to fill the available width.
  final bool expanded;

  /// Tighter padding for dense layouts (dialog rows, list actions).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    final isPrimary = kind == MembershipButtonKind.primary;
    final isDestructive = kind == MembershipButtonKind.destructive;

    // Foreground color: Professional contrast - white on gold for Pro,
    // white on purple for Max, neutral/danger for other kinds.
    final Color fg = isPrimary
        ? Colors.white // Better contrast on gold/purple gradients
        : isDestructive
            ? HunterTheme.danger
            : HunterTheme.textSecondary;

    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 10 : 14,
          horizontal: compact ? 14 : 16,
        ),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: tokens.gradient,
                )
              : null,
          color: isPrimary
              ? null
              : isDestructive
                  ? HunterTheme.danger.withOpacity(0.10)
                  : HunterTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(
                  color: isDestructive
                      ? HunterTheme.danger.withOpacity(0.45)
                      : tokens.isPremium
                          ? tokens.accent.withOpacity(0.3)
                          : HunterTheme.border,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: tokens.accent
                        .withOpacity(0.25 * tokens.glowStrength), // Reduced glow
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
