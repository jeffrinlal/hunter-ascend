import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Max dashboard's redesigned quick-actions row.
///
/// Purely presentational — [onNutritionTap]/[onMapTap] are the same
/// navigation callbacks the Basic and Pro dashboards use. Rendered as
/// square glass tiles with a glowing elite border and icon-above-label
/// layout, distinct from the Basic dashboard's plain cards and the Pro
/// dashboard's scrolling pill row.
class EliteQuickActions extends StatelessWidget {
  final VoidCallback onNutritionTap;
  final VoidCallback onMapTap;

  const EliteQuickActions({
    super.key,
    required this.onNutritionTap,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _tile(Icons.restaurant_menu_rounded, 'NUTRITION', onNutritionTap, HunterTheme.purple)),
      const SizedBox(width: 12),
      Expanded(child: _tile(Icons.map_rounded, 'MAP', onMapTap, HunterTheme.purpleLight)),
    ]);
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: HunterTheme.cardColor,
          border: Border.all(color: accent.withOpacity(0.5), width: 1.3),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.22), blurRadius: 16, spreadRadius: 1)],
        ),
        child: Column(children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5),
          ),
        ]),
      ),
    );
  }
}
