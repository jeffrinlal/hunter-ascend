import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Membership-aware app bar ([PreferredSizeWidget], drop-in for [AppBar]).
///
/// * Basic → identical to the stock app bar (background = app background,
///   elevation 0, standard foreground colors).
/// * Pro   → premium glass/gradient wash (gold → transparent) with a gold
///   hairline bottom edge.
/// * Max   → luxury gradient (deep violet → purple) with white foreground
///   and a purple glow, matching the Max dashboard hero.
class MembershipAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MembershipAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bottom,
    this.centerTitle = true,
  });

  /// Simple string title (mutually exclusive with [titleWidget]).
  final String? title;

  /// Custom title widget (takes precedence over [title]).
  final Widget? titleWidget;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;

  /// Optional bottom widget (e.g. a TabBar). Its height is added to the
  /// preferred size automatically.
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;

    Widget resolvedTitle;
    if (titleWidget != null) {
      resolvedTitle = titleWidget!;
    } else {
      resolvedTitle = Text(
        title ?? '',
        style: TextStyle(
          color: MembershipTheme.isMax
              ? Colors.white
              : HunterTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      );
    }

    final appBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: resolvedTitle,
      actions: actions,
      bottom: bottom,
      foregroundColor:
          MembershipTheme.isMax ? Colors.white : HunterTheme.textSecondary,
      iconTheme: IconThemeData(
        color: MembershipTheme.isMax ? Colors.white : HunterTheme.textSecondary,
      ),
    );

    // Basic: no decoration — the scaffold background shows through.
    if (!tokens.isPremium) return appBar;

    final isMax = MembershipTheme.isMax;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isMax
              ? tokens.heroGradient
              : [
                  tokens.accent.withOpacity(0.18),
                  tokens.accent.withOpacity(0.04),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: tokens.accent.withOpacity(isMax ? 0.5 : 0.25),
            width: isMax ? 1.2 : 1.0,
          ),
        ),
        boxShadow: isMax
            ? [
                BoxShadow(
                  color: tokens.accent
                      .withOpacity(0.25 * tokens.glowStrength),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: appBar,
    );
  }
}
