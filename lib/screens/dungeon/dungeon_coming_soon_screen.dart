import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Phase 3 placeholder shown after ENTER DUNGEON — dungeon gameplay arrives
/// in Phase 4.
///
/// Reached via pushReplacement from [DungeonGateScreen], so BACK pops
/// straight to the Dungeon Lobby as specified. Uses the existing premium
/// card style ([MembershipCard]) for the notice.
class DungeonComingSoonScreen extends StatelessWidget {
  const DungeonComingSoonScreen({super.key, required this.spec});

  final DungeonGateSpec spec;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final rank = dungeonGateRank(spec);

    return MembershipScaffold(
      appBar: const MembershipAppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: MembershipCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🕳', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 18),
                  Text(
                    'Dungeon Gameplay',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coming in Phase 4.',
                    style: TextStyle(
                      color: rank.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spec.name,
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MembershipButton.secondary(
                    'BACK',
                    onTap: () => Navigator.of(context).pop(),
                    expanded: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
