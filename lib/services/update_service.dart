import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now().toString().substring(0, 10);

    final lastChecked = prefs.getString('last_update_check');

    // Already checked today
    if (lastChecked == today) {
      final hasUpdate = prefs.getBool('cached_has_update') ?? false;

      if (!hasUpdate) return null;

      return {
        "title": prefs.getString('cached_title'),
        "message": prefs.getString('cached_message'),
        "forceUpdate": prefs.getBool('cached_force') ?? false,
      };
    }

    final packageInfo = await PackageInfo.fromPlatform();

    final currentVersion = packageInfo.version;

    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('app_config')
        .get();

    if (!doc.exists) return null;

    final data = doc.data()!;

    final latestVersion = data['latestVersion'];

    final updateAvailable = currentVersion != latestVersion;

    await prefs.setString('last_update_check', today);
    await prefs.setBool('cached_has_update', updateAvailable);

    if (updateAvailable) {
      await prefs.setString('cached_title', data['title']);
      await prefs.setString('cached_message', data['message']);
      await prefs.setBool('cached_force', data['forceUpdate']);
    }

    if (!updateAvailable) return null;

    return data;
  }
}