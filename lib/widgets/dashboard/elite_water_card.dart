import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Max dashboard's redesigned hydration tracker.
///
/// Purely presentational — receives the same water state and the exact same
/// callbacks (`onAdd`, `onRemove`, `onSetCupSize`, `onEditGoal`) that already
/// drive Firestore writes in the parent screen.
///
/// Styled to match the rest of the Max "elite" design language: a gradient
/// fill, a pulsing neon glow border (same treatment as [EliteMissionCard]),
/// a glowing capsule liquid bar, gradient-filled +/- controls, and premium
/// cup-size chips. No Firestore reads/writes happen in this widget.
class EliteWaterCard extends StatefulWidget {
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
  State<EliteWaterCard> createState() => _EliteWaterCardState();
}

class _EliteWaterCardState extends State<EliteWaterCard> with SingleTickerProviderStateMixin {
  static const Color _accent = Colors.cyanAccent;
  static const List<int> _cupSizes = [150, 250, 350, 500];

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.waterIntakeMl / widget.waterGoalMl).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, _) {
        final glow = _glow.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accent.withOpacity(0.12), HunterTheme.cardColor],
            ),
            border: Border.all(color: _accent.withOpacity(0.45 + glow * 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: _accent.withOpacity(0.14 + glow * 0.18), blurRadius: 26, spreadRadius: 1),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.water_drop_rounded, color: _accent, size: 16),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'ELITE HYDRATION',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                ),
                const Spacer(),
                Text('${(progress * 100).toInt()}%', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                GestureDetector(onTap: widget.onEditGoal, child: const Icon(Icons.edit, size: 15, color: _accent)),
              ]),
              const SizedBox(height: 16),
              // Glowing capsule liquid bar.
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(children: [
                  Container(height: 22, color: HunterTheme.border),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_accent.withOpacity(0.55), _accent]),
                          boxShadow: [BoxShadow(color: _accent.withOpacity(0.4 + glow * 0.2), blurRadius: 10)],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${widget.waterIntakeMl} / ${widget.waterGoalMl} ml',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _circleBtn(Icons.remove, widget.onRemove),
                    const SizedBox(width: 10),
                    _circleBtn(Icons.add, widget.onAdd),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cupSizes.map((size) {
                  final selected = widget.selectedCupSize == size;
                  return GestureDetector(
                    onTap: () => widget.onSetCupSize(size),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: selected
                            ? const LinearGradient(colors: [_accent, Color(0xFF4DD0E1)])
                            : null,
                        color: selected ? null : _accent.withOpacity(0.08),
                        border: Border.all(color: _accent.withOpacity(selected ? 0.9 : 0.4)),
                        boxShadow: selected
                            ? [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]
                            : null,
                      ),
                      child: Text(
                        '${size}ml',
                        style: TextStyle(
                          color: selected ? Colors.black : _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accent, Color(0xFF4DD0E1)],
          ),
          boxShadow: [BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 10)],
        ),
        child: const Icon(icon, color: Colors.black, size: 18),
      ),
    );
  }
}
