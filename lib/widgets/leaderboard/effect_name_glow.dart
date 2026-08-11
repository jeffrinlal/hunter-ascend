import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps a hunter's name [Text] widget with the appropriate leaderboard effect
/// glow based on [effectId]. If [effectId] is null, the child is returned
/// as-is (zero overhead for hunters without an active effect).
///
/// Performance contract:
/// - NO AnimationController per row. A single shared [Animation<double>]
///   is passed in from a parent-level ticker so all rows animate in sync
///   without each allocating its own controller.
/// - Each effect applies only lightweight [BoxShadow] / [ShaderMask] /
///   [DecoratedBox] treatments — no CustomPainter per row, no particle
///   system per row, no BackdropFilter.
/// - The name text itself remains readable and is never blurred.
/// - Layout is stable: no padding/margin/size change between effects.
class EffectNameGlow extends StatelessWidget {
  const EffectNameGlow({
    super.key,
    required this.child,
    required this.effectId,
    required this.animation,
  });

  /// The name [Text] widget to wrap.
  final Widget child;

  /// The active effect ID (e.g. 'effect_fire_aura'), or null for no effect.
  final String? effectId;

  /// A 0→1 repeating animation value from a SHARED parent controller.
  /// All rows share one ticker so no per-row AnimationController exists.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (effectId == null) return child;

    final config = _effectConfig(effectId!);
    if (config == null) return child;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return _buildGlow(config, t);
      },
    );
  }

  Widget _buildGlow(_EffectConfig config, double t) {
    // Pulsing glow intensity: oscillates between 0.4 and 1.0
    final pulse = 0.4 + 0.6 * ((math.sin(t * math.pi * 2 * config.pulseSpeed) + 1) / 2);
    // Secondary phase offset for dual-tone effects
    final pulse2 = 0.4 + 0.6 * ((math.cos(t * math.pi * 2 * config.pulseSpeed * 1.3) + 1) / 2);

    final List<BoxShadow> shadows = [
      // Primary glow
      BoxShadow(
        color: config.primary.withOpacity(0.6 * pulse),
        blurRadius: config.blurRadius * pulse,
        spreadRadius: 0,
      ),
      // Secondary glow (offset color for depth)
      BoxShadow(
        color: config.secondary.withOpacity(0.35 * pulse2),
        blurRadius: config.blurRadius * 0.6 * pulse2,
        spreadRadius: 0,
      ),
    ];

    // The ShaderMask gives the text itself a gradient tint without changing
    // its size or layout. The outer Container supplies the ambient glow.
    return Container(
      decoration: BoxDecoration(
        boxShadow: shadows,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            config.primary,
            config.textTint,
            config.primary,
          ],
          stops: [
            (t * config.sweepSpeed) % 1.0,
            ((t * config.sweepSpeed) + 0.5) % 1.0,
            ((t * config.sweepSpeed) + 1.0) % 1.0,
          ],
          tileMode: TileMode.repeated,
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: child,
      ),
    );
  }

  static _EffectConfig? _effectConfig(String effectId) {
    return _configs[effectId];
  }

  static const Map<String, _EffectConfig> _configs = {
    // ── Fire Aura ──
    // Warm fiery glow with heat shimmer motion
    'effect_fire_aura': _EffectConfig(
      primary: Color(0xFFFF6B00),
      secondary: Color(0xFFFFD700),
      textTint: Color(0xFFFFA500),
      blurRadius: 12,
      pulseSpeed: 1.8,
      sweepSpeed: 0.7,
    ),
    // ── Frost Aura ──
    // Icy crystalline glow with slow, deliberate pulse
    'effect_frost_aura': _EffectConfig(
      primary: Color(0xFF00D4FF),
      secondary: Color(0xFFB0E0FF),
      textTint: Color(0xFF7FEFFF),
      blurRadius: 10,
      pulseSpeed: 0.8,
      sweepSpeed: 0.4,
    ),
    // ── Lightning Aura ──
    // Electric crackle with rapid pulsing
    'effect_lightning_aura': _EffectConfig(
      primary: Color(0xFFFFFF00),
      secondary: Color(0xFF00BFFF),
      textTint: Color(0xFFE0FF80),
      blurRadius: 14,
      pulseSpeed: 3.2,
      sweepSpeed: 1.5,
    ),
    // ── Shadow Aura ──
    // Dark energy with deep purple undertones
    'effect_shadow_aura': _EffectConfig(
      primary: Color(0xFF6A0DAD),
      secondary: Color(0xFF1A0030),
      textTint: Color(0xFFBB86FC),
      blurRadius: 11,
      pulseSpeed: 1.0,
      sweepSpeed: 0.3,
    ),
    // ── Cosmic Aura ──
    // Celestial starlight with multi-hue nebula sweep
    'effect_cosmic_aura': _EffectConfig(
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      textTint: Color(0xFFC084FC),
      blurRadius: 13,
      pulseSpeed: 1.2,
      sweepSpeed: 0.6,
    ),
    // ── Aqua Aura ──
    // Flowing water currents with gentle wave motion
    'effect_aqua_aura': _EffectConfig(
      primary: Color(0xFF0077B6),
      secondary: Color(0xFF48CAE4),
      textTint: Color(0xFF90E0EF),
      blurRadius: 10,
      pulseSpeed: 0.9,
      sweepSpeed: 0.5,
    ),
    // ── Nature Aura ──
    // Organic green energy with life-pulse rhythm
    'effect_nature_aura': _EffectConfig(
      primary: Color(0xFF2D6A4F),
      secondary: Color(0xFF95D5B2),
      textTint: Color(0xFF74C69D),
      blurRadius: 9,
      pulseSpeed: 1.1,
      sweepSpeed: 0.35,
    ),
    // ── Void Aura ──
    // Deep void with consuming dark energy and inverse glow
    'effect_void_aura': _EffectConfig(
      primary: Color(0xFF0D0221),
      secondary: Color(0xFF4A0E4E),
      textTint: Color(0xFF7B2D8B),
      blurRadius: 15,
      pulseSpeed: 0.6,
      sweepSpeed: 0.2,
    ),
    // ── Divine Aura ──
    // Radiant celestial gold with holy brilliance
    'effect_divine_aura': _EffectConfig(
      primary: Color(0xFFFFD700),
      secondary: Color(0xFFFFF8E1),
      textTint: Color(0xFFFFECB3),
      blurRadius: 14,
      pulseSpeed: 1.4,
      sweepSpeed: 0.8,
    ),
    // ── Soul Reaper Aura ──
    // Spectral ghostly energy with ethereal drift
    'effect_soul_reaper_aura': _EffectConfig(
      primary: Color(0xFF64FFDA),
      secondary: Color(0xFF004D40),
      textTint: Color(0xFFA7FFEB),
      blurRadius: 12,
      pulseSpeed: 0.7,
      sweepSpeed: 0.45,
    ),
  };
}

/// Visual configuration for one effect. Each effect has genuinely different:
/// - [primary] / [secondary] glow colors (character)
/// - [textTint] — the name's gradient tint color
/// - [blurRadius] — glow spread (energy style)
/// - [pulseSpeed] — how fast the glow breathes (motion style)
/// - [sweepSpeed] — how fast the text gradient sweeps (name glow treatment)
class _EffectConfig {
  const _EffectConfig({
    required this.primary,
    required this.secondary,
    required this.textTint,
    required this.blurRadius,
    required this.pulseSpeed,
    required this.sweepSpeed,
  });

  final Color primary;
  final Color secondary;
  final Color textTint;
  final double blurRadius;
  final double pulseSpeed;
  final double sweepSpeed;
}
