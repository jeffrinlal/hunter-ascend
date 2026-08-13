import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Status values for a `step_clashes/{battleId}` document.
class StepClashStatus {
  StepClashStatus._();
  static const String waiting = 'waiting';
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

/// Outcome from one participant's perspective.
enum StepClashOutcome { win, draw, loss, forfeited }

/// Which card state the Battle Hub should render.
enum StepClashCardState { none, incoming, waiting, active, resultAvailable }

/// Immutable read-only view of a `step_clashes/{battleId}` document.
@immutable
class StepClashData {
  const StepClashData({required this.id, required this.raw});

  factory StepClashData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) =>
      StepClashData(id: snap.id, raw: snap.data() ?? const {});

  final String id;
  final Map<String, dynamic> raw;

  List<String> get participants =>
      (raw['participants'] as List?)?.whereType<String>().toList() ??
      const [];

  Map<String, String> get participantNames {
    final m = raw['participantNames'];
    if (m is! Map) return const {};
    return m.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  int get goalSteps => (raw['goalSteps'] as num?)?.toInt() ?? 0;
  int get durationMinutes => (raw['durationMinutes'] as num?)?.toInt() ?? 0;
  String get status => (raw['status'] as String?) ?? '';
  String get creatorUid => (raw['creatorUid'] as String?) ?? '';

  List<String> get pendingInvitees =>
      (raw['pendingInvitees'] as List?)?.whereType<String>().toList() ??
      const [];

  DateTime? get startAt => (raw['startAt'] as Timestamp?)?.toDate();
  DateTime? get completedAt => (raw['completedAt'] as Timestamp?)?.toDate();
  DateTime? get createdAt => (raw['createdAt'] as Timestamp?)?.toDate();

  String? get winner => raw['winner'] as String?;

  List<String> get forfeited =>
      (raw['forfeited'] as List?)?.whereType<String>().toList() ?? const [];

  Map<String, int> get progress => _intMap(raw['progress']);
  Map<String, int> get startSnapshot => _intMap(raw['startSnapshot']);
  Map<String, bool> get xpAwarded => _boolMap(raw['xpAwarded']);

  // ── Derived ─────────────────────────────────────────────────────────

  DateTime? get endAt {
    final s = startAt;
    if (s == null) return null;
    return s.add(Duration(minutes: durationMinutes));
  }

  bool get hasExpired {
    final e = endAt;
    if (e == null) return false;
    return DateTime.now().isAfter(e);
  }

  Duration get timeRemaining {
    final e = endAt;
    if (e == null) return Duration.zero;
    final diff = e.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool isParticipant(String uid) => participants.contains(uid);
  bool isForfeited(String uid) => forfeited.contains(uid);

  int progressFor(String uid) => progress[uid] ?? 0;

  /// Sorted list of (uid, steps) excluding forfeited, descending by steps.
  List<(String uid, int steps)> get ranking {
    final entries = <(String, int)>[];
    for (final uid in participants) {
      if (!forfeited.contains(uid)) {
        entries.add((uid, progress[uid] ?? 0));
      }
    }
    entries.sort((a, b) => b.$2.compareTo(a.$2));
    return entries;
  }

  StepClashOutcome? outcomeFor(String uid) {
    if (status != StepClashStatus.completed) return null;
    if (forfeited.contains(uid)) return StepClashOutcome.forfeited;
    final w = winner;
    if (w == null) return null;
    if (w.isEmpty) return StepClashOutcome.draw;
    return w == uid ? StepClashOutcome.win : StepClashOutcome.loss;
  }

  String nameFor(String uid) => participantNames[uid] ?? 'Unknown';

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    final out = <String, int>{};
    value.forEach((k, v) {
      if (k is String && v is num) out[k] = v.toInt();
    });
    return out;
  }

  static Map<String, bool> _boolMap(Object? value) {
    if (value is! Map) return const {};
    final out = <String, bool>{};
    value.forEach((k, v) {
      if (k is String && v is bool) out[k] = v;
    });
    return out;
  }
}

/// Result of a Step Clash action.
@immutable
class StepClashActionResult {
  const StepClashActionResult.success([this.clash])
      : ok = true,
        message = null;
  const StepClashActionResult.failure(this.message)
      : ok = false,
        clash = null;

  final bool ok;
  final String? message;
  final StepClashData? clash;
}

/// All Firestore access for the Step Clash feature.
///
/// Every write path is isolated to its own method so security rules can
/// whitelist exact field sets per transition.
class StepClashService {
  StepClashService._();
  static final StepClashService instance = StepClashService._();

  static const String _collection = 'step_clashes';

  /// XP reward for the winner.
  static const int winnerXpReward = 30;

  /// Allowed step goals.
  static const List<int> allowedGoals = [10000, 25000, 50000, 100000];

