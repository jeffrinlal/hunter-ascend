import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
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
import 'package:hunter_ascend/services/xp_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
import 'package:hunter_ascend/services/feature_unlock_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
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
  static Color get _blue => MembershipTheme.current.accent;
  static Color get _border => HunterTheme.border;
  
  // ── Access check ──────────────────────────────────────────
  bool _isCheckingAccess = true;
  bool _isUnlocked = false;
  
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

  // ── GPS health / watchdog ─────────────────────────────────
  // Root-cause fix: distance/speed/calories/XP all derive exclusively from
  // _distanceKm, which is only ever updated inside the position-stream
  // listener below. If that stream stalls (weak signal, indoor start,
  // provider throttling) every one of those stats silently freezes while
  // the independent elapsed-time Timer keeps ticking — exactly the reported
  // bug. These fields let the UI detect and surface that condition instead
  // of failing silently.
  Timer? _gpsWatchdogTimer;
  DateTime? _lastPositionAt;
  bool _isAcquiringGps = false;
  bool _gpsSignalWeak = false;
  static const Duration _gpsStaleThreshold = Duration(seconds: 15);

  // TEMP DEBUG LOGGING (remove before release): counts how many times the
  // Geolocator position-stream callback has actually been invoked this run,
  // independent of any filter outcome. This is read-only diagnostic state —
  // it is never used in any conditional/business-logic branch, only printed.
  int _positionCallbackCount = 0;

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
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final unlocked = await FeatureUnlockService.instance.isMapUnlocked();
    if (!mounted) return;

    if (!unlocked) {
      // Not unlocked - go back immediately
      Navigator.of(context).pop();
      // Show message after navigation completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Map is locked. Watch an ad to unlock!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      return;
    }

    setState(() {
      _isUnlocked = true;
      _isCheckingAccess = false;
    });
    
    // Defer initialization until after build completes
    // (MapController needs to be attached to FlutterMap widget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getCurrentLocation();
        _loadBannerAd();
      }
    });
  }

  @override
  void dispose() {
    // TEMP DEBUG LOGGING — covers the case where the screen is closed/
    // navigated away from mid-run (neither Pause, Resume, nor Stop was
    // pressed), so the timeline doesn't silently end.
    debugPrint('[RunTrack][STATE] dispose() entered. '
        '_isTracking=$_isTracking, _isPaused=$_isPaused, '
        'distanceKm=$_distanceKm, positionStreamWasActive=${_positionStream != null}');
    _positionStream?.cancel();
    _positionStream = null;
    debugPrint('[RunTrack][STATE] Position stream cancelled (from dispose()).');
    _timer?.cancel();
    _timer = null;
    _gpsWatchdogTimer?.cancel();
    _gpsWatchdogTimer = null;
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
  //
  // TEMP DEBUG LOGGING (remove before release): every debugPrint tagged
  // '[RunTrack]' below instruments one stage of the Start Run -> Finish Run
  // pipeline per the requested audit. They are purely additive (no behavior
  // change) and safe to strip once the fix is confirmed on a real device.
  Future<void> _startTracking() async {
    // TEMP DEBUG LOGGING — logs every call to _startTracking(), including
    // calls the guard below rejects (e.g. a double-tap while already
    // tracking), so the timeline shows entry regardless of outcome.
    debugPrint('[RunTrack][STATE] _startTracking() entered. currentIsTracking=$_isTracking');
    if (_isTracking) {
      debugPrint('[RunTrack][STATE] _startTracking() aborted by guard — already tracking.');
      return;
    }
    debugPrint('[RunTrack] STAGE 1: Start Run pressed.');

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

    if (!mounted) return;

    // TEMP DEBUG LOGGING — state values immediately before this setState
    // flips them, so the transition (old -> new) is visible in the log.
    debugPrint('[RunTrack][STATE] Before start setState: '
        '_isTracking=$_isTracking, _isPaused=$_isPaused, _distanceKm=$_distanceKm');
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _routePoints = [];
      _elapsedSeconds = 0;
      _distanceKm = 0;
      _isAcquiringGps = true;
      _gpsSignalWeak = false;
      _lastPositionAt = null;
      _positionCallbackCount = 0; // TEMP DEBUG LOGGING — reset per run.
    });
    // TEMP DEBUG LOGGING — confirms the transition landed.
    debugPrint('[RunTrack][STATE] After start setState: '
        '_isTracking=$_isTracking (false->true), _isPaused=$_isPaused (->false), '
        '_distanceKm=$_distanceKm (reset to 0)');

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });

    // GPS watchdog — this is the diagnostic counterpart to the root-cause
    // fix. It does NOT change how distance is computed; it only detects
    // when the position stream has stopped delivering fixes (the exact
    // failure mode that previously froze distance/speed/calories/XP with
    // no visible explanation) and surfaces that to the user instead of
    // letting the run silently record nothing.
    _gpsWatchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_isTracking || _isPaused) return;
      final last = _lastPositionAt;
      final stale = last == null || DateTime.now().difference(last) > _gpsStaleThreshold;
      if (stale != _gpsSignalWeak) {
        setState(() => _gpsSignalWeak = stale);
      }
    });

    // GPS Stream — Android requires AndroidSettings with intervalDuration
    // for reliable position updates. The generic LocationSettings doesn't
    // work properly on Android for continuous tracking.
    final LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        // Note: foregroundNotificationConfig removed as this app doesn't
        // use background location tracking (tracking stops when screen closes)
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    debugPrint('[RunTrack] STAGE 2: Subscribing to position stream. settings=$locationSettings');

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
          (position) {
        if (!mounted) return;
        // TEMP DEBUG LOGGING — runs before the STAGE 3a counter increments,
        // so (_positionCallbackCount == 0) here means this is the very
        // first position callback invocation since _startTracking().
        if (_positionCallbackCount == 0) {
          debugPrint('[RunTrack][STATE] First position of this run received '
              'by the listener (about to process it below).');
        }
        // TEMP DEBUG LOGGING — proves the Geolocator stream callback is
        // actually being invoked at all, independent of any filter outcome.
        // This answers "is the callback firing?" with a hard counter rather
        // than inferring it from downstream state.
        _positionCallbackCount++;
        debugPrint('[RunTrack] STAGE 3a: Position-stream callback invoked. '
            'callbackCount=$_positionCallbackCount');

        // TEMP DEBUG LOGGING — every raw Position the stream delivers.
        debugPrint('[RunTrack] STAGE 3: Position received — '
            'lat=${position.latitude}, lng=${position.longitude}, '
            'accuracy=${position.accuracy}m, timestamp=${position.timestamp}');

        // Reject positions with poor accuracy (large GPS error radius) so a
        // noisy/low-quality fix can't be recorded as real movement — but
        // still count it as "a fix was received" for watchdog purposes so
        // the UI doesn't report "no signal" while fixes are in fact arriving.
        _lastPositionAt = DateTime.now();
        const maxAcceptableAccuracyMeters = 30.0;
        final hasUsableAccuracy = !position.accuracy.isNaN && position.accuracy <= maxAcceptableAccuracyMeters;

        // TEMP DEBUG LOGGING — explicit accuracy-filter verdict, logged
        // unconditionally and before any other filter runs.
        debugPrint('[RunTrack] STAGE 3b: Accuracy filter — '
            'accuracy=${position.accuracy}m, threshold=${maxAcceptableAccuracyMeters}m, '
            'isNaN=${position.accuracy.isNaN}, passes=$hasUsableAccuracy');

        final newPoint = LatLng(position.latitude, position.longitude);

        // TEMP DEBUG LOGGING — raw distance from the last route point,
        // computed and logged unconditionally (even if a filter above would
        // otherwise reject this point first) so the actual GPS-reported
        // movement between fixes is always visible, not just the movement
        // for points that happened to pass every other filter.
        if (_routePoints.isNotEmpty) {
          final rawDistanceKm = const Distance()
              .as(LengthUnit.Kilometer, _routePoints.last, newPoint);
          debugPrint('[RunTrack] STAGE 3c: Raw distance from last route point '
              '(pre-filter) = ${rawDistanceKm.toStringAsFixed(6)} km '
              '(${(rawDistanceKm * 1000).toStringAsFixed(2)} m), '
              'lastPoint=${_routePoints.last}, newPoint=$newPoint');
        } else {
          debugPrint('[RunTrack] STAGE 3c: Raw distance from last route point '
              '(pre-filter) = N/A (_routePoints is empty — this will be the '
              'first point)');
        }

        double? addedDistance;
        String filterReason = 'accepted';
        String rejectionCategory = 'none';
        if (!hasUsableAccuracy) {
          filterReason = 'filtered out — accuracy ${position.accuracy}m exceeds ${maxAcceptableAccuracyMeters}m threshold';
          rejectionCategory = 'poor_accuracy';
        } else if (_isPaused) {
          filterReason = 'filtered out — run is paused';
          rejectionCategory = 'paused';
        } else if (_routePoints.isEmpty) {
          filterReason = 'accepted (first point — no prior point to measure distance from)';
          rejectionCategory = 'none (first point)';
        } else {
          final lastPoint = _routePoints.last;
          final distance = const Distance().as(LengthUnit.Kilometer, lastPoint, newPoint);
          // Ignore unrealistic GPS jumps so a sudden spike can't inflate distance.
          if (distance > 0 && distance < 0.1) {
            addedDistance = distance;
            filterReason = 'accepted — +${distance.toStringAsFixed(5)} km';
            rejectionCategory = 'none';
          } else if (distance <= 0) {
            // TEMP DEBUG LOGGING — distinguishes "exactly zero/negative
            // distance" from "jump filter" rejection, which the original
            // single `else` branch did not separate.
            filterReason = 'filtered out — zero/non-positive distance (${distance.toStringAsFixed(8)} km between points)';
            rejectionCategory = 'zero_distance';
          } else {
            filterReason = 'filtered out — implausible jump (${distance.toStringAsFixed(5)} km between points)';
            rejectionCategory = 'jump_filter';
          }
        }
        // TEMP DEBUG LOGGING — accept/reject decision for this position,
        // plus the specific rejection category (poor_accuracy / paused /
        // zero_distance / jump_filter / none).
        debugPrint('[RunTrack] STAGE 4: Position $filterReason '
            '[rejectionCategory=$rejectionCategory]');
        // TEMP DEBUG LOGGING — distance contributed by this position (if any).
        debugPrint('[RunTrack] STAGE 5: Distance added from this point = ${addedDistance ?? 0} km');

        // TEMP DEBUG LOGGING — capture _distanceKm immediately before the
        // mutation below so the before/after can be compared and logged
        // without altering the mutation itself.
        final double distanceKmBeforeUpdate = _distanceKm;

        setState(() {
          _isAcquiringGps = false;
          _gpsSignalWeak = false;
          _currentPosition = newPoint;
          if (addedDistance != null) _distanceKm += addedDistance;
          if (hasUsableAccuracy && !_isPaused) _routePoints.add(newPoint);
        });

        // TEMP DEBUG LOGGING — explicitly states whether _distanceKm changed
        // as a result of this position update, and if not, why (mirrors the
        // same rejectionCategory computed above for STAGE 4).
        if (_distanceKm != distanceKmBeforeUpdate) {
          debugPrint('[RunTrack][STATE] _distanceKm CHANGED: '
              '$distanceKmBeforeUpdate -> $_distanceKm '
              '(delta=${(_distanceKm - distanceKmBeforeUpdate).toStringAsFixed(6)} km)');
        } else {
          debugPrint('[RunTrack][STATE] _distanceKm UNCHANGED at $_distanceKm '
              'despite receiving a position update '
              '[reason=$rejectionCategory]');
        }

        // TEMP DEBUG LOGGING — running total after this update.
        debugPrint('[RunTrack] STAGE 6: Total distance after update = $_distanceKm km '
            '(routePoints=${_routePoints.length})');
        // TEMP DEBUG LOGGING — confirms setState (UI refresh) ran for this update.
        debugPrint('[RunTrack] STAGE 7: UI refreshed via setState — '
            'currentPosition=$_currentPosition, distanceKm=$_distanceKm, speedKmh=$_speedKmh, '
            'calories=$_caloriesBurned, xp=$_xpEarned');

        try {
          _mapController.move(newPoint, _mapController.camera.zoom);
        } catch (_) {}
      },
      onError: (error) {
        debugPrint('[RunTrack] Position stream onError fired: $error');
        debugPrint("GPS stream error: $error");
        // Stop tracking safely on stream error (e.g., permission revoked mid-run).
        _positionStream?.cancel();
        _positionStream = null;
        // TEMP DEBUG LOGGING — position stream cancellation from the error path.
        debugPrint('[RunTrack][STATE] Position stream cancelled (from onError handler).');
        _timer?.cancel();
        _timer = null;
        _gpsWatchdogTimer?.cancel();
        _gpsWatchdogTimer = null;
        if (mounted) {
          // TEMP DEBUG LOGGING — state before/after the error-path reset.
          debugPrint('[RunTrack][STATE] Before error-path setState: '
              '_isTracking=$_isTracking, _isPaused=$_isPaused');
          setState(() {
            _isTracking = false;
            _isPaused = false;
          });
          debugPrint('[RunTrack][STATE] After error-path setState: '
              '_isTracking=$_isTracking (->false), _isPaused=$_isPaused (->false)');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location tracking stopped due to an error.")),
          );
        }
      },
    );
  }

  void _pauseTracking() {
    // TEMP DEBUG LOGGING — logs whether this tap is a "Pause" or "Resume"
    // action (determined from the state BEFORE the toggle below), without
    // changing the toggle expression itself.
    final bool wasPaused = _isPaused;
    debugPrint('[RunTrack][STATE] ${wasPaused ? "Resume" : "Pause"} pressed. '
        '_isPaused before=$wasPaused, distanceKm=$_distanceKm, '
        'routePoints=${_routePoints.length}');
    setState(() => _isPaused = !_isPaused);
    debugPrint('[RunTrack][STATE] _isPaused changed: $wasPaused -> $_isPaused');
  }

  Future<void> _stopTracking() async {
    // TEMP DEBUG LOGGING — logs entry into _stopTracking() with the state
    // as it stood right before cancellation, so the timeline shows exactly
    // what was accumulated at the moment Stop was pressed.
    debugPrint('[RunTrack][STATE] Stop pressed. _stopTracking() entered. '
        '_isTracking=$_isTracking, _isPaused=$_isPaused, '
        'distanceKm=$_distanceKm, routePoints=${_routePoints.length}, '
        'positionStreamWasActive=${_positionStream != null}');

    _positionStream?.cancel();
    _positionStream = null;
    debugPrint('[RunTrack][STATE] Position stream cancelled (from _stopTracking()).');
    _timer?.cancel();
    _timer = null;
    _gpsWatchdogTimer?.cancel();
    _gpsWatchdogTimer = null;

    // TEMP DEBUG LOGGING — STAGE 8: full snapshot at Finish Run.
    debugPrint('[RunTrack] STAGE 8: Finish Run — '
        'elapsedSeconds=$_elapsedSeconds, distanceKm=$_distanceKm, '
        'speedKmh=$_speedKmh, calories=$_caloriesBurned, xp=$_xpEarned, '
        'routePoints=${_routePoints.length}');

    if (_distanceKm < 0.01) {
      // TEMP DEBUG LOGGING — exact reason "Run too short" is triggered.
      debugPrint('[RunTrack] STAGE 8: "Run too short" triggered — '
          'distanceKm=$_distanceKm is below the 0.01 km threshold '
          '(routePoints=${_routePoints.length})');
      // TEMP DEBUG LOGGING — state before the short-run reset.
      debugPrint('[RunTrack][STATE] Before short-run setState: '
          '_isTracking=$_isTracking, _isPaused=$_isPaused');
      setState(() {
        _isTracking = false;
        _isPaused = false;
        _isAcquiringGps = false;
        _gpsSignalWeak = false;
      });
      // TEMP DEBUG LOGGING — state after the short-run reset.
      debugPrint('[RunTrack][STATE] After short-run setState: '
          '_isTracking=$_isTracking (->false), _isPaused=$_isPaused (->false)');
      // Distinguish "you didn't move" from "GPS never produced a usable fix"
      // so a stalled GPS stream is no longer misreported as a short run —
      // this is diagnostic only; the actual fix is the tuned platform
      // location settings + accuracy filtering above, which makes this
      // branch far less likely to trigger for genuine runs.
      final message = _routePoints.length < 2
          ? "No GPS movement was recorded. Check your location signal and try again 📡"
          : "Too short to save! Keep running 🏃";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [HunterTheme.gold.withOpacity(0.22), HunterTheme.gold.withOpacity(0.08)],
                    ),
                    border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: HunterTheme.gold.withOpacity(0.25), blurRadius: 16)],
                  ),
                  child: Icon(Icons.emoji_events_rounded, color: HunterTheme.gold, size: 28),
                ),
                const SizedBox(height: 14),
                Text("RUN COMPLETE!", style: TextStyle(color: HunterTheme.gold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 24),

                // Stats grid
                Row(children: [
                  _statBox("DISTANCE", "${_distanceKm.toStringAsFixed(2)} km", _blue),
                  const SizedBox(width: 10),
                  _statBox("TIME", _timerDisplay, HunterTheme.gold),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _statBox("CALORIES", "${_caloriesBurned.toStringAsFixed(0)} kcal", HunterTheme.danger),
                  const SizedBox(width: 10),
                  _statBox("XP EARNED", "+$_xpEarned XP", HunterTheme.success),
                ]),
                const SizedBox(height: 10),
                _statBox("AVG SPEED", "${_speedKmh.toStringAsFixed(1)} km/h", HunterTheme.purple),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
                        // TEMP DEBUG LOGGING — final _isTracking/_isPaused
                        // reset after a successful save.
                        debugPrint('[RunTrack][STATE] Before SAVE RUN setState: '
                            '_isTracking=$_isTracking, _isPaused=$_isPaused');
                        setState(() { _isTracking = false; _isPaused = false; });
                        debugPrint('[RunTrack][STATE] After SAVE RUN setState: '
                            '_isTracking=$_isTracking (->false), _isPaused=$_isPaused (->false)');
                      } else {
                        setDialogState(() => isSaving = false);
                      }
                    },
                    child: isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                        : const Text("SAVE RUN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
                  ),
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: isSaving ? null : () {
                    Navigator.pop(dialogContext);
                    // TEMP DEBUG LOGGING — _isTracking/_isPaused reset on
                    // Discard (run summary dismissed without saving).
                    debugPrint('[RunTrack][STATE] Before DISCARD setState: '
                        '_isTracking=$_isTracking, _isPaused=$_isPaused');
                    setState(() { _isTracking = false; _isPaused = false; });
                    debugPrint('[RunTrack][STATE] After DISCARD setState: '
                        '_isTracking=$_isTracking (->false), _isPaused=$_isPaused (->false)');
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

      // Award XP via centralized service (handles daily/weekly XP tracking).
      await XpService.instance.awardXp(amount: _xpEarned);

      // Update cumulative run stats (backs the walking/explorer
      // achievements: walk_5/25/100/500, explore_first/10/100/longest).
      // longestRunKm needs a max(), not a plain increment, so this is done
      // via a transaction rather than FieldValue.increment.
      final hunterRef = FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      try {
        await FirebaseFirestore.instance.runTransaction((txn) async {
          final snap = await txn.get(hunterRef);
          final data = snap.data() ?? {};
          final curTotalRuns = ((data['totalRunsCompleted'] ?? 0) as num).toInt();
          final curTotalKm = ((data['totalRunDistanceKm'] ?? 0) as num).toDouble();
          final curLongest = ((data['longestRunKm'] ?? 0) as num).toDouble();
          txn.update(hunterRef, {
            'totalRunsCompleted': curTotalRuns + 1,
            'totalRunDistanceKm': curTotalKm + _distanceKm,
            'longestRunKm': _distanceKm > curLongest ? _distanceKm : curLongest,
          });
        });
      } catch (e) {
        debugPrint('saveRun cumulative stats: $e');
      }

      if (mounted) {
        setState(() {
          _routePoints.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Run saved! +$_xpEarned XP earned!")),
        );
        // Immediately re-evaluate/celebrate any achievement this run just
        // satisfied — walk_*/explore_* plus any XP/level-driven ones.
        await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
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

    // Fetch hunter name + avatar for the share card (same doc, no extra query).
    String hunterName = 'Hunter';
    String? profilePicture;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .get();
        hunterName = (doc.data()?['hunterName'] ?? 'Hunter').toString();
        final pic = doc.data()?['profilePicture'];
        if (pic is String && pic.isNotEmpty) profilePicture = pic;
      }
    } catch (_) {}

    // Presentation-only date label for the share image.
    final now = DateTime.now();
    const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateLabel = '${_months[now.month - 1]} ${now.day}, ${now.year}';

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
            border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.15), blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MembershipTheme.current.accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.4)),
                ),
                child: Icon(Icons.share_rounded, color: MembershipTheme.current.accent, size: 32),
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MembershipTheme.current.accent,
                    foregroundColor: MembershipTheme.isMax ? Colors.white : Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5)),
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
          profilePicture: profilePicture,
          dateLabel: dateLabel,
          distanceKm: distanceKm,
          timerDisplay: timerDisplay,
          durationSeconds: durationSeconds,
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

      // Record that the hunter has shared a run/activity card (backs the
      // "Share Activity" achievement) and immediately re-evaluate/celebrate.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({'hasSharedActivity': true});
        } catch (e) {
          debugPrint('shareRun hasSharedActivity write: $e');
        }
        if (mounted) {
          await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
        }
      }
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.14), HunterTheme.cardColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ]),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Check access before showing content
    if (_isCheckingAccess) {
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isUnlocked) {
      // Safety fallback (shouldn't be reached due to pop in _checkAccess)
      return Scaffold(
        backgroundColor: _bg,
        body: const Center(
          child: Text('Access Denied'),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: RichText(text: TextSpan(children: [
          TextSpan(text: "HUNTER ", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
          TextSpan(text: "MAP", style: TextStyle(color: _blue, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ])),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(children: [
              _tabBtn(Icons.map_rounded, "MAP", 0),
              _tabBtn(Icons.timeline_rounded, "HISTORY", 1),
            ]),
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildMapTab() : _buildHistoryTab(),
    );
  }

  Widget _tabBtn(IconData icon, String label, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: MembershipTheme.current.gradient,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: _blue.withOpacity(0.35 * HunterTheme.glowStrength), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.black : HunterTheme.textTertiary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : HunterTheme.textTertiary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_blue.withOpacity(0.16), _card],
                        ),
                        border: Border.all(color: _blue.withOpacity(0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Locating you...',
                        style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
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
                  color: MembershipTheme.current.accent,
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
                    child: const Icon(Icons.navigation_rounded, color: Colors.black, size: 20),
                  ),
                ),
              ]),
          ],
        ),
      ),

      // GPS status banner — surfaces the exact failure mode from the root-
      // cause analysis (position stream stalled/no fix yet) instead of
      // letting distance/speed/calories/XP freeze with no explanation.
      if (_isTracking && (_isAcquiringGps || _gpsSignalWeak))
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          color: HunterTheme.gold.withOpacity(0.14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2, color: HunterTheme.gold),
            ),
            const SizedBox(width: 8),
            Text(
              _isAcquiringGps ? "Acquiring GPS signal..." : "Weak GPS signal — distance may pause",
              style: TextStyle(color: HunterTheme.gold, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ]),
        ),

      // Live stats bar
      if (_isTracking)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_blue.withOpacity(0.06), _card],
            ),
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _liveStatItem(Icons.timer_outlined, _timerDisplay, "TIME"),
            _liveStatItem(Icons.route_rounded, _distanceKm.toStringAsFixed(2), "KM"),
            _liveStatItem(Icons.speed_rounded, _speedKmh.toStringAsFixed(1), "KM/H"),
            _liveStatItem(Icons.local_fire_department_rounded, _caloriesBurned.toStringAsFixed(0), "KCAL"),
            _liveStatItem(Icons.bolt_rounded, "+$_xpEarned", "XP"),
          ]),
        ),

      // Controls
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _bg, border: Border(top: BorderSide(color: _border))),
          child: _isTracking
              ? Row(children: [
            // Pause
            Expanded(
              child: GestureDetector(
                onTap: _pauseTracking,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: HunterTheme.gold.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: HunterTheme.gold),
                    const SizedBox(width: 6),
                    Text(_isPaused ? "RESUME" : "PAUSE", style: TextStyle(color: HunterTheme.gold, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: HunterTheme.danger.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HunterTheme.danger.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.stop_rounded, color: HunterTheme.danger),
                    const SizedBox(width: 6),
                    Text("STOP", style: TextStyle(color: HunterTheme.danger, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ),
          ])
              : GestureDetector(
            onTap: _startTracking,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: MembershipTheme.current.gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _blue.withOpacity(0.4 * HunterTheme.glowStrength), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                SizedBox(width: 8),
                Text("START RUN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _liveStatItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: _blue, size: 18),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
              if (!snapshot.hasData) {
                return Center(
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_blue.withOpacity(0.16), _card],
                      ),
                      border: Border.all(color: _blue.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final runs = snapshot.data!.docs;

              if (runs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_blue.withOpacity(0.16), _card],
                          ),
                          border: Border.all(color: _blue.withOpacity(0.3), width: 1.4),
                          boxShadow: [
                            BoxShadow(color: _blue.withOpacity(0.14 * HunterTheme.glowStrength), blurRadius: 24),
                          ],
                        ),
                        child: Icon(Icons.directions_run_rounded, color: _blue, size: 42),
                      ),
                      const SizedBox(height: 22),
                      Text("No runs yet", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text("Start your first run to build your history", textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4)),
                    ]),
                  ),
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
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_blue.withOpacity(0.08), _card],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(HunterTheme.isDark ? 0.2 : 0.04), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.insights_rounded, color: _blue, size: 16),
                        const SizedBox(width: 8),
                        Text("ALL-TIME STATS", style: TextStyle(color: _blue, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        _statBox("TOTAL", "${totalKm.toStringAsFixed(1)} km", _blue),
                        const SizedBox(width: 8),
                        _statBox("CALORIES", "${totalCal.toStringAsFixed(0)} kcal", HunterTheme.danger),
                        const SizedBox(width: 8),
                        _statBox("TOTAL XP", "+$totalXp XP", HunterTheme.success),
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
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_blue.withOpacity(0.05), _card],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(HunterTheme.isDark ? 0.15 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_blue.withOpacity(0.18), _blue.withOpacity(0.06)],
                              ),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _blue.withOpacity(0.25)),
                            ),
                            child: Icon(Icons.directions_run_rounded, color: _blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "${date.day}/${date.month}/${date.year}",
                              style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: HunterTheme.success.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: HunterTheme.success.withOpacity(0.3)),
                            ),
                            child: Text("+$xp XP", style: TextStyle(color: HunterTheme.success, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _runStat(Icons.route_rounded, "$km km"),
                          _runStat(Icons.timer_outlined, "$durMin:$durSec"),
                          _runStat(Icons.speed_rounded, "$speed km/h"),
                          _runStat(Icons.local_fire_department_rounded, "$cal kcal"),
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

  Widget _runStat(IconData icon, String value) {
    return Column(children: [
      Icon(icon, color: _blue, size: 17),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
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
    required this.dateLabel,
    required this.distanceKm,
    required this.timerDisplay,
    required this.durationSeconds,
    required this.speedKmh,
    required this.calories,
    required this.xpEarned,
    this.profilePicture,
  });

  final List<LatLng> route;
  final String hunterName;
  final String? profilePicture;
  final String dateLabel;
  final double distanceKm;
  final String timerDisplay;
  final int durationSeconds;
  final double speedKmh;
  final double calories;
  final int xpEarned;

  /// Fixed card width (captured at 3x → ~1290px).
  static const double _cardWidth = 430;
  static const double _cardHeight = 660;

  // Fixed dark palette for the share image (theme-independent).
  static const _bg = Color(0xFF0C1017);
  static const _surface = Color(0xFF141A24);
  static const _accent = Color(0xFFFF7A3D);
  static const _accentBright = Color(0xFFFF9E5C);
  static const _gold = Color(0xFFFFD54A);
  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFF5F6F8);
  static const _textSecondary = Color(0xFFC2C8D2);
  static const _textTertiary = Color(0xFF808895);

  /// Display-only average pace (min/km) derived from distance + duration.
  String get _paceLabel {
    if (distanceKm <= 0 || durationSeconds <= 0) return '--';
    final secPerKm = durationSeconds / distanceKm;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round().clamp(0, 59);
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

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
    final mapHeight = _cardHeight * 0.60;
    final mapOptions = _fitRoute(_cardWidth, mapHeight);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _cardWidth,
          height: _cardHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_surface, _bg],
            ),
          ),
          child: Column(
            children: [
              // ── Map hero (route preview + overlays) ──
              SizedBox(
                width: _cardWidth,
                height: mapHeight,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FlutterMap(
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
                                strokeWidth: 5,
                                color: _accent,
                                borderStrokeWidth: 2,
                                borderColor: Colors.white.withOpacity(0.85),
                              ),
                            ],
                          ),
                          if (route.isNotEmpty)
                            MarkerLayer(markers: [
                              Marker(
                                point: route.first,
                                width: 16,
                                height: 16,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                  ),
                                ),
                              ),
                              if (route.length > 1)
                                Marker(
                                  point: route.last,
                                  width: 16,
                                  height: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                  ),
                                ),
                            ]),
                        ],
                      ),
                      // Top scrim + hunter chip.
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16, left: 18, right: 18,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _accent, width: 2),
                              ),
                              child: ClipOval(
                                child: profilePicture != null
                                    ? Image.memory(base64Decode(profilePicture!), fit: BoxFit.cover)
                                    : Container(color: _surface, child: const Icon(Icons.person, color: _accentBright, size: 22)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hunterName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    dateLabel,
                                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.directions_run_rounded, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                      // Bottom scrim + big distance hero.
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                distanceKm.toStringAsFixed(2),
                                style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.0),
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text('KM', style: TextStyle(color: _accentBright, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats + branding ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _stat('DURATION', timerDisplay, _textPrimary),
                          _statDivider(),
                          _stat('PACE', '$_paceLabel/km', _accentBright),
                          _statDivider(),
                          _stat('CALORIES', calories.toStringAsFixed(0), _textPrimary),
                          _statDivider(),
                          _stat('XP', '+$xpEarned', _gold),
                        ],
                      ),
                      const Spacer(),
                      Container(height: 1, color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 14),
                      // Branding footer.
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [_accent, _gold],
                              ),
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'HUNTER ASCEND',
                                  style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                                ),
                                Text(
                                  'Level Up Your Real Life',
                                  style: TextStyle(color: _accentBright.withOpacity(0.9), fontSize: 10.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: _green, size: 15),
                                SizedBox(width: 5),
                                Text('Get the app', style: TextStyle(color: _textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
                              ],
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

  Widget _statDivider() => Container(width: 1, height: 30, color: Colors.white.withOpacity(0.08));

  Widget _stat(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: valueColor, fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: _textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}
