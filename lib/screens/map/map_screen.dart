import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

/// Live GPS run-tracking screen with route stats and saved-run history.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => HunterTheme.primary;
  static Color get _border => HunterTheme.border;
  // ── Map ──────────────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<LatLng> _routePoints = [];

  // Cached stream for run history (stable identity across rebuilds).
  late final Stream<QuerySnapshot> _runsHistoryStream = FirebaseFirestore
      .instance
      .collection('runs')
      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots();

  // ── Tracking ─────────────────────────────────────────────
  bool _isTracking = false;
  bool _isPaused = false;
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  bool _isSavingRun = false;
  int _elapsedSeconds = 0;
  double _distanceKm = 0;
  int _selectedTab = 0; // 0 = map, 1 = history

  // ── Banner Ad ────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // ── Stats ────────────────────────────────────────────────
  double get _speedKmh {
    if (_elapsedSeconds == 0) return 0;
    return (_distanceKm / _elapsedSeconds) * 3600;
  }

  double get _caloriesBurned {
    // ~60 cal per km (average person)
    return _distanceKm * 60;
  }

  int get _xpEarned {
    // 10 XP per 100m
    return (_distanceKm * 100).toInt();
  }

  String get _timerDisplay {
    final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Init ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _positionStream = null;
    _timer?.cancel();
    _timer = null;
    _bannerAd?.dispose();
    super.dispose();
  }

  // ── Banner Ad loading ───────────────────────────────────
  void _loadBannerAd() {
    // Max tier hides banner ads entirely — skip the load so nothing is
    // requested or rendered for those hunters.
    if (!MembershipService.instance.showBannerAds) return;

    final adUnitId = AppConstants.mapHistoryBannerAdUnitId;

    _bannerAd = AdsService.createBannerAd(
      adUnitId: adUnitId,
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() => _isBannerLoaded = true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        debugPrint('Banner ad failed to load: $error');
      },
    );

    _bannerAd!.load();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enable location services")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied. Enable in settings.")));
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      try {
        _mapController.move(_currentPosition!, 16);
      } catch (_) {}
    } catch (e) {
      debugPrint("getCurrentPosition error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not determine location. Please try again.")),
        );
      }
    }
  }

  // ── Tracking ─────────────────────────────────────────────
  Future<void> _startTracking() async {
    if (_isTracking) return;

    // Re-verify location permission and services immediately before tracking.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enable location services to start a run.")));
      return;
    }
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission required to start a run.")));
      return;
    }

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _routePoints = [];
      _elapsedSeconds = 0;
      _distanceKm = 0;
    });

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });

    // GPS Stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(
          (position) {
        final newPoint = LatLng(position.latitude, position.longitude);

        if (_routePoints.isNotEmpty && !_isPaused) {
          final lastPoint = _routePoints.last;
          final distance = const Distance().as(LengthUnit.Kilometer, lastPoint, newPoint);
          // Ignore unrealistic GPS jumps so a sudden spike can't inflate distance.
          if (distance > 0 && distance < 0.1) {
            setState(() => _distanceKm += distance);
          }
        }

        setState(() {
          _currentPosition = newPoint;
          if (!_isPaused) _routePoints.add(newPoint);
        });

        try {
          _mapController.move(newPoint, _mapController.camera.zoom);
        } catch (_) {}
      },
      onError: (error) {
        debugPrint("GPS stream error: $error");
        // Stop tracking safely on stream error (e.g., permission revoked mid-run).
        _positionStream?.cancel();
        _positionStream = null;
        _timer?.cancel();
        _timer = null;
        if (mounted) {
          setState(() {
            _isTracking = false;
            _isPaused = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location tracking stopped due to an error.")),
          );
        }
      },
    );
  }

  void _pauseTracking() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopTracking() async {
    _positionStream?.cancel();
    _positionStream = null;
    _timer?.cancel();
    _timer = null;

    if (_distanceKm < 0.01) {
      setState(() { _isTracking = false; _isPaused = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Too short to save! Keep running 🏃")));
      return;
    }

    // Show summary
    await _showRunSummary();
  }

  Future<void> _showRunSummary() async {
    bool isSaving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border, width: 1.5),
              boxShadow: [BoxShadow(color: _blue.withOpacity(0.2), blurRadius: 30)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🏆 RUN COMPLETE!", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 24),

                // Stats grid
                Row(children: [
                  _statBox("📍 DISTANCE", "${_distanceKm.toStringAsFixed(2)} km", _blue),
                  const SizedBox(width: 10),
                  _statBox("⏱️ TIME", _timerDisplay, Colors.orange),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _statBox("🔥 CALORIES", "${_caloriesBurned.toStringAsFixed(0)} kcal", Colors.redAccent),
                  const SizedBox(width: 10),
                  _statBox("⚡ XP EARNED", "+$_xpEarned XP", HunterTheme.success),
                ]),
                const SizedBox(height: 10),
                _statBox("💨 AVG SPEED", "${_speedKmh.toStringAsFixed(1)} km/h", Colors.purpleAccent),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isSaving ? null : () async {
                      setDialogState(() => isSaving = true);
                      // Capture route before _saveRun clears it.
                      final savedRoute = List<LatLng>.from(_routePoints);
                      final savedDistance = _distanceKm;
                      final savedDuration = _elapsedSeconds;
                      final savedSpeed = _speedKmh;
                      final savedCalories = _caloriesBurned;
                      final savedXp = _xpEarned;
                      final savedTimerDisplay = _timerDisplay;
                      final success = await _saveRun();
                      if (!mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext);
                        await _showShareRunDialog(
                          route: savedRoute,
                          distanceKm: savedDistance,
                          durationSeconds: savedDuration,
                          speedKmh: savedSpeed,
                          calories: savedCalories,
                          xpEarned: savedXp,
                          timerDisplay: savedTimerDisplay,
                        );
                        setState(() { _isTracking = false; _isPaused = false; });
                      } else {
                        setDialogState(() => isSaving = false);
                      }
                    },
                    child: isSaving
                        ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HunterTheme.textPrimary,
                      ),
                    )
                        : Text("SAVE RUN ⚡", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                  ),
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: isSaving ? null : () {
                    Navigator.pop(dialogContext);
                    setState(() { _isTracking = false; _isPaused = false; });
                  },
                  child: Text("DISCARD", style: TextStyle(color: HunterTheme.textTertiary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _saveRun() async {
    if (_isSavingRun) return false;
    if (!await ConnectivityService.isOnline()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
      return false;
    }
    _isSavingRun = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Save run to Firestore
      await FirebaseFirestore.instance.collection('runs').add({
        'uid': user.uid,
        'distanceKm': _distanceKm,
        'durationSeconds': _elapsedSeconds,
        'caloriesBurned': _caloriesBurned,
        'xpEarned': _xpEarned,
        'avgSpeedKmh': _speedKmh,
        'routePoints': _routePoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'createdAt': Timestamp.now(),
      });
      // Keep only latest 10 runs
      final oldRuns = await FirebaseFirestore.instance
          .collection('runs')
          .where('uid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      if (oldRuns.docs.length > 10) {
        for (final doc in oldRuns.docs.skip(10)) {
          await doc.reference.delete();
        }
      }

      // Award XP atomically (matches completeQuest's transaction pattern).
      // Reads the LATEST Firestore xp/level, applies the reward, and writes
      // atomically so concurrent rewards (step, mission, penalty) cannot be lost.
      final ref = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};
        int curXp = (data['xp'] ?? 0) as int;
        int curLevel = (data['level'] ?? 1) as int;
        curXp += _xpEarned;
        while (curXp >= 500) { curXp -= 500; curLevel++; }
        txn.update(ref, {'xp': curXp, 'level': curLevel});
      });

      if (mounted) {
        setState(() {
          _routePoints.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Run saved! +$_xpEarned XP earned!")),
        );
      }
      return true;
    } catch (e) {
      debugPrint("saveRun: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save your run. Please try again.")),
        );
      }
      return false;
    } finally {
      _isSavingRun = false;
    }
  }

  // ── Share Run Dialog ──────────────────────────────────────
  Future<void> _showShareRunDialog({
    required List<LatLng> route,
    required double distanceKm,
    required int durationSeconds,
    required double speedKmh,
    required double calories,
    required int xpEarned,
    required String timerDisplay,
  }) async {
    if (!mounted || route.length < 2) return;

    // Fetch hunter name for the share card.
    String hunterName = 'Hunter';
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .get();
        hunterName = (doc.data()?['hunterName'] ?? 'Hunter').toString();
      }
    } catch (_) {}

    if (!mounted) return;

    final shouldShare = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HunterTheme.primary.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: HunterTheme.primary.withOpacity(0.15), blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HunterTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: HunterTheme.primary.withOpacity(0.4)),
                ),
                child: Icon(Icons.share_rounded, color: HunterTheme.primary, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                '🏃 Share Your Run?',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Show your progress to friends and fellow hunters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HunterTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Not Now',
                    style: TextStyle(color: HunterTheme.textTertiary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldShare != true || !mounted) return;

    // Generate the share image. Sharing is optional — failures must never
    // affect the already-successful run save.
    try {
      final controller = ScreenshotController();
      final bytes = await controller.captureFromWidget(
        _RunShareCard(
          route: route,
          hunterName: hunterName,
          distanceKm: distanceKm,
          timerDisplay: timerDisplay,
          speedKmh: speedKmh,
          calories: calories,
          xpEarned: xpEarned,
        ),
        context: context,
        pixelRatio: 3.0,
        // 2 seconds allows map tiles to load on typical connections.
        // FlutterMap does not expose a "tiles loaded" callback, so a
        // generous fixed delay is the only reliable approach. The dark
        // card background ensures the image still looks premium even if
        // a tile partially fails to load on very slow connections.
        delay: const Duration(milliseconds: 2000),
      );

      // Guard against blank/empty capture.
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to generate the share image. Please try again.')),
          );
        }
        return;
      }

      final dir = await Directory.systemTemp.createTemp('hunter_run');
      final file = File('${dir.path}/hunter_ascend_run.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🏃 I just ran ${distanceKm.toStringAsFixed(2)} km in $timerDisplay!\n'
            '🔥 ${calories.toStringAsFixed(0)} kcal burned • ⚡ +$xpEarned XP\n\n'
            'Track your runs on Hunter Ascend — Level Up Your Real Life\n'
            'https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend',
      );
    } catch (e) {
      debugPrint('shareRun: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to generate the share image. Please try again.')),
        );
      }
    }
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: RichText(text: TextSpan(children: [
          TextSpan(text: "HUNTER ", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
          TextSpan(text: "MAP", style: TextStyle(color: _blue, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ])),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
            child: Row(children: [
              _tabBtn("🗺️ MAP", 0),
              _tabBtn("📋 HISTORY", 1),
            ]),
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildMapTab() : _buildHistoryTab(),
    );
  }

  Widget _tabBtn(String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : HunterTheme.textTertiary, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  // ── Map Tab ───────────────────────────────────────────────
  Widget _buildMapTab() {
    return Column(children: [
      // Map
      Expanded(
        child: _currentPosition == null
            ? Center(child: CircularProgressIndicator(color: _blue))
            : FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition!,
            initialZoom: 16,
          ),
          children: [
            // OpenStreetMap tiles - completely free!
            TileLayer(
              urlTemplate: 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_nolabels/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.hunterascend.hunter_ascend',
              additionalOptions: const {
                'subdomains': 'abcd',
              },
            ),
// Labels layer on top
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.hunterascend.hunter_ascend',
            ),

            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints,
                  strokeWidth: 5,
                  color: HunterTheme.primary,
                ),
              ],
            ),

// Current position marker
            if (_currentPosition != null)
              MarkerLayer(markers: [
                Marker(
                  point: _currentPosition!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: _blue.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: Icon(Icons.navigation, color: HunterTheme.textPrimary, size: 20),
                  ),
                ),
              ]),
          ],
        ),
      ),

      // Stats bar
      if (_isTracking)
        Container(
          padding: const EdgeInsets.all(16),
          color: _card,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _liveStatItem("⏱️", _timerDisplay, "TIME"),
              _liveStatItem("📍", "${_distanceKm.toStringAsFixed(2)}", "KM"),
              _liveStatItem("💨", "${_speedKmh.toStringAsFixed(1)}", "KM/H"),
              _liveStatItem("🔥", "${_caloriesBurned.toStringAsFixed(0)}", "KCAL"),
              _liveStatItem("⚡", "+$_xpEarned", "XP"),
            ]),
          ]),
        ),

      // Controls
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _bg, border: Border(top: BorderSide(color: _border))),
        child: _isTracking
            ? Row(children: [
          // Pause
          Expanded(
            child: GestureDetector(
              onTap: _pauseTracking,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(_isPaused ? "RESUME" : "PAUSE", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Stop
          Expanded(
            child: GestureDetector(
              onTap: _stopTracking,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.stop, color: Colors.redAccent),
                  SizedBox(width: 6),
                  Text("STOP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        ])
            : GestureDetector(
          onTap: _startTracking,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _blue.withOpacity(0.4), blurRadius: 20)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.play_arrow, color: HunterTheme.textPrimary, size: 24),
              SizedBox(width: 8),
              Text("START RUN", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _liveStatItem(String emoji, String value, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10)),
    ]);
  }

  // ── Banner ad widget ──────────────────────────────────────
  Widget _buildBannerAd() {
    if (_bannerAd == null || !_isBannerLoaded) {
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  // ── History Tab ───────────────────────────────────────────
  Widget _buildHistoryTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text("Not logged in", style: TextStyle(color: HunterTheme.textPrimary)));

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _runsHistoryStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _blue));

              final runs = snapshot.data!.docs;

              if (runs.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.map_outlined, color: _blue, size: 60),
                    const SizedBox(height: 16),
                    Text("No runs yet!", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Start your first run to see history", style: TextStyle(color: HunterTheme.textTertiary)),
                  ]),
                );
              }

              // Total stats
              double totalKm = 0;
              double totalCal = 0;
              int totalXp = 0;
              for (final run in runs) {
                final data = run.data() as Map<String, dynamic>;
                totalKm += (data['distanceKm'] ?? 0).toDouble();
                totalCal += (data['caloriesBurned'] ?? 0).toDouble();
                totalXp += (data['xpEarned'] ?? 0) as int;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Total stats card
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                      boxShadow: [BoxShadow(color: _blue.withOpacity(0.1), blurRadius: 16)],
                    ),
                    child: Column(children: [
                      Text("📊 ALL TIME STATS", style: TextStyle(color: _blue, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _statBox("📍 TOTAL", "${totalKm.toStringAsFixed(1)} km", _blue),
                        const SizedBox(width: 8),
                        _statBox("🔥 CALORIES", "${totalCal.toStringAsFixed(0)} kcal", Colors.redAccent),
                        const SizedBox(width: 8),
                        _statBox("⚡ TOTAL XP", "+$totalXp XP", HunterTheme.success),
                      ]),
                    ]),
                  ),

                  // Run list
                  ...runs.map((run) {
                    final data = run.data() as Map<String, dynamic>;
                    final date = (data['createdAt'] as Timestamp).toDate();
                    final km = (data['distanceKm'] ?? 0).toStringAsFixed(2);
                    final cal = (data['caloriesBurned'] ?? 0).toStringAsFixed(0);
                    final xp = data['xpEarned'] ?? 0;
                    final speed = (data['avgSpeedKmh'] ?? 0).toStringAsFixed(1);
                    final dur = data['durationSeconds'] ?? 0;
                    final durMin = (dur ~/ 60).toString().padLeft(2, '0');
                    final durSec = (dur % 60).toString().padLeft(2, '0');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.directions_run, color: _blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "${date.day}/${date.month}/${date.year}",
                            style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: HunterTheme.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text("+$xp XP", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _runStat("📍", "$km km"),
                          _runStat("⏱️", "$durMin:$durSec"),
                          _runStat("💨", "$speed km/h"),
                          _runStat("🔥", "$cal kcal"),
                        ]),
                      ]),
                    );
                  }),
                ],
              );
            },
          ),
        ),

        // Banner ad pinned at the bottom of the history tab
        _buildBannerAd(),
      ],
    );
  }

  Widget _runStat(String emoji, String value) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}



