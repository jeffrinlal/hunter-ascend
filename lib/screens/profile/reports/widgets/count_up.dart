import 'package:flutter/material.dart';

/// A subtle count-up number animation.
///
/// Animates from 0 to [value] once (and re-animates only when [value] changes,
/// e.g. on a range toggle). Uses a gentle ease-out curve — no bounce, no loop —
/// to keep the "system boot-up" feel elegant rather than flashy.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.formatter,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String Function(double) formatter;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(formatter(v), style: style),
    );
  }
}
