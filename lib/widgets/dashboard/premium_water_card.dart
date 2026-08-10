import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Pro dashboard's redesigned hydration tracker.
///
/// Purely presentational — receives the same water state the Basic
/// dashboard's water card manages (intake, goal, cup size) plus the exact
/// same callbacks the parent screen already wires to Firestore
/// (`_addWater`, `_removeWater`, `_setCupSize`, `_showWaterGoalSheet`). This
/// widget renders a circular gauge + pill cup-size chips instead of the
/// Basic dashboard's linear bar and water-drop icons — it performs no
/// Firestore reads/writes itself.
class PremiumWaterCard extends StatelessWidget {
  final int waterIntakeMl;
  final int waterGoalMl;
  final int selectedCupSize;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<int> onSetCupSize;
  final VoidCallback onEditGoal;

  const PremiumWaterCard({
    super.key,
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.selectedCupSize,
    required this.onAdd,
    required this.onRemove,
    required this.onSetCupSize,
    required this.onEditGoal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (waterIntakeMl / waterGoalMl).clamp(0.0, 1.0);
    const accent = Colors.cyan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        // Professional: dark surface with subtle cyan accent
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: accent.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.water_drop_rounded, color: accent, size: 18),
            const SizedBox(width: 6),
            Text('HYDRATION', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const Spacer(),
            GestureDetector(onTap: onEditGoal, child: const Icon(Icons.edit, size: 15, color: accent)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(value: 1, strokeWidth: 7, color: HunterTheme.border),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 700),
                    builder: (context, value, _) => SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        color: accent,
                      ),
                    ),
                  ),
                  Text('${(progress * 100).toInt()}%', style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$waterIntakeMl ml', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('of $waterGoalMl ml goal', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _circleBtn(Icons.remove, onRemove),
            const SizedBox(width: 8),
            _circleBtn(Icons.add, onAdd),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [150, 250, 350, 500].map((size) {
              final selected = selectedCupSize == size;
              return GestureDetector(
                onTap: () => onSetCupSize(size),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? accent : HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.6)),
                  ),
                  child: Text(
                    '${size}ml',
                    style: TextStyle(color: selected ? Colors.white : accent, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00D9E8), Color(0xFF00B8C7)],
          ),
          boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
