import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/app_theme_data.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';

/// A background widget that provides visual depth for glassmorphism.
///
/// When the Crystal Glass theme is active, it renders a subtle gradient with
/// soft radial glows behind the content — giving `BackdropFilter` something
/// meaningful to blur. Without this, blurring a flat solid color produces
/// no visible frosted effect.
///
/// When any other theme is active, the decorative layers are hidden but the
/// widget tree structure remains identical (Stack with child at the same
/// position). This is critical: changing the tree structure conditionally
/// (e.g. returning `child` directly vs wrapping in a Stack) destroys
/// descendant Element state — including StreamBuilder's cached snapshot —
/// causing the dashboard skeleton to appear until Firestore re-delivers data.
///
/// ## Usage
/// Wrap the `body` content of a Scaffold:
/// ```dart
/// Scaffold(
///   backgroundColor: HunterTheme.background,
///   body: GlassBackground(child: SafeArea(...)),
/// )
/// ```
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  bool get _isGlassActive =>
      ThemeService.instance.activeThemeNotifier.value == AppTheme.crystalGlass;

  @override
  Widget build(BuildContext context) {
    // ALWAYS use the same tree structure (Stack) regardless of whether glass
    // is active. This preserves descendant Element identity across theme
    // switches, preventing StreamBuilder state loss.
    return Stack(
      children: [
        if (_isGlassActive) ...[
          // ── Gradient base ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HunterTheme.background,
                    HunterTheme.surface,
                    HunterTheme.background,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Top-left radial glow (soft primary accent) ──
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    HunterTheme.primary.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom-right radial glow (warm subtle) ──
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    HunterTheme.primary.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Center soft ambient glow ──
          Positioned(
            top: 200,
            left: 80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],

        // ── Actual content (always at the same position in the Stack) ──
        Positioned.fill(child: child),
      ],
    );
  }
}
