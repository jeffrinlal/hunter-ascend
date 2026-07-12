import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toString().substring(0, 10);

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('app_config')
        .get();

    if (!doc.exists) {

      return null;
    }
    final data = doc.data()!;
    final latestVersion = data['latestVersion'];
    final updateAvailable = currentVersion != latestVersion;
    if (!updateAvailable) return null;

    final forceUpdate = data['forceUpdate'] ?? false;

    // Non-forced updates: only show once per day per specific version, so
    // the user isn't nagged every time they reopen the app. Keying by
    // version (not just the date) means pushing a NEW latestVersion later
    // today will still show immediately, instead of being blocked by a
    // stale "already checked today" flag from an older version.
    if (!forceUpdate) {
      final dismissedKey = 'dismissed_update_$latestVersion';
      if (prefs.getString(dismissedKey) == today) return null;
      await prefs.setString(dismissedKey, today);
    }

    return data;
  }
}