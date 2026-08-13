import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/shop/coin_shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A reusable Shop entry-point button with a subtle glow/pulse highlight
/// animation that draws the user's attention the first few times they see
/// the dashboard.
///
/// ## Version-based display logic
/// Instead of a permanent "seen" flag, this uses a version integer stored in
/// SharedPreferences (`shop_highlight_version`). The highlight plays whenever
/// the stored version is lower than [currentHighlightVersion]. After the user
/// taps the button and opens the Shop, the stored version is bumped to
/// [currentHighlightVersion], suppressing the animation until the next
/// version bump. Future shop content updates (new skins, effects, items) can
/// simply increment [currentHighlightVersion] to resurface the highlight
/// without any backend changes.
///
/// ## Animation
/// A gentle 3.5-second repeating cycle:
/// * Gold glow pulsing between low and moderate opacity (never aggressive).
/// * Subtle scale oscillation between 1.0 and 1.03.
///
/// Both cease immediately once the user taps (opening the Shop) and never
/// restart for that version. The animation is purely visual — no Firestore
/// reads, no business logic, no side effects.
///
/// ## Usage
/// Drop-in replacement for the existing inline `GestureDetector`→`Container`
/// Shop buttons on the Basic, Pro and Max dashboards. Pass [accentColor] to
/// match the tier's accent (gold for Basic, membership accent for Pro/Max),
/// and [emojiSize]/[textSize] to match the existing button proportions.
class ShopHighlightButton extends StatefulWidget {
  const ShopHighlightButton({
    super.key,
    required this.accentColor,
    this.emojiSize = 16.0,
    this.textSize = 13.0,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  /// Accent colour for the border, text and glow. Typically `HunterTheme.gold`
  /// for Basic, or `MembershipTheme.current.accent` for Pro/Max.
  final Color accentColor;

  /// Size of the 🪙 emoji text. Basic uses 16, Pro/Max strips use 14.
  final double emojiSize;

  /// Size of the "Shop" label. Basic uses 13, Pro/Max use 12.
  final double textSize;

  /// Corner radius. Basic uses 20 (pill), Pro/Max use 16.
  final double borderRadius;

  /// Internal padding. Basic uses h:12/v:8, Pro/Max use h:10/v:6.
  final EdgeInsetsGeometry padding;

  /// Increment this when new shop content warrants resurfacing the highlight.
  /// The stored version must be LOWER than this for the animation to play.
  static const int currentHighlightVersion = 1;

  /// SharedPreferences key holding the last-seen version.
  static const String _prefsKey = 'shop_highlight_version';

  @override
  State<ShopHighlightButton> createState() => _ShopHighlightButtonState();
}

class _ShopHighlightButtonState extends State<ShopHighlightButton>
    with SingleTickerProviderStateMixin {
  /// Whether the highlight animation should play (version check passed).
  bool _shouldHighlight = false;

  /// Whether the prefs read has completed (avoids a flash of un-animated
  /// state while the async read is pending — renders the static version
  /// until we know whether to animate).
  bool _ready = false;

  AnimationController? _controller;

  static const String _prefsKey = ShopHighlightButton._prefsKey;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final stored = prefs.getInt(_prefsKey) ?? 0;
    final shouldAnimate =
        stored < ShopHighlightButton.currentHighlightVersion;
    setState(() {
      _shouldHighlight = shouldAnimate;
      _ready = true;
    });
    if (shouldAnimate) _startAnimation();
  }

  void _startAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  Future<void> _onTap() async {
    // Navigate to Shop (unchanged destination).
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoinShopScreen()),
    );

    // After returning from the Shop, suppress the highlight for this version.
    if (!mounted) return;
    if (_shouldHighlight) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefsKey,
        ShopHighlightButton.currentHighlightVersion,
      );
      _controller?.stop();
      if (mounted) setState(() => _shouldHighlight = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Until the prefs read completes, render the static (un-animated) button
    // so layout never jumps.
    if (!_ready || !_shouldHighlight || _controller == null) {
      return _staticButton();
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final t = _controller!.value;
        // Sine wave: smooth 0→1→0 oscillation over the 3.5s cycle.
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
        return Transform.scale(
          scale: 1.0 + 0.03 * pulse, // max 1.03
          child: _animatedButton(pulse),
        );
      },
    );
  }

  Widget _animatedButton(double pulse) {
    final color = widget.accentColor;
    // Glow opacity oscillates between a soft base and a moderate peak.
    final glowOpacity = 0.2 + 0.35 * pulse; // 0.20 → 0.55
    final borderOpacity = 0.5 + 0.35 * pulse; // 0.50 → 0.85

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: color.withValues(alpha: borderOpacity)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: glowOpacity),
              blurRadius: 12 + 6 * pulse,
              spreadRadius: 1 * pulse,
            ),
          ],
        ),
        child: _content(),
      ),
    );
  }

  Widget _staticButton() {
    final color = widget.accentColor;
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _content(),
      ),
    );
  }

  Widget _content() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🪙', style: TextStyle(fontSize: widget.emojiSize)),
        const SizedBox(width: 6),
        Text(
          'Shop',
          style: TextStyle(
            color: widget.accentColor,
            fontSize: widget.textSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
