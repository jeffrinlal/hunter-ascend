import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';

/// Global banner that appears at the top of the app when internet is lost,
/// and briefly shows a "Back Online" confirmation when connectivity returns.
///
/// Wrap the entire app content (e.g., inside MaterialApp's builder) with this
/// widget so it works across all screens without per-screen listeners.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOffline = false;
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.status.addListener(_onStatusChange);
    _isOffline = !ConnectivityService.instance.status.value;
  }

  @override
  void dispose() {
    ConnectivityService.instance.status.removeListener(_onStatusChange);
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  void _onStatusChange() {
    final online = ConnectivityService.instance.status.value;
    if (online && _isOffline) {
      // Just came back online
      setState(() {
        _isOffline = false;
        _showBackOnline = true;
      });
      _backOnlineTimer?.cancel();
      _backOnlineTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    } else if (!online) {
      setState(() {
        _isOffline = true;
        _showBackOnline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: Colors.red.shade800,
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You're Offline — Internet connection is required for gameplay.",
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            actions: const [SizedBox.shrink()],
          ),
        if (_showBackOnline && !_isOffline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: Colors.green.shade700,
            content: const Row(
              children: [
                Icon(Icons.wifi, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  "Back Online",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
