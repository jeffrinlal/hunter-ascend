import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Premium dialog design system.
///
/// Presentation-only helpers used to give every popup a cohesive premium look
/// and a cinematic entrance (fade + gentle scale + soft backdrop blur), while
/// leaving all callbacks/actions untouched.
///
/// - [showPremiumDialog] : animated presenter (drop-in for showDialog).
/// - [PremiumDialogCard]  : the premium card scaffold (medallion + title +
///   body + actions).
/// - [PremiumDialogButton]: primary / secondary / destructive buttons that
///   match the app-wide button language (black-on-primary, etc.).

/// Animated dialog presenter: fade + gentle scale-up + a soft backdrop blur.
/// Lightweight (short 240ms transition). Fully theme-agnostic.
Future<T?> showPremiumDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, a1, a2) => Builder(builder: builder),
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          // Soft blur over the background content (subtle, transition-only).
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 4 * anim.value,
                sigmaY: 4 * anim.value,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
          FadeTransition(
            opacity: curved,
            child: Transform.scale(
              scale: 0.94 + 0.06 * curved.value,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

/// A premium dialog card scaffold: optional glowing icon medallion, title,
/// body (message or custom [content]) and an actions row.
class PremiumDialogCard extends StatelessWidget {
  final IconData? icon;
  final Color? accent;
  final String? title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  const PremiumDialogCard({
    super.key,
    this.icon,
    this.accent,
    this.title,
    this.message,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? MembershipTheme.current.accent;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a.withOpacity(0.06), HunterTheme.cardColor],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HunterTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(HunterTheme.isDark ? 0.5 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: a.withOpacity(0.10 * HunterTheme.glowStrength),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [a.withOpacity(0.22), a.withOpacity(0.08)],
                  ),
                  border: Border.all(color: a.withOpacity(0.4), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: a.withOpacity(0.25 * HunterTheme.glowStrength), blurRadius: 18),
                  ],
                ),
                child: Icon(icon, color: a, size: 30),
              ),
              const SizedBox(height: 18),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              if (message != null || content != null) const SizedBox(height: 10),
            ],
            if (content != null)
              content!
            else if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (actions.length == 1)
                SizedBox(width: double.infinity, child: actions.first)
              else
                Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

enum PremiumButtonKind { primary, secondary, destructive }

/// A premium dialog button matching the app-wide button language:
/// primary = gradient + black text; secondary = neutral outline;
/// destructive = danger-tinted. The [onTap] action is passed through as-is.
class PremiumDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final PremiumButtonKind kind;
  final IconData? icon;

  const PremiumDialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = PremiumButtonKind.primary,
    this.icon,
  });

  const PremiumDialogButton.primary(this.label, {super.key, required this.onTap, this.icon})
      : kind = PremiumButtonKind.primary;
  const PremiumDialogButton.secondary(this.label, {super.key, required this.onTap, this.icon})
      : kind = PremiumButtonKind.secondary;
  const PremiumDialogButton.destructive(this.label, {super.key, required this.onTap, this.icon})
      : kind = PremiumButtonKind.destructive;

  @override
  Widget build(BuildContext context) {
    final primary = kind == PremiumButtonKind.primary;
    final destructive = kind == PremiumButtonKind.destructive;

    final Color fg = primary
        ? (MembershipTheme.isMax ? Colors.white : Colors.black)
        : destructive
            ? HunterTheme.danger
            : HunterTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: MembershipTheme.current.gradient,
                )
              : null,
          color: primary
              ? null
              : destructive
                  ? HunterTheme.danger.withOpacity(0.10)
                  : HunterTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(
                  color: destructive
                      ? HunterTheme.danger.withOpacity(0.45)
                      : HunterTheme.border,
                ),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: MembershipTheme.current.accent.withOpacity(0.35 * HunterTheme.glowStrength),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
                  fontWeight: primary ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
