import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ads_service.dart';

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

  // ── Tracking ─────────────────────────────────────────────
  bool _isTracking = false;
  bool _isPaused = false;
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
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
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ── Banner Ad loading ───────────────────────────────────
  void _loadBannerAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-5435480116436845/6580125873'
    // TODO: Replace with your real iOS banner ad unit ID for production
        : 'ca-app-pub-3940256099942544/2934735716';

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

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    try {
      _mapController.move(_currentPosition!, 16);
    } catch (_) {}
  }

  // ── Tracking ─────────────────────────────────────────────
  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _routePoints = [];
      _elapsedSeconds = 0;
      _distanceKm = 0;
    });

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });

    // GPS Stream
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((position) {
      final newPoint = LatLng(position.latitude, position.longitude);

      if (_routePoints.isNotEmpty && !_isPaused) {
        final lastPoint = _routePoints.last;
        final distance = const Distance().as(LengthUnit.Kilometer, lastPoint, newPoint);
        setState(() => _distanceKm += distance);
      }

      setState(() {
        _currentPosition = newPoint;
        if (!_isPaused) _routePoints.add(newPoint);
      });

      try {
        _mapController.move(newPoint, _mapController.camera.zoom);
      } catch (_) {}
    });
  }

  void _pauseTracking() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopTracking() async {
    _positionStream?.cancel();
    _timer?.cancel();

    if (_distanceKm < 0.01) {
      setState(() { _isTracking = false; _isPaused = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Too short to save! Keep running 🏃")));
      return;
    }

    // Show summary
    await _showRunSummary();
  }

  Future<void> _showRunSummary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveRun();
                    setState(() { _isTracking = false; _isPaused = false; });
                  },
                  child: Text("SAVE RUN ⚡", style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() { _isTracking = false; _isPaused = false; });
                },
                child: Text("DISCARD", style: TextStyle(color: HunterTheme.textTertiary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRun() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

    // Award XP
    final doc = await FirebaseFirestore.instance.collection('hunters').doc(user.uid).get();
    final data = doc.data() ?? {};
    final currentXp = data['xp'] ?? 0;
    int newXp = currentXp + _xpEarned;
    int newLevel = data['level'] ?? 1;
    if (newXp >= 500) { newLevel++; newXp -= 500; }

    await FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
      'xp': newXp,
      'level': newLevel,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Run saved! +$_xpEarned XP earned!")),
      );
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
            stream: FirebaseFirestore.instance
                .collection('runs')
                .where('uid', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
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