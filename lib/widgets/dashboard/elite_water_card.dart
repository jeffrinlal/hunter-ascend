import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Max dashboard's redesigned hydration tracker.
///
/// Purely presentational — receives the same water state and the exact same
/// callbacks (`onAdd`, `onRemove`, `onSetCupSize`, `onEditGoal`) that already
/// drive Firestore writes in the parent screen. Rendered as a neon
/// capsule-shaped liquid bar with a glowing border, distinct from both the
/// Basic dashboard's linear bar + drop icons and the Pro dashboard's
/// circular gauge. No Firestore reads/writes happen in this widget.
class EliteWaterCard extends StatelessWidget {
  final int waterIntakeMl;
  final int waterGoalMl;
  final int selectedCupSize;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<int> onSetCupSize;
  final VoidCallback onEditGoal;

  const EliteWaterCard({
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
    const accent = Colors.cyanAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(0.45), width: 1.4),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 22, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('ELITE HYDRATION', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const Spacer(),
            Text('${(progress * 100).toInt()}%', style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            GestureDetector(onTap: onEditGoal, child: const Icon(Icons.edit, size: 15, color: accent)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(children: [
              Container(height: 22, color: HunterTheme.border),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent.withOpacity(0.5), accent]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$waterIntakeMl / $waterGoalMl ml', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(children: [
                _circleBtn(Icons.remove, onRemove),
                const SizedBox(width: 8),
                _circleBtn(Icons.add, onAdd),
              ]),
            ],
          ),
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
                    color: selected ? accent.withOpacity(0.9) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.7)),
                  ),
                  child: Text(
                    '${size}ml',
                    style: TextStyle(color: selected ? Colors.black : accent, fontWeight: FontWeight.w700, fontSize: 12),
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.cyanAccent),
          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.35), blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.cyanAccent, size: 16),
      ),
    );
  }
}
