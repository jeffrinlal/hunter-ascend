import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Pure UI bottom navigation widget shared across MainShell and pushed routes.
///
/// Contains NO business logic, NO Firestore streams, NO navigation calls.
/// The parent is responsible for providing state and handling callbacks.
class HunterBottomNav extends StatelessWidget {
  /// Which tab index is currently selected (0-4).
  final int selectedIndex;

  /// Whether to show the red notification dot on the Duels icon.
  final bool showDuelBadge;

  /// Called when the user taps a destination. Parent handles all logic.
  final ValueChanged<int> onDestinationSelected;

  const HunterBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showDuelBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = HunterTheme.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        border: Border(
          top: BorderSide(
            color: HunterTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: HunterTheme.cardColor,
          indicatorColor: HunterTheme.primary.withOpacity(0.14),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? HunterTheme.primary
                  : inactive,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? HunterTheme.primary
                  : inactive,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Missions',
            ),
            const NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
            NavigationDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.sports_kabaddi),
                  if (showDuelBadge)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Duels',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
