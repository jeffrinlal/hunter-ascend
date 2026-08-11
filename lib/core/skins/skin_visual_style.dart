import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';

/// How a skin's decorative animation behaves. This is purely a *structural/
/// motion* descriptor — it never carries a color. Colors are always pulled
/// from the existing [HunterTheme]/[MembershipTheme] tokens at render time,
/// so a skin can never override the active Premium Theme's palette.
enum SkinAnimationStyle {
  /// No animation — used by [SkinId.classic] so it renders pixel-identical
  /// to the pre-Phase-3 UI.
  none,

  /// Slow border/glow breathing (Shadow Monarch — brooding, deliberate).
  pulseGlow,

  /// Continuous top-to-bottom sweep (Cyber Hunter — HUD scan effect).
  scanline,

  /// Diagonal highlight sweep, reversing (Frostborn — light glinting off
  /// ice/crystal facets).
  frostShimmer,

  /// Fast, irregular-feeling opacity flicker (Inferno — unstable flame).
  flicker,
}

/// How a skin reshapes a card's silhouette. Purely geometric — never a
/// color change.
enum SkinCornerShape {
  /// Standard uniform rounded rectangle — [SkinId.classic].
  rounded,

  /// Tighter, less-rounded corners for an angular HUD-panel feel (Cyber).
  sharpPanel,

  /// One or two corners clipped into an angular facet (Frostborn).
  crystalFacet,

  /// A jagged/zigzag bottom edge (Inferno).
  jaggedEdge,
}

/// Pure data describing how a skin restructures a card's presentation:
/// silhouette, border treatment, decorative corner emblem, and animation
/// style. Contains **no color values** of its own — every color reference
/// resolved by a consumer of this style must come from the existing
/// `HunterTheme`/`MembershipTheme` token getters, never a hardcoded hex.
/// This is what enforces "a Skin is not a color theme" at the type level.
@immutable
class SkinVisualStyle {
  const SkinVisualStyle({
    required this.id,
    required this.cornerShape,
    required this.animation,
    required this.baseBorderRadius,
    required this.doubleBorder,
    this.emblemIcon,
    this.emblemAlignment = Alignment.topRight,
  });

  /// Which skin this style belongs to (for debugging/asserts only).
  final SkinId id;

  final SkinCornerShape cornerShape;
  final SkinAnimationStyle animation;

  /// Corner radius for the card's own background (before any
  /// [cornerShape]-driven clip is applied on top).
  final double baseBorderRadius;

  /// Whether the card's border renders as two concentric rings instead of
  /// one (Shadow Monarch's layered, "system panel" feel).
  final bool doubleBorder;

  /// Small decorative badge icon rendered in a corner, using the theme's
  /// existing accent/gold/info/danger token (never a new hardcoded color).
  /// `null` for [SkinId.classic] — no badge is added.
  final IconData? emblemIcon;

  final Alignment emblemAlignment;

  /// Whether this style introduces any visible decoration at all. Used by
  /// consumers to short-circuit straight back to the pre-existing plain
  /// rendering for Classic (or when the skin is not the active appearance),
  /// guaranteeing no behavior/appearance change in that case.
  bool get hasDecoration => animation != SkinAnimationStyle.none || emblemIcon != null || doubleBorder;
}
