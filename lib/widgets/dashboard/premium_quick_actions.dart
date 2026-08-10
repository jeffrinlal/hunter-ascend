import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Pro dashboard's redesigned horizontal quick-actions row.
///
/// Purely presentational — the [onNutritionTap]/[onMapTap] callbacks are
/// supplied by the parent screen and perform the exact same navigation
/// (`NutritionScreen` / `MapScreen`) as the Basic dashboard's quick actions.
/// This widget only changes how those two actions look: floating pill
/// buttons with icon + label side-by-side, instead of the Basic dashboard's
/// stacked icon-over-label square cards.
class PremiumQuickActions extends StatelessWidget {
  final VoidCallback onNutritionTap;
  final VoidCallback onMapTap;

  const PremiumQuickActions({
    super.key,
    required this.onNutritionTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback, Color)>[
      (Icons.restaurant_menu_rounded, 'Nutrition', onNutritionTap, HunterTheme.gold),
      (Icons.map_rounded, 'Map', onMapTap, HunterTheme.primary),
    ];

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, label, onTap, color) = items[i];
          return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(colors: [color.withOpacity(0.16), HunterTheme.cardColor]),
                border: Border.all(color: color.withOpacity(0.4)),
                boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
