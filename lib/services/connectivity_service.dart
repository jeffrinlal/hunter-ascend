import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Lightweight global connectivity monitor.
///
/// Periodically checks internet reachability via a DNS lookup (no external
/// package dependency). Exposes a [ValueNotifier<bool>] for the app-wide
/// connectivity banner, and a static [isOnline] helper for imperative checks
/// before gameplay actions.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// Current connectivity state. `true` = online.
  final ValueNotifier<bool> status = ValueNotifier<bool>(true);

  Timer? _timer;

  /// Starts periodic monitoring (every 5 seconds).
  void start() {
    _check(); // immediate first check
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  /// Stops monitoring (e.g., on app dispose).
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One-shot connectivity check. Returns `true` if online.
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _check() async {
    final online = await isOnline();
    if (status.value != online) {
      status.value = online;
      debugPrint("CONNECTIVITY: ${online ? 'ONLINE' : 'OFFLINE'}");
    }
  }
}
