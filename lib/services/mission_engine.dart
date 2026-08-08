import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Shared mission execution engine — the ONE implementation of the app's
/// mission lifecycle:
///
/// * start (duration selection reward ladder + Firestore persistence),
/// * 1-second countdown ticking [remaining] down to zero,
/// * completion detection ([isReady] when the timer hits zero),
/// * cancel / clear, and
/// * restore across app restarts and screen rebuilds.
///
/// The Missions screen runs two engines (daily + weekly) and Dungeons
/// delegate their execution to a third instead of duplicating any of this
/// — dungeons only provide metadata, AI objectives, theme and rewards.
///
/// Each engine owns its own Firestore slot on the hunter document
/// ([titleField] / [xpField] / [endTimeField]), so runs from different
/// surfaces never collide.
class MissionEngine extends ChangeNotifier {
  MissionEngine({
    required this.titleField,
    required this.xpField,
    required this.endTimeField,
    this.rewardMultiplier = 1,
  });

  /// Firestore field names holding the active run on the hunter doc.
  final String titleField;
  final String xpField;
  final String endTimeField;

  /// Scales the duration-based reward (weekly missions pay 3x daily).
  final int rewardMultiplier;

  String? _title;
  int _reward = 0;
  DateTime? _endTime;
  Duration _remaining = Duration.zero;
  Timer? _ticker;

  String? get title => _title;
  int get reward => _reward;
  Duration get remaining => _remaining;
  bool get isActive => _title != null;

  /// Completion detection — the countdown hit zero, so the run is ready
  /// for the Hunter Verification + reward flow.
  bool get isReady => isActive && _remaining == Duration.zero;

  /// The duration-based reward ladder used since the first mission flow:
  /// longer missions pay more.
  static int rewardForMinutes(int minutes) {
    if (minutes >= 60) return 50;
    if (minutes >= 45) return 40;
    if (minutes >= 30) return 30;
    if (minutes >= 15) return 20;
    if (minutes >= 10) return 15;
    if (minutes >= 5) return 10;
    return 5;
  }

  /// Starts a run for [minutes] and persists it so it survives navigation
  /// and app restarts (see [restore]).
  Future<void> start({required String title, required int minutes}) async {
    final endTime = DateTime.now().add(Duration(minutes: minutes));
    _title = title;
    _reward = rewardForMinutes(minutes) * rewardMultiplier;
    _endTime = endTime;
    _remaining = Duration(minutes: minutes);
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('hunters').doc(user.uid).update({
        titleField: title,
        xpField: _reward,
        endTimeField: Timestamp.fromDate(endTime),
      });
    }
    _startTicker();
  }

  /// Ends the run and clears the Firestore slot — used for BOTH cancel and
  /// completion (the caller reads [title] / [reward] first, then awards).
  Future<void> clearRun() async {
    _ticker?.cancel();
    _ticker = null;
    _title = null;
    _reward = 0;
    _endTime = null;
    _remaining = Duration.zero;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({
        titleField: FieldValue.delete(),
        xpField: FieldValue.delete(),
        endTimeField: FieldValue.delete(),
      });
    }
  }

  /// Resumes an in-progress run from Firestore (app restart, screen
  /// rebuild, navigating back into the surface).
  Future<void> restore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final name = data[titleField];
    if (name == null) return;
    final endTime = (data[endTimeField] as Timestamp?)?.toDate();

    _title = name.toString();
    _reward = (data[xpField] as num?)?.toInt() ?? 0;
    _endTime = endTime;
    _remaining = endTime == null
        ? Duration.zero
        : (endTime.isBefore(DateTime.now())
            ? Duration.zero
            : endTime.difference(DateTime.now()));
    notifyListeners();

    if (endTime != null && endTime.isAfter(DateTime.now())) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final end = _endTime;
      if (end == null) return;
      final diff = end.difference(DateTime.now());
      _remaining = diff.isNegative ? Duration.zero : diff;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
