import 'package:hunter_ascend/core/skins/skin_data.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';

/// Static catalog of every skin available in the app.
///
/// This is the single source of truth for skin metadata — pricing,
/// durations, names, descriptions, and rarity all live here, NOT hardcoded
/// inside [SkinService] or any UI. Adding a new skin in a future phase is a
/// two-step change: add a [SkinId] value, then add a matching entry below.
class SkinCatalog {
  SkinCatalog._();

  static const List<SkinData> all = [
    SkinData(
      id: SkinId.classic,
      name: 'Classic Hunter',
      description:
          'The original Hunter Ascend look — clean, focused, and always free.',
      coinPrice: 0,
      coinUnlockDuration: Duration.zero,
      adUnlockDuration: Duration.zero,
      previewAssetPath: 'assets/skins/classic/preview.png',
      rarity: SkinRarity.common,
      isDefault: true,
    ),
    SkinData(
      id: SkinId.shadowMonarch,
      name: 'Shadow Monarch',
      description:
          'Command the shadows with a darker, commanding presence.',
      coinPrice: 2000,
      coinUnlockDuration: Duration(days: 30),
      adUnlockDuration: Duration(days: 15),
      previewAssetPath: 'assets/skins/shadow_monarch/preview.png',
      rarity: SkinRarity.legendary,
    ),
    SkinData(
      id: SkinId.cyberHunter,
      name: 'Cyber Hunter',
      description:
          'A neon-lit, high-tech interface for the digital-age hunter.',
      coinPrice: 2000,
      coinUnlockDuration: Duration(days: 30),
      adUnlockDuration: Duration(days: 15),
      previewAssetPath: 'assets/skins/cyber_hunter/preview.png',
      rarity: SkinRarity.epic,
    ),
    SkinData(
      id: SkinId.frostborn,
      name: 'Frostborn',
      description: 'A frozen, icy aesthetic for hunters of the north.',
      coinPrice: 2000,
      coinUnlockDuration: Duration(days: 30),
      adUnlockDuration: Duration(days: 15),
      previewAssetPath: 'assets/skins/frostborn/preview.png',
      rarity: SkinRarity.epic,
    ),
    SkinData(
      id: SkinId.inferno,
      name: 'Inferno',
      description: 'A blazing, fire-forged look for hunters who bring the heat.',
      coinPrice: 2000,
      coinUnlockDuration: Duration(days: 30),
      adUnlockDuration: Duration(days: 15),
      previewAssetPath: 'assets/skins/inferno/preview.png',
      rarity: SkinRarity.epic,
    ),
  ];

  /// Looks up a skin's metadata by id. Falls back to the first catalog
  /// entry (Classic) if [id] is somehow not present — this should never
  /// happen in practice since every [SkinId] value has a matching entry.
  static SkinData getById(SkinId id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);

  /// The always-free, permanent default skin.
  static SkinData get defaultSkin =>
      all.firstWhere((s) => s.isDefault, orElse: () => all.first);
}
