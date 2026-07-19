import 'package:flutter/material.dart';

/// Staggered fade + slide-up entrance animation wrapper.
///
/// Purely presentational — wraps [child] and animates it in once, the first
/// time it is built. Used by the Pro and Max dashboards to give each screen
/// a distinct "premium reveal" feel on open. Holds no Firestore/business
/// state; [delay] simply staggers when each wrapped section starts its
/// animation so the dashboard reveals top-to-bottom.
class EntranceFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  const EntranceFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offsetY = 16,
  });

  @override
  State<EntranceFadeSlide> createState() => _EntranceFadeSlideState();
}

class _EntranceFadeSlideState extends State<EntranceFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<double> _dy = Tween<double>(
    begin: widget.offsetY,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _dy.value),
          child: child,
        ),
      ),
    );
  }
}
