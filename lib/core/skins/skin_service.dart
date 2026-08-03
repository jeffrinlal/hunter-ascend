import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';

/// Manages skin selection, ad-reward unlock, and expiry.
///
/// Every non-classic skin is unlocked the same way for every user, regardless
/// of membership tier: watch a rewarded ad -> unlocked for 24h -> auto-revert
/// to [SkinId.classic] once expired.
class SkinService {
  SkinService._();
  static final SkinService instance = SkinService._();

  static const String _activeSkinKey = 'activeSkinId';
  static const String _expiryPrefix = 'skinExpiry_'; // + skin.name

  final ValueNotifier<SkinId> activeSkinNotifier =
  ValueNotifier<SkinId>(SkinId.classic);

  bool _initialized = false;
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final savedId = SkinId.fromId(prefs.getString(_activeSkinKey));
    if (savedId == SkinId.classic || _isStillValid(savedId, prefs)) {
      activeSkinNotifier.value = savedId;
    } else {
      // Expired while the app was closed -> revert.
      activeSkinNotifier.value = SkinId.classic;
      await prefs.setString(_activeSkinKey, SkinId.classic.name);
    }
  }

  /// Call after a rewarded ad completes successfully.
  Future<void> unlockForOneDay(SkinId skin) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final expiry = DateTime.now().add(const Duration(hours: 24));
    await prefs.setInt('$_expiryPrefix${skin.name}', expiry.millisecondsSinceEpoch);
    await prefs.setString(_activeSkinKey, skin.name);
    activeSkinNotifier.value = skin;
  }

  /// Re-checks expiry (call on app resume, e.g. from a lifecycle listener).
  Future<void> checkExpiry() async {
    final current = activeSkinNotifier.value;
    if (current == SkinId.classic) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (!_isStillValid(current, prefs)) {
      activeSkinNotifier.value = SkinId.classic;
      await prefs.setString(_activeSkinKey, SkinId.classic.name);
    }
  }

  bool isUnlocked(SkinId skin, SharedPreferences prefs) => _isStillValid(skin, prefs);

  bool _isStillValid(SkinId skin, SharedPreferences prefs) {
    final ms = prefs.getInt('$_expiryPrefix${skin.name}');
    if (ms == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(ms).isAfter(DateTime.now());
  }
}