// ══════════════════════════════════════════════════════════════════════════════
// RUN SHARE CARD — off-screen widget captured as a PNG for sharing
// ══════════════════════════════════════════════════════════════════════════════

/// A premium dark share card with an actual FlutterMap showing the run route,
/// plus stats in a bottom panel. Rendered off-screen by ScreenshotController.
class _RunShareCard extends StatelessWidget {
  const _RunShareCard({
    required this.route,
    required this.hunterName,
    required this.distanceKm,
    required this.timerDisplay,
    required this.speedKmh,
    required this.calories,
    required this.xpEarned,
  });

  final List<LatLng> route;
  final String hunterName;
  final double distanceKm;
  final String timerDisplay;
  final double speedKmh;
  final double calories;
  final int xpEarned;

  /// Fixed card width (captured at 3x → ~1290px).
  static const double _cardWidth = 430;
  static const double _cardHeight = 640;

  // Fixed dark palette for the share image (theme-independent).
  static const _bg = Color(0xFF0C1017);
  static const _surface = Color(0xFF141A24);
  static const _accent = Color(0xFFFF7A3D);
  static const _accentBright = Color(0xFFFF9E5C);
  static const _gold = Color(0xFFFFD54A);
  static const _textPrimary = Color(0xFFF5F6F8);
  static const _textSecondary = Color(0xFFC2C8D2);
  static const _textTertiary = Color(0xFF808895);

