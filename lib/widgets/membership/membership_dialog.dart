import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/widgets/premium_dialog.dart';

/// Membership-aware dialog presenter.
///
/// Reuses the app-wide premium dialog system ([showPremiumDialog] +
/// [PremiumDialogCard]) but automatically colors the accent from the current
/// membership tier — gold for Pro, purple for Max, app primary for Basic.
/// No business logic is touched; the [actions] callbacks pass through as-is.
///
/// ```dart
/// showMembershipDialog(
///   context: context,
///   icon: Icons.workspace_premium_rounded,
///   title: 'Membership Expired',
///   message: '...',
///   actions: [ ... PremiumDialogButton ... ],
/// );
/// ```
Future<T?> showMembershipDialog<T>({
  required BuildContext context,
  IconData? icon,
  String? title,
  String? message,
  Widget? content,
  List<Widget> actions = const [],

  /// Override the tier-derived accent (e.g. to force a semantic color).
  Color? accent,
  bool barrierDismissible = true,
}) {
  final resolvedAccent = accent ?? MembershipTheme.current.accent;
  return showPremiumDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => PremiumDialogCard(
      icon: icon,
      accent: resolvedAccent,
      title: title,
      message: message,
      content: content,
      actions: actions,
    ),
  );
}