  /// Allowed durations in minutes.
  static const List<int> allowedDurations = [30, 60, 120];

  /// Sync interval for progress updates (time-based trigger).
  /// Progress also syncs when the step delta since last sync exceeds
  /// [syncStepThreshold], whichever comes first.
  static const Duration syncInterval = Duration(seconds: 30);

  /// Step delta threshold that triggers an early sync before the time
  /// interval elapses. Keeps the battle feeling live during active walking
  /// without writing every single pedometer event.
  static const int syncStepThreshold = 300;

  CollectionReference<Map<String, dynamic>> get _clashes =>
      FirebaseFirestore.instance.collection(_collection);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ══════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════

  /// Live stream of incoming invites (for badge).
  Stream<QuerySnapshot<Map<String, dynamic>>> incomingInviteStream(
    String uid,
  ) {
    return _clashes
        .where('pendingInvitees', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.waiting)
        .limit(1)
        .snapshots();
  }

  /// The user's current active or waiting-for-them Step Clash.
  Future<StepClashData?> fetchActive(String uid) async {
    // Active battle this user is in.
    final active = await _clashes
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.active)
        .limit(1)
        .get();
    if (active.docs.isNotEmpty) {
      return StepClashData.fromSnapshot(active.docs.first);
    }

    // Waiting battle this user created or accepted.
    final waiting = await _clashes
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.waiting)
        .limit(1)
        .get();
    if (waiting.docs.isNotEmpty) {
      return StepClashData.fromSnapshot(waiting.docs.first);
    }