  /// Computes a bounding box for the route with padding, then returns a
  /// center LatLng and a zoom level that fits the route within the given
  /// pixel dimensions.
  MapOptions _fitRoute(double width, double height) {
    if (route.isEmpty) {
      return MapOptions(initialCenter: const LatLng(0, 0), initialZoom: 2);
    }
    if (route.length == 1) {
      return MapOptions(
        initialCenter: route.first,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: 0),
      );
    }

    double minLat = route.first.latitude;
    double maxLat = route.first.latitude;
    double minLng = route.first.longitude;
    double maxLng = route.first.longitude;

    for (final p in route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Add 40% padding so route edges don't touch the card border and
    // start/finish markers are always fully visible.
    final latDiff = math.max((maxLat - minLat) * 1.4, 0.001);
    final lngDiff = math.max((maxLng - minLng) * 1.4, 0.001);

    // At zoom 0 the Mercator projection maps 360° onto 256px.
    // Each zoom level doubles the resolution. Solve for the zoom that
    // fits the padded bounding box into the available pixel area.
    final latZoom = math.log(height / 256 * 360 / latDiff) / math.ln2;
    final lngZoom = math.log(width / 256 * 360 / lngDiff) / math.ln2;
    final zoom = math.min(latZoom, lngZoom).clamp(2.0, 17.0);

    return MapOptions(
      initialCenter: center,
      initialZoom: zoom,
      interactionOptions: const InteractionOptions(flags: 0), // no gestures
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = _cardHeight * 0.65;
    final mapOptions = _fitRoute(_cardWidth, mapHeight);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _cardWidth,
          height: _cardHeight,
          color: _bg,
          child: Column(
            children: [
              // ── Map section (top ~65%) ──
              SizedBox(
                width: _cardWidth,
                height: mapHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: FlutterMap(
                    options: mapOptions,
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.hunterascend.hunter_ascend',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route,
                            strokeWidth: 4,
                            color: _accent,
                          ),
                        ],
                      ),
                      // Start marker
                      if (route.isNotEmpty)
                        MarkerLayer(markers: [
                          Marker(
                            point: route.first,
                            width: 14,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          if (route.length > 1)
                            Marker(
                              point: route.last,
                              width: 14,
                              height: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ]),
                    ],
                  ),
                ),
              ),

              // ── Stats section (bottom ~35%) ──
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hunter name row
                      Row(
                        children: [
                          Icon(Icons.directions_run_rounded,
                              color: _accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hunterName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Stats grid
                      Row(
                        children: [
                          _stat('DISTANCE', '${distanceKm.toStringAsFixed(2)} km', _accent),
                          _stat('DURATION', timerDisplay, _accentBright),
                          _stat('SPEED', '${speedKmh.toStringAsFixed(1)} km/h', _textPrimary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _stat('CALORIES', '${calories.toStringAsFixed(0)} kcal', _textPrimary),
                          _stat('XP EARNED', '+$xpEarned', _gold),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const Spacer(),
                      // Footer
                      Row(
                        children: [
                          Text(
                            'HUNTER ASCEND',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Level Up Your Real Life',
                            style: TextStyle(
                              color: _textTertiary,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
