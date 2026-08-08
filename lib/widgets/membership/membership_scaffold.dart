import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Ambient tier glow painted behind screen content.
///
/// * Basic → renders nothing, so the stock background is untouched.
/// * Pro   → a soft gold bloom anchored at the top of the screen.
/// * Max   → a richer purple bloom at the top plus a faint violet bloom at
///           the bottom, matching the Max dashboard's immersive feel.
///
/// The glow never intercepts pointer events ([IgnorePointer]) and sits
/// behind the screen's own [Scaffold].
class MembershipAmbientBackground extends StatelessWidget {
  const MembershipAmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    if (!tokens.isPremium) return const SizedBox.shrink();

    final isMax = MembershipTheme.isMax;

    return IgnorePointer(
      child: Stack(
        children: [
          // Top bloom.
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            height: 340,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    tokens.accent.withOpacity(isMax ? 0.20 : 0.13),
                    tokens.accent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Max-only bottom bloom for extra depth.
          if (isMax)
            Positioned(
              bottom: -140,
              left: -80,
              right: -80,
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.0,
                    colors: [
                      tokens.accentAlt.withOpacity(0.12),
                      tokens.accentAlt.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Drop-in membership-aware [Scaffold].
///
/// Keeps [HunterTheme.background] as the base color on every tier, then adds
/// the [MembershipAmbientBackground] glow behind the content for premium
/// tiers. Basic users get a pixel-identical scaffold to the stock design.
///
/// Usage — replace:
/// ```dart
/// Scaffold(backgroundColor: HunterTheme.background, appBar: ..., body: ...)
/// ```
/// with:
/// ```dart
/// MembershipScaffold(appBar: ..., body: ...)
/// ```
class MembershipScaffold extends StatelessWidget {
  const MembershipScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomSheet;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HunterTheme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const MembershipAmbientBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar,
            body: body,
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            drawer: drawer,
            endDrawer: endDrawer,
            bottomSheet: bottomSheet,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          ),
        ],
      ),
    );
  }
}
