import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';

/// Membership-aware circular loading indicator.
///
/// Basic → plain primary-colored spinner (stock look).
/// Pro/Max → tier accent spinner wrapped in a soft matching glow.
class MembershipLoadingIndicator extends StatelessWidget {
  const MembershipLoadingIndicator({super.key, this.size = 32, this.padding});

  final double size;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;

    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
      ),
    );

    final glow = tokens.isPremium
        ? Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: tokens.accent
                      .withOpacity(0.30 * tokens.glowStrength),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: spinner,
          )
        : spinner;

    return Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: Center(child: glow),
    );
  }
}

/// Membership-aware linear progress bar (gradient fill for premium tiers).
class MembershipLinearProgress extends StatelessWidget {
  const MembershipLinearProgress({
    super.key,
    required this.value,
    this.height = 8,
  });

  /// Progress in the 0..1 range (clamped).
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    final v = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: tokens.accent.withOpacity(0.14),
              ),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: tokens.gradient),
                  boxShadow: tokens.isPremium
                      ? [
                          BoxShadow(
                            color: tokens.accent.withOpacity(
                              0.35 * tokens.glowStrength,
                            ),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membership-aware empty state (icon medallion + title + message).
///
/// The medallion uses the tier accent — subtle for Basic, golden for Pro,
/// glowing purple for Max.
class MembershipEmptyState extends StatelessWidget {
  const MembershipEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.accent.withOpacity(0.20),
                    tokens.accent.withOpacity(0.06),
                  ],
                ),
                border: Border.all(
                  color: tokens.accent.withOpacity(0.35),
                  width: 1.4,
                ),
                boxShadow: tokens.isPremium
                    ? [
                        BoxShadow(
                          color: tokens.accent.withOpacity(
                            0.22 * tokens.glowStrength,
                          ),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, color: tokens.accent, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Membership-aware error state with an optional retry action.
class MembershipErrorState extends StatelessWidget {
  const MembershipErrorState({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MembershipEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Oops!',
      message: message,
      action: onRetry == null
          ? null
          : MembershipButton.secondary(
              'Try Again',
              onTap: onRetry,
              icon: Icons.refresh_rounded,
            ),
    );
  }
}
