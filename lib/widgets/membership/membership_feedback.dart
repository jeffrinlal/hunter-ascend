import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Membership-aware SnackBar helper.
///
/// Keeps the app-wide floating pill styling from [HunterTheme]'s
/// snackBarTheme, but tints the content icon and any action with the current
/// tier accent (gold for Pro, purple for Max, app primary for Basic).
///
/// ```dart
/// showMembershipSnackBar(context, 'Plan unlocked!',
///     icon: Icons.check_circle_rounded);
/// ```
void showMembershipSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? accent,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  final resolvedAccent = accent ?? MembershipTheme.current.accent;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: resolvedAccent, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Membership-aware premium bottom sheet presenter.
///
/// Reuses the global bottomSheetTheme (rounded top, drag handle) and adds a
/// tier-colored accent strip along the top edge for premium tiers. Basic gets
/// the stock sheet — identical to today.
Future<T?> showMembershipBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
}) {
  final tokens = MembershipTheme.current;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    builder: (ctx) {
      final sheet = builder(ctx);
      if (!tokens.isPremium) return sheet;

      return Stack(
        children: [
          sheet,
          // Tier accent strip hugging the rounded top edge.
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: tokens.gradient),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.accent
                          .withOpacity(0.4 * tokens.glowStrength),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
