import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_visual_style.dart';

/// Maps each [SkinId] to its [SkinVisualStyle].
///
/// Adding a new skin's visual identity (Phase 3+) means adding one entry
/// here — no new screens, no per-skin widget subclasses. Screens stay
/// unaware of individual skins entirely; they only ever consume a resolved
/// [SkinVisualStyle] through `SkinAwareSurface`.
class SkinStyleRegistry {
  SkinStyleRegistry._();

  /// The no-decoration style used for [SkinId.classic] and as the fallback
  /// whenever the Skin is not the active appearance (e.g. a Premium Theme
  /// is active instead — see `SkinService.isSkinAppearanceActive`).
  static const SkinVisualStyle classic = SkinVisualStyle(
    id: SkinId.classic,
    cornerShape: SkinCornerShape.rounded,
    animation: SkinAnimationStyle.none,
    baseBorderRadius: 20,
    doubleBorder: false,
    emblemIcon: null,
  );

  static const SkinVisualStyle shadowMonarch = SkinVisualStyle(
    id: SkinId.shadowMonarch,
    cornerShape: SkinCornerShape.rounded,
    animation: SkinAnimationStyle.pulseGlow,
    baseBorderRadius: 20,
    doubleBorder: true,
    emblemIcon: Icons.dark_mode_rounded,
    emblemAlignment: Alignment.bottomRight,
  );

  static const SkinVisualStyle cyberHunter = SkinVisualStyle(
    id: SkinId.cyberHunter,
    cornerShape: SkinCornerShape.sharpPanel,
    animation: SkinAnimationStyle.scanline,
    baseBorderRadius: 10,
    doubleBorder: false,
    emblemIcon: Icons.crop_free_rounded,
    emblemAlignment: Alignment.topRight,
  );

  static const SkinVisualStyle frostborn = SkinVisualStyle(
    id: SkinId.frostborn,
    cornerShape: SkinCornerShape.crystalFacet,
    animation: SkinAnimationStyle.frostShimmer,
    baseBorderRadius: 18,
    doubleBorder: false,
    emblemIcon: Icons.ac_unit_rounded,
    emblemAlignment: Alignment.topLeft,
  );

  static const SkinVisualStyle inferno = SkinVisualStyle(
    id: SkinId.inferno,
    cornerShape: SkinCornerShape.jaggedEdge,
    animation: SkinAnimationStyle.flicker,
    baseBorderRadius: 18,
    doubleBorder: false,
    emblemIcon: Icons.local_fire_department_rounded,
    emblemAlignment: Alignment.topRight,
  );

  static SkinVisualStyle forSkin(SkinId id) {
    switch (id) {
      case SkinId.classic:
        return classic;
      case SkinId.shadowMonarch:
        return shadowMonarch;
      case SkinId.cyberHunter:
        return cyberHunter;
      case SkinId.frostborn:
        return frostborn;
      case SkinId.inferno:
        return inferno;
    }
  }
}
