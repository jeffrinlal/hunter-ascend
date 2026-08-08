import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/nutrition/calorie_tracker_screen.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Nutrition tab: hosts the [CalorieTrackerCard] on a scrollable page.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => MembershipScaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: HunterTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const CalorieTrackerCard(),
          ),
        ),
      ),
    );
  }
}
