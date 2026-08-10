import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/nutrition/calorie_tracker_screen.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:hunter_ascend/services/feature_unlock_service.dart';

/// Nutrition tab: hosts the [CalorieTrackerCard] on a scrollable page.
/// For Basic users, requires a 30-day unlock via rewarded ad.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  bool _isChecking = true;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final unlocked = await FeatureUnlockService.instance.isNutritionUnlocked();
    if (!mounted) return;

    if (!unlocked) {
      // Not unlocked - go back immediately
      Navigator.of(context).pop();
      // Show message after navigation completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Nutrition is locked. Watch an ad to unlock!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      return;
    }

    setState(() {
      _isUnlocked = true;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show loading while checking access
      return Scaffold(
        backgroundColor: HunterTheme.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isUnlocked) {
      // This shouldn't be reached due to pop in _checkAccess, but safety fallback
      return Scaffold(
        backgroundColor: HunterTheme.background,
        body: const Center(
          child: Text('Access Denied'),
        ),
      );
    }

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
