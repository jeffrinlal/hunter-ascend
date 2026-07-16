import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lightweight global connectivity monitor.
///
/// Periodically checks internet reachability via a DNS lookup (no external
/// package dependency). Exposes a [ValueNotifier<bool>] for the app-wide
/// connectivity banner, and a static [isOnline] helper for imperative checks
/// before gameplay actions.
///
/// Lifecycle-aware: automatically pauses polling when the app enters the
/// background and resumes when it returns to the foreground.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  /// Current connectivity state. `true` = online.
  final ValueNotifier<bool> status = ValueNotifier<bool>(true);

  Timer? _timer;

  /// Starts periodic monitoring (every 15 seconds) and registers the
  /// lifecycle observer to pause/resume automatically.
  void start() {
    _check(); // immediate first check
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stops monitoring and removes the lifecycle observer.
  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background — stop polling to save battery.
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground — resume polling.
      _check(); // immediate check on resume
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
    }
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