    // Completed battle with result not yet viewed (xpAwarded.uid == false).
    final completed = await _clashes
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.completed)
        .limit(5)
        .get();
    for (final doc in completed.docs) {
      final data = StepClashData.fromSnapshot(doc);
      if (data.xpAwarded[uid] != true && !data.isForfeited(uid)) {
        return data;
      }
    }

    return null;
  }

  /// Re-reads a single battle by ID.
  Future<StepClashData?> fetchById(String id) async {
    final snap = await _clashes.doc(id).get();
    if (!snap.exists) return null;
    return StepClashData.fromSnapshot(snap);
  }

  /// Resolves which card state to show on the Battle Hub.
  static StepClashCardState cardStateFor(
    StepClashData? clash,
    String uid, {
    bool hasIncomingInvite = false,
  }) {
    if (hasIncomingInvite) return StepClashCardState.incoming;
    if (clash == null) return StepClashCardState.none;
    if (!clash.isParticipant(uid)) return StepClashCardState.none;
    switch (clash.status) {
      case StepClashStatus.waiting:
        return StepClashCardState.waiting;
      case StepClashStatus.active:
        return clash.hasExpired
            ? StepClashCardState.resultAvailable
            : StepClashCardState.active;
      case StepClashStatus.completed:
        return (clash.xpAwarded[uid] != true && !clash.isForfeited(uid))
            ? StepClashCardState.resultAvailable
            : StepClashCardState.none;
      default:
        return StepClashCardState.none;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // CREATE
  // ══════════════════════════════════════════════════════════════════════

  /// Creates a new Step Clash and invites [inviteeUids].
  Future<StepClashActionResult> create({
    required List<String> inviteeUids,
    required Map<String, String> inviteeNames,
    required int goalSteps,
    required int durationMinutes,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const StepClashActionResult.failure('You must be signed in.');
    }
    if (inviteeUids.isEmpty || inviteeUids.length > 4) {
      return const StepClashActionResult.failure(
        'Invite 1 to 4 other Hunters.',
      );
    }
    if (inviteeUids.contains(uid)) {
      return const StepClashActionResult.failure(
        'You cannot invite yourself.',
      );
    }

    final myName =
        HunterRepository.instance.getCached()?.hunterName ?? 'Unknown';

    final allParticipants = <String>[uid, ...inviteeUids]..sort();
    final names = <String, String>{uid: myName, ...inviteeNames};

    final xpAwardedMap = <String, bool>{};
    for (final p in allParticipants) {
      xpAwardedMap[p] = false;
    }

    try {
      final ref = await _clashes.add(<String, dynamic>{
        'participants': allParticipants,
        'participantNames': names,
        'goalSteps': goalSteps,
        'durationMinutes': durationMinutes,
        'status': StepClashStatus.waiting,
        'creatorUid': uid,
        'pendingInvitees': inviteeUids,
        'progress': <String, int>{},
        'startSnapshot': <String, int>{},
        'winner': null,
        'forfeited': <String>[],
        'xpAwarded': xpAwardedMap,
        'startAt': null,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return StepClashActionResult.success(await fetchById(ref.id));
    } on FirebaseException catch (e) {
      debugPrint('StepClashService.create: ${e.code} ${e.message}');
      return StepClashActionResult.failure(_msg(e));
    } catch (e) {
      debugPrint('StepClashService.create: $e');
      return const StepClashActionResult.failure(
        'Could not create the Step Clash.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACCEPT
  // ══════════════════════════════════════════════════════════════════════

  /// Accepts an incoming invite. If all invitees have accepted, starts the
  /// battle (`status → active`, `startAt = serverTimestamp`).
  Future<StepClashActionResult> accept(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) {
      return const StepClashActionResult.failure('You must be signed in.');
    }
    if (!clash.pendingInvitees.contains(uid)) {
      return const StepClashActionResult.failure(
        'You are not invited to this battle.',
      );
    }

    try {
      final ref = _clashes.doc(clash.id);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = StepClashData.fromSnapshot(snap);
        if (current.status != StepClashStatus.waiting) return;
        if (!current.pendingInvitees.contains(uid)) return;

        final updatedPending =
            current.pendingInvitees.where((u) => u != uid).toList();

        final updates = <String, dynamic>{
          'pendingInvitees': updatedPending,
        };

        // If this was the last invitee, start the battle.
        if (updatedPending.isEmpty) {
          updates['status'] = StepClashStatus.active;
          updates['startAt'] = FieldValue.serverTimestamp();
        }

        txn.update(ref, updates);
      });

      return StepClashActionResult.success(await fetchById(clash.id));
    } on FirebaseException catch (e) {
      debugPrint('StepClashService.accept: ${e.code} ${e.message}');
      return StepClashActionResult.failure(_msg(e));
    } catch (e) {
      debugPrint('StepClashService.accept: $e');
      return const StepClashActionResult.failure(
        'Could not accept the invite.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DECLINE / CANCEL
  // ══════════════════════════════════════════════════════════════════════

  /// Declines an invite (removes self from pending; cancels if nobody left).
  Future<StepClashActionResult> decline(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) {
      return const StepClashActionResult.failure('You must be signed in.');
    }

    try {
      final ref = _clashes.doc(clash.id);
      final updatedPending =
          clash.pendingInvitees.where((u) => u != uid).toList();
      final updatedParticipants =
          clash.participants.where((u) => u != uid).toList();

      // If declining leaves no invitees and only the creator, cancel.
      if (updatedParticipants.length <= 1) {
        await ref.update({'status': StepClashStatus.cancelled});
      } else {
        await ref.update({
          'pendingInvitees': updatedPending,
          'participants': updatedParticipants,
        });
      }
      return const StepClashActionResult.success();
    } catch (e) {
      debugPrint('StepClashService.decline: $e');
      return const StepClashActionResult.failure(
        'Could not decline the invite.',
      );
    }
  }

  /// Creator cancels a waiting battle.
  Future<StepClashActionResult> cancel(StepClashData clash) async {
    final uid = _uid;
    if (uid == null || clash.creatorUid != uid) {
      return const StepClashActionResult.failure('Only the creator can cancel.');
    }
    if (clash.status != StepClashStatus.waiting) {
      return const StepClashActionResult.failure(
        'This battle can no longer be cancelled.',
      );
    }
    try {
      await _clashes.doc(clash.id).update({
        'status': StepClashStatus.cancelled,
      });
      return const StepClashActionResult.success();
    } catch (e) {
      debugPrint('StepClashService.cancel: $e');
      return const StepClashActionResult.failure('Could not cancel.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // PROGRESS SYNC
  // ══════════════════════════════════════════════════════════════════════

  /// Syncs this participant's step progress to Firestore.
  ///
  /// [rawPedometerNow] is the current cumulative pedometer value.
  /// [startPedometer] is the value captured at battle start.
  /// Steps = rawPedometerNow - startPedometer (clamped at goal).
  Future<void> syncProgress(
    StepClashData clash, {
    required int rawPedometerNow,
    required int startPedometer,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    if (clash.status != StepClashStatus.active) return;
    if (clash.isForfeited(uid)) return;

    final steps =
        (rawPedometerNow - startPedometer).clamp(0, clash.goalSteps);

    try {
      final updates = <String, dynamic>{
        'progress.$uid': steps,
      };
      // Write-once snapshot if not yet stored.
      if (clash.startSnapshot[uid] == null) {
        updates['startSnapshot.$uid'] = startPedometer;
      }
      await _clashes.doc(clash.id).update(updates);
    } catch (e) {
      debugPrint('StepClashService.syncProgress: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FINALIZE (exactly-once winner determination)
  // ══════════════════════════════════════════════════════════════════════

  /// Determines the winner and freezes the result.
  ///
  /// Called when:
  /// - A participant reaches the goal (early win)
  /// - The timer expires
  ///
  /// Transaction asserts `status == 'active'` so only one device ever
  /// commits the result.
  Future<StepClashData?> finalize(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) return null;
    if (clash.status == StepClashStatus.completed) return clash;
    if (clash.status != StepClashStatus.active) return null;

    try {
      final ref = _clashes.doc(clash.id);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = StepClashData.fromSnapshot(snap);
        if (current.status != StepClashStatus.active) return;
        if (current.winner != null) return; // already finalized

        // Determine winner: highest non-forfeited progress.
        final ranking = current.ranking;
        if (ranking.isEmpty) {
          txn.update(ref, {
            'status': StepClashStatus.completed,
            'winner': '',
            'completedAt': FieldValue.serverTimestamp(),
          });
          return;
        }

        final topSteps = ranking.first.$2;
        final topPlayers =
            ranking.where((e) => e.$2 == topSteps).toList();

        final String winner;
        if (topPlayers.length > 1) {
          winner = ''; // draw
        } else {
          winner = topPlayers.first.$1;
        }

        txn.update(ref, {
          'status': StepClashStatus.completed,
          'winner': winner,
          'completedAt': FieldValue.serverTimestamp(),
        });
      });

      return await fetchById(clash.id);
    } catch (e) {
      debugPrint('StepClashService.finalize: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // FORFEIT
  // ══════════════════════════════════════════════════════════════════════

  /// Marks this participant as forfeited.
  ///
  /// If only one non-forfeited participant remains, auto-finalizes.
  Future<StepClashActionResult> forfeit(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) {
      return const StepClashActionResult.failure('You must be signed in.');
    }
    if (!clash.isParticipant(uid)) {
      return const StepClashActionResult.failure('Not your battle.');
    }
    if (clash.isForfeited(uid)) {
      return const StepClashActionResult.failure('Already forfeited.');
    }

    try {
      await _clashes.doc(clash.id).update({
        'forfeited': FieldValue.arrayUnion([uid]),
      });

      // Check if only one player left → auto-finalize.
      final refreshed = await fetchById(clash.id);
      if (refreshed != null && refreshed.status == StepClashStatus.active) {
        final remaining = refreshed.participants
            .where((p) => !refreshed.forfeited.contains(p))
            .toList();
        if (remaining.length <= 1) {
          await finalize(refreshed);
        }
      }

      return StepClashActionResult.success(await fetchById(clash.id));
    } catch (e) {
      debugPrint('StepClashService.forfeit: $e');
      return const StepClashActionResult.failure('Could not forfeit.');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // XP CLAIM (winner only, exactly-once)
  // ══════════════════════════════════════════════════════════════════════

  /// Claims the winner's XP reward. Write-once, no rollback.
  Future<bool> claimXp(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) return false;
    if (clash.status != StepClashStatus.completed) return false;
    if (clash.winner != uid) return false;
    if (clash.xpAwarded[uid] == true) return false;

    final ref = _clashes.doc(clash.id);
    var claimed = false;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = StepClashData.fromSnapshot(snap);
        if (current.status != StepClashStatus.completed) return;
        if (current.winner != uid) return;
        if (current.xpAwarded[uid] == true) return;

        txn.update(ref, {'xpAwarded.$uid': true});
        claimed = true;
      });
    } catch (e) {
      debugPrint('StepClashService.claimXp gate: $e');
      return false;
    }

    if (!claimed) return false;

    // Grant XP through existing service (own doc only).
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final result =
            await XpService.instance.awardXp(amount: winnerXpReward);
        if (result != null) return true;
      } catch (e) {
        debugPrint('StepClashService.claimXp grant $attempt: $e');
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
    return true; // Claimed but grant may have failed — write-once, no rollback.
  }

  /// Marks this participant's result as acknowledged (losers/draw/forfeited).
  Future<void> acknowledge(StepClashData clash) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _clashes.doc(clash.id).update({'xpAwarded.$uid': true});
    } catch (e) {
      debugPrint('StepClashService.acknowledge: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACCOUNT DELETION
  // ══════════════════════════════════════════════════════════════════════

  /// Releases all step clashes involving [uid] for account deletion.
  Future<void> releaseForDeletion(String uid) async {
    final waiting = await _clashes
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.waiting)
        .get();
    for (final doc in waiting.docs) {
      try {
        await doc.reference.update({'status': StepClashStatus.cancelled});
      } catch (_) {}
    }

    final active = await _clashes
        .where('participants', arrayContains: uid)
        .where('status', isEqualTo: StepClashStatus.active)
        .get();
    for (final doc in active.docs) {
      try {
        await doc.reference.update({
          'forfeited': FieldValue.arrayUnion([uid]),
        });
      } catch (_) {}
    }
  }

  String _msg(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Step Clash is not enabled yet.';
    }
    if (e.code == 'unavailable') {
      return 'Internet connection required.';
    }
    return 'Something went wrong. Please try again.';
  }
}
