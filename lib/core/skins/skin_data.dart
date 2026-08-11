import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';

/// Cosmetic rarity tier for a skin — display-only metadata (e.g. for a
/// rarity-colored border in a future Shop UI). Has no effect on pricing,
/// duration, or access logic.
enum SkinRarity { common, rare, epic, legendary }

/// Static metadata describing one skin: identity, pricing, unlock durations,
/// and display info. This is a pure data holder — it has no Firestore/prefs
/// logic of its own (that lives in [SkinService]) and no UI-specific values
/// beyond a placeholder asset path reference.
///
/// ## Access model
/// A skin is never permanently purchased (except [SkinId.classic], which is
/// always free and permanent via [isDefault]). Every other skin grants
/// *temporary* access through exactly one of two paths:
/// - Coins: pay [coinPrice] coins, get [coinUnlockDuration] of access.
/// - Rewarded ad: watch one ad, get [adUnlockDuration] of access.
@immutable
class SkinData {
  const SkinData({
    required this.id,
    required this.name,
    required this.description,
    required this.coinPrice,
    required this.coinUnlockDuration,
    required this.adUnlockDuration,
    required this.previewAssetPath,
    required this.rarity,
    this.isDefault = false,
  });

  /// Stable identifier — matches a [SkinId] enum value.
  final SkinId id;

  /// Display name shown in the (future) Shop UI.
  final String name;

  /// Short display description shown in the (future) Shop UI.
  final String description;

  /// Coin cost to unlock via [SkinService.purchaseSkinWithCoins]. `0` for
  /// the default skin, which is never purchased.
  final int coinPrice;

  /// How long a coin purchase grants access for. [Duration.zero] for the
  /// default skin (access is permanent, not time-limited).
  final Duration coinUnlockDuration;

  /// How long a completed rewarded ad grants access for. [Duration.zero]
  /// for the default skin (not applicable — it's already always available).
  final Duration adUnlockDuration;

  /// Placeholder reference to the skin's preview/asset. No actual asset
  /// file is required to exist yet — this is just a stable path string for
  /// later phases to wire up real art against.
  final String previewAssetPath;

  /// Cosmetic rarity tier (display-only).
  final SkinRarity rarity;

  /// Whether this is the default, always-free, permanent skin. Exactly one
  /// entry in [SkinCatalog.all] should have this set to `true`.
  final bool isDefault;
}
