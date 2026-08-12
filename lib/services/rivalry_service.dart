import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Canonical `status` values for a `rivalries/{pairId}` document.
///
/// Only these five values are ever persisted. Every other conceptual state
/// (request expired, result available, settled, time remaining, end date) is
/// DERIVED — see [RivalryData]. Nothing derivable is stored, so no stored
/// value can drift out of agreement with reality.
class RivalryStatus {
  RivalryStatus._();

  /// A request has been sent and not yet answered.
  static const String pending = 'pending';

  /// The request was accepted; the countdown is running.
  static const String active = 'active';

  /// The duration elapsed and the outcome has been computed and frozen.
  static const String completed = 'completed';

  /// The receiver rejected the request. Terminal.
  static const String declined = 'declined';

  /// A participant deleted their account mid-rivalry. Terminal, no outcome.
  static const String abandoned = 'abandoned';
}

/// The outcome of a completed rivalry from one participant's point of view.
enum RivalryOutcome { win, draw, loss }

/// Which Rivals card the Battle Hub should render.
///
/// Deliberately mirrors `_DuelCardState` in `battle_hub_screen.dart`: a small
/// closed enum resolved from data the hub already has, used to pick card copy
/// and a destination. It is not a new state system — every value is derived
/// from the single `rivalries` document that concerns this user.
enum RivalCardState {
  /// Nothing in flight — the "find a rival" entry point.
  none,

  /// Another hunter has challenged this user; awaiting accept/decline.
  incomingRequest,

  /// This user sent a request that has not been answered yet.
  requestSent,

  /// A rivalry is running and has not reached its end date.
  active,

  /// The rivalry ended (or is past its end date) and this user has not
  /// finished with the result yet.
  resultAvailable,

  /// The other participant deleted their account mid-rivalry.
  rivalLeft,
}

/// Immutable read-only view over a `rivalries/{pairId}` document.
///
/// Every getter is either a direct field read or a pure derivation. This type
/// performs no Firestore access whatsoever, so widgets can hold it, rebuild
/// against it and derive countdowns from it for free.
@immutable
class RivalryData {
  const RivalryData({required this.id, required this.raw});

  factory RivalryData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return RivalryData(id: snapshot.id, raw: snapshot.data() ?? const {});
  }

  /// The document id, which is always the deterministic pair id.
  final String id;
  final Map<String, dynamic> raw;

  // ── Stored fields ─────────────────────────────────────────────────────

  List<String> get participants =>
      (raw['participants'] as List?)?.whereType<String>().toList() ??
      const <String>[];

  /// The participants who have NOT yet finished with this rivalry. Each user
  /// removes only their own uid. Once a uid is gone the document stops
  /// matching that user's `array-contains` query, so it becomes invisible to
  /// them while remaining visible to the other participant.
  List<String> get unsettledFor =>
      (raw['unsettledFor'] as List?)?.whereType<String>().toList() ??
      const <String>[];

  String get fromUid => (raw['fromUid'] as String?) ?? '';
  String get toUid => (raw['toUid'] as String?) ?? '';
  String get fromHunterName => (raw['fromHunterName'] as String?) ?? 'Unknown';
  String get toHunterName => (raw['toHunterName'] as String?) ?? 'Unknown';
  int get durationDays => (raw['durationDays'] as num?)?.toInt() ?? 0;
  String get status => (raw['status'] as String?) ?? '';

  /// The winner's uid, or the empty string for a DRAW. `null` until the
  /// rivalry is finalized. The empty-string-means-draw convention is the same
  /// one the existing duel system uses.
  String? get winner => raw['winner'] as String?;

  bool get xpAwarded => raw['xpAwarded'] == true;

  DateTime? get createdAt => (raw['createdAt'] as Timestamp?)?.toDate();

  /// Server-stamped moment the receiver accepted. Absent while pending, which
  /// is exactly why time spent awaiting acceptance cannot count towards the
  /// duration.
  DateTime? get startAt => (raw['startAt'] as Timestamp?)?.toDate();

  DateTime? get completedAt => (raw['completedAt'] as Timestamp?)?.toDate();

  /// Total-XP snapshot per uid, taken at acceptance.
  Map<String, int> get startScore => _intMap(raw['startScore']);

  /// Total-XP snapshot per uid, taken at finalization.
  Map<String, int> get endScore => _intMap(raw['endScore']);

  // ── Derived: timing ───────────────────────────────────────────────────

  /// End instant, derived rather than stored, so it can never disagree with
  /// [startAt] + [durationDays].
  DateTime? get endAt {
    final start = startAt;
    if (start == null) return null;
    return start.add(Duration(days: durationDays));
  }

  /// True once the duration has elapsed. False while pending (no [startAt]).
  bool get hasExpired {
    final end = endAt;
    if (end == null) return false;
    return !DateTime.now().isBefore(end);
  }

  /// Time left, floored at zero. `null` while pending.
  Duration? get timeRemaining {
    final end = endAt;
    if (end == null) return null;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// A `pending` request older than [RivalryService.requestExpiryDays] is
  /// treated as expired. Derived from [createdAt] because no scheduler exists
  /// to write an `expired` status — storing it would guarantee it goes stale.
  bool get isRequestExpired {
    if (status != RivalryStatus.pending) return false;
    final created = createdAt;
    if (created == null) return false;
    return DateTime.now().difference(created).inDays >=
        RivalryService.requestExpiryDays;
  }

  // ── Derived: participants ─────────────────────────────────────────────

  /// The other participant's uid, or `''` if [myUid] is not a participant.
  String otherUidFor(String myUid) {
    for (final uid in participants) {
      if (uid != myUid) return uid;
    }
    return '';
  }

  /// Denormalised display name for [uid]. Never used for matching or
  /// authorisation — those always go through uids.
  String hunterNameFor(String uid) {
    if (uid == fromUid) return fromHunterName;
    if (uid == toUid) return toHunterName;
    return 'Unknown';
  }

  bool isParticipant(String uid) => participants.contains(uid);

  bool isUnsettledFor(String uid) => unsettledFor.contains(uid);

  // ── Derived: progress and outcome ─────────────────────────────────────

  /// Progress made during the rivalry, using the frozen [endScore]. Returns
  /// `null` until the rivalry is finalized.
  int? finalProgressFor(String uid) {
    final start = startScore[uid];
    final end = endScore[uid];
    if (start == null || end == null) return null;
    return end - start;
  }

  /// Progress so far for a still-running rivalry, given the hunter's CURRENT
  /// total XP. Never negative because total XP is monotonic.
  int liveProgressFor(String uid, int currentTotalXp) {
    final start = startScore[uid];
    if (start == null) return 0;
    final delta = currentTotalXp - start;
    return delta < 0 ? 0 : delta;
  }

  /// This user's outcome, or `null` if the rivalry is not completed.
  RivalryOutcome? outcomeFor(String uid) {
    if (status != RivalryStatus.completed) return null;
    final w = winner;
    if (w == null) return null;
    if (w.isEmpty) return RivalryOutcome.draw;
    return w == uid ? RivalryOutcome.win : RivalryOutcome.loss;
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const <String, int>{};
    final out = <String, int>{};
    value.forEach((key, v) {
      if (key is String && v is num) out[key] = v.toInt();
    });
    return out;
  }
}

/// Result of a mutating rivalry action.
@immutable
class RivalryActionResult {
  const RivalryActionResult.success([this.rivalry])
      : ok = true,
        message = null;

  const RivalryActionResult.failure(this.message)
      : ok = false,
        rivalry = null;

  final bool ok;

  /// User-facing reason the action was refused. Null on success.
  final String? message;

  /// The resulting document state, when the action produced one.
  final RivalryData? rivalry;
}

/// Result of the winner's exactly-once +50 XP claim.
@immutable
class RivalryXpResult {
  const RivalryXpResult({required this.granted, this.award});

  /// True only when THIS call is the one that granted the XP.
  final bool granted;

  /// The [XpAwardResult] from the shared [XpService], for level-up UI.
  final XpAwardResult? award;
}

/// All Firestore access for the time-limited Rivalry feature.
///
/// ## Why one service owns every write
/// The duel system keeps its transactions inline in `duel_screen.dart`, which
/// is how a cross-user write silently drifted out of agreement with the
/// security rules. Every rivalry read, write and transaction lives here
/// instead, so the complete set of write paths is auditable in one file.
///
/// ## Data model — a single document per pair
/// ```
/// rivalries/{pairId}          pairId = ([uidA, uidB]..sort()).join('_')
/// ```
/// The id is DETERMINISTIC, which makes a duplicate A-B rivalry structurally
/// impossible without a query, a lock or a transaction. That matters because
/// client Firestore transactions cannot run queries — they can only `get`
/// known references — so nothing else provides that guarantee client-side.
///
/// The same document is the request, the relationship and the frozen result.
///
/// ## Cost
/// * ZERO writes for the entire 3/7/14-day rivalry. State is snapshotted at
///   acceptance and read once at expiry; nothing is written in between.
/// * ZERO composite indexes. Both queries are index-free by construction:
///   two equality filters (served by single-field indexes, exactly like the
///   existing `duel_requests` queries, which have no entry in
///   `firestore.indexes.json`), or one bare `array-contains` (served by the
///   automatic single-field array index).
/// * ONE new permanent listener, for the nav badge. Firestore has no
///   cross-collection OR, so combining the duel and rival badges into one dot
///   requires one subscription each.
///
/// ## Writes are split per transition, on purpose
/// Every mutation below touches the smallest possible set of keys, so the
/// security rules can whitelist exact `affectedKeys()` per transition and
/// per actor. No method ever writes the whole document. The required rules
/// are documented in the implementation report, not applied here.
class RivalryService {
  RivalryService._();

  static final RivalryService instance = RivalryService._();

  /// The only rivalry durations the client will ever send.
  static const List<int> allowedDurations = <int>[3, 7, 14];

  /// A pending request older than this is treated as expired (derived, never
  /// stored — see [RivalryData.isRequestExpired]).
  static const int requestExpiryDays = 7;

  /// XP granted to the winner, exactly once. "maximum" in the product spec:
  /// a flat 50 regardless of duration.
  static const int winnerXpReward = 50;

  /// XP required per level, matching `XpService`'s level-up loop.
  static const int _xpPerLevel = 500;

  /// Attempts made to hand the winner's XP to [XpService] once the claim has
  /// been committed. See [claimWinnerXp] for why there is no rollback.
  static const int _xpGrantAttempts = 3;

  static const String _collection = 'rivalries';

  CollectionReference<Map<String, dynamic>> get _rivalries =>
      FirebaseFirestore.instance.collection(_collection);

  CollectionReference<Map<String, dynamic>> get _hunters =>
      FirebaseFirestore.instance.collection('hunters');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ══════════════════════════════════════════════════════════════════════
  // PURE HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Deterministic document id for a pair of hunters. Order-independent, so
  /// both users compute the same id and a second A-B document cannot exist.
  static String pairIdFor(String a, String b) => (<String>[a, b]..sort()).join('_');

  /// MONOTONIC total XP: `(level - 1) * 500 + xp`.
  ///
  /// The raw `xp` field must NEVER be compared directly. `XpService` runs
  /// `while (curXp >= 500) { curXp -= 500; curLevel++; }`, so `xp` is
  /// IN-LEVEL progress and wraps back towards zero on every level-up. A naive
  /// `endXp - startXp` therefore goes NEGATIVE for the player who progressed
  /// most (e.g. level 3 / 480xp to level 4 / 80xp is a real gain of 100 but
  /// reads as -400). Folding the level back in restores monotonicity, so the
  /// difference between two snapshots is always the true XP gained.
  ///
  /// This introduces no new field and no new tracking: `level` and `xp` are
  /// `HunterData` fields 2 and 1, the two oldest in the model.
  static int totalXpFrom(Map<String, dynamic>? hunter) {
    if (hunter == null) return 0;
    final level = (hunter['level'] as num?)?.toInt() ?? 1;
    final xp = (hunter['xp'] as num?)?.toInt() ?? 0;
    return (level - 1) * _xpPerLevel + xp;
  }

  /// True when [snapshot] contains a pending incoming request that has not
  /// aged out. Used by the nav badge and the Battle Hub so an abandoned
  /// request cannot leave a red dot on the tab forever.
  static bool hasLiveIncomingRequest(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return false;
    for (final doc in snapshot.docs) {
      if (!RivalryData.fromSnapshot(doc).isRequestExpired) return true;
    }
    return false;
  }

  /// The first live pending incoming request in [snapshot], if any.
  static RivalryData? liveIncomingRequest(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    if (snapshot == null) return null;
    for (final doc in snapshot.docs) {
      final data = RivalryData.fromSnapshot(doc);
      if (!data.isRequestExpired) return data;
    }
    return null;
  }

  /// Resolves which Rivals card to show. Pure function of the document and
  /// the viewing user, so the hub and the card can never disagree.
  static RivalCardState cardStateFor(RivalryData? rivalry, String myUid) {
    if (rivalry == null || !rivalry.isParticipant(myUid)) {
      return RivalCardState.none;
    }
    switch (rivalry.status) {
      case RivalryStatus.pending:
        if (rivalry.isRequestExpired) return RivalCardState.none;
        return rivalry.toUid == myUid
            ? RivalCardState.incomingRequest
            : RivalCardState.requestSent;
      case RivalryStatus.active:
        // Past its end date but not yet finalized: route to the result, which
        // finalizes on open. Same shape as the duel system's post-frame
        // `_autoCompleteDuel()` trigger.
        return rivalry.hasExpired
            ? RivalCardState.resultAvailable
            : RivalCardState.active;
      case RivalryStatus.completed:
        return rivalry.isUnsettledFor(myUid)
            ? RivalCardState.resultAvailable
            : RivalCardState.none;
      case RivalryStatus.abandoned:
        return rivalry.isUnsettledFor(myUid)
            ? RivalCardState.rivalLeft
            : RivalCardState.none;
      default:
        return RivalCardState.none;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════

  /// Live stream of incoming pending rival requests, for the nav badge.
  ///
  /// Two equality filters, `limit(1)` — the exact shape the existing
  /// `duel_requests` badge uses, which needs NO composite index. This is the
  /// feature's only permanent listener; it is created once in `MainShell` and
  /// shared with the Battle Hub so the badge and the card are driven by one
  /// subscription.
  Stream<QuerySnapshot<Map<String, dynamic>>> incomingRequestStream(
    String uid,
  ) {
    return _rivalries
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: RivalryStatus.pending)
        .limit(1)
        .snapshots();
  }

  /// The single rivalry that currently concerns [uid] — pending in either
  /// direction, active, or completed-but-not-finished-with.
  ///
  /// One bare `array-contains` with no other filter and no `orderBy`, so it is
  /// served by the automatic single-field array index: no composite index.
  /// Because each user removes their own uid when done, this returns exactly
  /// the document that still matters to them and never accumulates stale
  /// completed rivalries.
  ///
  /// A non-empty result is also the one-active-rivalry check.
  Future<RivalryData?> fetchCurrentRivalry(String uid) async {
    final snap = await _rivalries
        .where('unsettledFor', arrayContains: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return RivalryData.fromSnapshot(snap.docs.first);
  }

  /// The current rivalry of the OTHER hunter, used only for the "is this
  /// Hunter free?" pre-flight check.
  ///
  /// This is the one query that reads a document the caller is not a
  /// participant in, mirroring the existing duel flow, which freely queries an
  /// opponent's `duels` and `duel_requests` before creating a challenge.
  ///
  /// If the deployed rules restrict rivalry reads to participants only, this
  /// returns `null` instead of failing the whole operation: the check is a UX
  /// courtesy, and the binding guarantee lives elsewhere — each user's own
  /// one-rivalry check runs on both send and accept, so neither side can end
  /// up in two rivalries even when this lookup returns nothing.
  Future<RivalryData?> _fetchOtherPartyRivalry(String uid) async {
    try {
      return await fetchCurrentRivalry(uid);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Re-reads one rivalry by its pair id.
  Future<RivalryData?> fetchById(String pairId) async {
    final snap = await _rivalries.doc(pairId).get();
    if (!snap.exists) return null;
    return RivalryData.fromSnapshot(snap);
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 1 — SEND REQUEST  (sender only, create)
  // ══════════════════════════════════════════════════════════════════════

  /// Sends a rivalry request to [targetUid] for [durationDays].
  ///
  /// Writes: 1 create. Reads: 2 pre-checks (+1 when the sender's own hunter
  /// name is not already cached).
  Future<RivalryActionResult> sendRequest({
    required String targetUid,
    required String targetHunterName,
    required int durationDays,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return const RivalryActionResult.failure('You must be signed in.');
    }
    if (targetUid == uid) {
      return const RivalryActionResult.failure(
        'You cannot start a rivalry with yourself.',
      );
    }
    if (!allowedDurations.contains(durationDays)) {
      return const RivalryActionResult.failure('Choose a rivalry duration.');
    }

    try {
      // Is the sender free? A pending request they already sent occupies
      // their slot, so this also prevents spamming multiple targets.
      final mine = await fetchCurrentRivalry(uid);
      if (mine != null && !mine.isRequestExpired) {
        return RivalryActionResult.failure(_busyMessage(mine, uid));
      }

      // Is the target free? Mirrors the existing duel guard, which refuses
      // with "Hunter is already in a duel" / "already has a pending
      // challenge" before creating a duel request.
      final theirs = await _fetchOtherPartyRivalry(targetUid);
      if (theirs != null && !theirs.isRequestExpired) {
        return const RivalryActionResult.failure(
          'This Hunter is already in a Rivalry.',
        );
      }

      final pairId = pairIdFor(uid, targetUid);
      final ref = _rivalries.doc(pairId);

      // A settled rivalry with this same hunter still occupies the
      // deterministic id. Remove it so a fresh one can be created; the delete
      // rule only permits this when nobody is still unsettled.
      final existing = await ref.get();
      if (existing.exists) {
        final previous = RivalryData.fromSnapshot(existing);
        if (previous.unsettledFor.isNotEmpty && !previous.isRequestExpired) {
          return RivalryActionResult.failure(_busyMessage(previous, uid));
        }
        await ref.delete();
      }

      // Reuses the hunter document HunterRepository already keeps
      // live-cached rather than re-reading it — the same denormalisation the
      // duel request flow performs. This is a DISPLAY copy only; all matching
      // and authorisation goes through fromUid/toUid.
      String myHunterName =
          HunterRepository.instance.getCached()?.hunterName ?? '';
      if (myHunterName.isEmpty) {
        final me = await _hunters.doc(uid).get();
        myHunterName = (me.data()?['hunterName'] as String?) ?? 'Unknown';
      }

      // Written to a non-existent document, so the rules evaluate this as a
      // `create`. Every field the create rule validates is present, and no
      // outcome field is seeded.
      await ref.set(<String, dynamic>{
        'participants': <String>[uid, targetUid]..sort(),
        'unsettledFor': <String>[uid, targetUid]..sort(),
        'fromUid': uid,
        'toUid': targetUid,
        'fromHunterName': myHunterName,
        'toHunterName': targetHunterName,
        'durationDays': durationDays,
        'status': RivalryStatus.pending,
        'xpAwarded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return RivalryActionResult.success(await fetchById(pairId));
    } on FirebaseException catch (e) {
      debugPrint('RivalryService.sendRequest: ${e.code} ${e.message}');
      return RivalryActionResult.failure(_firebaseMessage(e));
    } catch (e) {
      debugPrint('RivalryService.sendRequest: $e');
      return const RivalryActionResult.failure(
        'Could not send the rivalry request. Please try again.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 2 — ACCEPT  (receiver only: status, startAt, startScore)
  // ══════════════════════════════════════════════════════════════════════

  /// Accepts an incoming request, starting the countdown.
  ///
  /// The countdown begins HERE, not at send time: `startAt` is written as a
  /// server timestamp during acceptance and does not exist before it, so time
  /// spent awaiting an answer is structurally excluded from the duration.
  ///
  /// Also snapshots both hunters' monotonic total XP into `startScore`. The
  /// receiver can read the sender's hunter document because hunter reads are
  /// open to any signed-in user — that permission is what makes the whole
  /// baseline-snapshot design possible without any cross-user writes.
  Future<RivalryActionResult> accept(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) {
      return const RivalryActionResult.failure('You must be signed in.');
    }
    if (rivalry.toUid != uid) {
      return const RivalryActionResult.failure(
        'Only the challenged Hunter can accept this rivalry.',
      );
    }
    if (rivalry.status != RivalryStatus.pending) {
      return const RivalryActionResult.failure(
        'This rivalry request is no longer pending.',
      );
    }
    if (rivalry.isRequestExpired) {
      return const RivalryActionResult.failure(
        'This rivalry request has expired.',
      );
    }

    final senderUid = rivalry.fromUid;

    try {
      // Narrow the one-active-rivalry race as far as a client can: re-check
      // both sides immediately before the transaction. Client transactions
      // cannot run queries, so this cannot be folded inside. The residual
      // window is the transaction itself.
      final mine = await fetchCurrentRivalry(uid);
      if (mine != null && mine.id != rivalry.id && !mine.isRequestExpired) {
        return RivalryActionResult.failure(_busyMessage(mine, uid));
      }
      final theirs = await _fetchOtherPartyRivalry(senderUid);
      if (theirs != null &&
          theirs.id != rivalry.id &&
          !theirs.isRequestExpired) {
        return const RivalryActionResult.failure(
          'This Hunter has already started another Rivalry.',
        );
      }

      // Baseline snapshot. The sender's document must come from Firestore;
      // the accepting user's own comes from the live-cached repository, with a
      // Firestore fallback for a cold cache.
      final senderSnap = await _hunters.doc(senderUid).get();
      if (!senderSnap.exists) {
        return const RivalryActionResult.failure(
          'This Hunter no longer exists.',
        );
      }
      final int senderStart = totalXpFrom(senderSnap.data());

      final cachedMe = HunterRepository.instance.getCached();
      final int myStart;
      if (cachedMe != null) {
        myStart = (cachedMe.level - 1) * _xpPerLevel + cachedMe.xp;
      } else {
        final meSnap = await _hunters.doc(uid).get();
        myStart = totalXpFrom(meSnap.data());
      }

      final ref = _rivalries.doc(rivalry.id);
      var accepted = false;

      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = RivalryData.fromSnapshot(snap);
        // Re-assert inside the transaction so two devices cannot both accept.
        if (current.status != RivalryStatus.pending) return;
        if (current.toUid != uid) return;

        // Exactly three keys — the accept rule whitelists these and nothing
        // else, so this write cannot touch winner, endScore or xpAwarded.
        txn.update(ref, <String, dynamic>{
          'status': RivalryStatus.active,
          'startAt': FieldValue.serverTimestamp(),
          'startScore': <String, int>{uid: myStart, senderUid: senderStart},
        });
        accepted = true;
      });

      if (!accepted) {
        return const RivalryActionResult.failure(
          'This rivalry request is no longer pending.',
        );
      }
      return RivalryActionResult.success(await fetchById(rivalry.id));
    } on FirebaseException catch (e) {
      debugPrint('RivalryService.accept: ${e.code} ${e.message}');
      return RivalryActionResult.failure(_firebaseMessage(e));
    } catch (e) {
      debugPrint('RivalryService.accept: $e');
      return const RivalryActionResult.failure(
        'Could not accept the rivalry. Please try again.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 3 — DECLINE  (receiver only: status, unsettledFor)
  // ══════════════════════════════════════════════════════════════════════

  /// Declines an incoming request. Clears `unsettledFor` entirely so the
  /// document immediately stops matching either user's current-rivalry query.
  Future<RivalryActionResult> decline(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) {
      return const RivalryActionResult.failure('You must be signed in.');
    }
    if (rivalry.toUid != uid) {
      return const RivalryActionResult.failure(
        'Only the challenged Hunter can decline this rivalry.',
      );
    }
    if (rivalry.status != RivalryStatus.pending) {
      return const RivalryActionResult.failure(
        'This rivalry request is no longer pending.',
      );
    }
    try {
      await _rivalries.doc(rivalry.id).update(<String, dynamic>{
        'status': RivalryStatus.declined,
        'unsettledFor': <String>[],
      });
      return const RivalryActionResult.success();
    } on FirebaseException catch (e) {
      debugPrint('RivalryService.decline: ${e.code} ${e.message}');
      return RivalryActionResult.failure(_firebaseMessage(e));
    } catch (e) {
      debugPrint('RivalryService.decline: $e');
      return const RivalryActionResult.failure(
        'Could not decline the rivalry. Please try again.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 4 — CANCEL A SENT REQUEST  (either participant, delete)
  // ══════════════════════════════════════════════════════════════════════

  /// Withdraws a request that has not been answered yet.
  Future<RivalryActionResult> cancelRequest(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) {
      return const RivalryActionResult.failure('You must be signed in.');
    }
    if (!rivalry.isParticipant(uid)) {
      return const RivalryActionResult.failure('This is not your rivalry.');
    }
    if (rivalry.status != RivalryStatus.pending) {
      return const RivalryActionResult.failure(
        'This rivalry can no longer be cancelled.',
      );
    }
    try {
      await _rivalries.doc(rivalry.id).delete();
      return const RivalryActionResult.success();
    } on FirebaseException catch (e) {
      debugPrint('RivalryService.cancelRequest: ${e.code} ${e.message}');
      return RivalryActionResult.failure(_firebaseMessage(e));
    } catch (e) {
      debugPrint('RivalryService.cancelRequest: $e');
      return const RivalryActionResult.failure(
        'Could not cancel the request. Please try again.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 5 — FINALIZE  (either participant: status, winner,
  //                           endScore, completedAt)
  // ══════════════════════════════════════════════════════════════════════

  /// Computes and FREEZES the outcome once the duration has elapsed.
  ///
  /// Whoever opens the app first does this. The transaction asserts
  /// `status == 'active'` and that no winner has been written, mirroring the
  /// duel system's `_autoCompleteDuel()`. The second participant therefore
  /// never recomputes anything: they read the stored verdict, so both users
  /// always see the identical result and the same rivalry can only ever
  /// produce one outcome.
  ///
  /// Ties — including the common "neither hunter did anything" 0 == 0 — are
  /// stored as `winner: ''`, the same draw convention the duel system uses.
  ///
  /// Returns the completed document, or `null` if it is not finalizable.
  Future<RivalryData?> finalizeIfExpired(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) return null;
    if (!rivalry.isParticipant(uid)) return null;

    // Already frozen — never recompute.
    if (rivalry.status == RivalryStatus.completed) return rivalry;
    if (rivalry.status != RivalryStatus.active) return null;
    if (!rivalry.hasExpired) return null;

    final participants = rivalry.participants;
    if (participants.length != 2) return null;
    final a = participants[0];
    final b = participants[1];

    try {
      final snaps = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>(
        <Future<DocumentSnapshot<Map<String, dynamic>>>>[
          _hunters.doc(a).get(),
          _hunters.doc(b).get(),
        ],
      );

      final startA = rivalry.startScore[a];
      final startB = rivalry.startScore[b];
      if (startA == null || startB == null) {
        debugPrint('RivalryService.finalizeIfExpired: missing startScore');
        return null;
      }

      // A hunter who deleted their account keeps their baseline, so their
      // progress is treated as zero rather than crashing the finalization.
      final endA = snaps[0].exists ? totalXpFrom(snaps[0].data()) : startA;
      final endB = snaps[1].exists ? totalXpFrom(snaps[1].data()) : startB;

      final deltaA = endA - startA;
      final deltaB = endB - startB;
      final String winner = deltaA > deltaB
          ? a
          : deltaB > deltaA
              ? b
              : ''; // equal progress, including 0 == 0, is a DRAW

      final ref = _rivalries.doc(rivalry.id);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = RivalryData.fromSnapshot(snap);
        // Whoever loses this race simply does nothing; the winner of the race
        // has already written the one and only verdict.
        if (current.status != RivalryStatus.active) return;
        if (current.winner != null) return;

        // Exactly four keys. The finalize rule whitelists these and also
        // enforces, using server time, that the duration really has elapsed —
        // so a manipulated device clock cannot finalize early.
        txn.update(ref, <String, dynamic>{
          'status': RivalryStatus.completed,
          'winner': winner,
          'endScore': <String, int>{a: endA, b: endB},
          'completedAt': FieldValue.serverTimestamp(),
        });
      });

      return await fetchById(rivalry.id);
    } on FirebaseException catch (e) {
      debugPrint('RivalryService.finalizeIfExpired: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('RivalryService.finalizeIfExpired: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 6 — CLAIM WINNER XP  (winner only: xpAwarded, write-once)
  // ══════════════════════════════════════════════════════════════════════

  /// Grants the winner +50 XP through the existing [XpService], exactly once.
  ///
  /// ## How the race is closed
  /// The gate is a single boolean on the SHARED document, so both devices
  /// contend on the same Firestore document and transactions are serialized
  /// per document: exactly one caller can flip `xpAwarded` false to true. The
  /// loser's device additionally fails the `winner == uid` assertion, so it
  /// can never grant XP even if it races. Reopening the result, restarting the
  /// app or switching devices all re-enter here and find the flag already set.
  ///
  /// ## Why there is no rollback
  /// The duel implementation rolls its flag back when the XP grant fails. That
  /// requires rules to permit `true -> false`, which hands the winner an
  /// unlimited XP replay: claim, roll back, claim again. `xpAwarded` is
  /// therefore WRITE-ONCE here, and the grant is retried in-session instead.
  /// The residual risk is narrow and one-directional: if the process dies
  /// between the claim and a successful grant, 50 XP is lost rather than
  /// duplicated.
  ///
  /// XP is only ever written to the caller's OWN hunter document — cross-user
  /// hunter writes are forbidden by the rules, and nothing here attempts one.
  Future<RivalryXpResult> claimWinnerXp(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) return const RivalryXpResult(granted: false);
    if (rivalry.status != RivalryStatus.completed) {
      return const RivalryXpResult(granted: false);
    }
    if (rivalry.winner != uid) {
      return const RivalryXpResult(granted: false);
    }
    if (rivalry.xpAwarded) return const RivalryXpResult(granted: false);

    final ref = _rivalries.doc(rivalry.id);
    var claimed = false;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final current = RivalryData.fromSnapshot(snap);
        if (current.status != RivalryStatus.completed) return;
        if (current.winner != uid) return;
        if (current.xpAwarded) return; // already granted somewhere else

        // Exactly one key.
        txn.update(ref, <String, dynamic>{'xpAwarded': true});
        claimed = true;
      });
    } catch (e) {
      debugPrint('RivalryService.claimWinnerXp gate: $e');
      return const RivalryXpResult(granted: false);
    }

    if (!claimed) return const RivalryXpResult(granted: false);

    // Claim committed. Hand the grant to the shared service, retrying so a
    // single transient failure does not cost the reward.
    for (var attempt = 1; attempt <= _xpGrantAttempts; attempt++) {
      try {
        final award = await XpService.instance.awardXp(amount: winnerXpReward);
        if (award != null) {
          return RivalryXpResult(granted: true, award: award);
        }
      } catch (e) {
        debugPrint('RivalryService.claimWinnerXp grant $attempt: $e');
      }
      if (attempt < _xpGrantAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    debugPrint('RivalryService.claimWinnerXp: grant failed after retries');
    return const RivalryXpResult(granted: true);
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 7 — SETTLE MY SIDE  (either participant: unsettledFor)
  // ══════════════════════════════════════════════════════════════════════

  /// Marks this user as finished with the rivalry by removing ONLY their own
  /// uid from `unsettledFor`.
  ///
  /// This is the single write the loser's completed rewarded ad performs, and
  /// it is why the ad flow is idempotent for free:
  /// * `arrayRemove` is idempotent and commutative, so running it twice, or
  ///   both users running it at once, is safe. No transaction needed.
  /// * Once removed, the document no longer matches this user's
  ///   `array-contains` query, so the Battle Hub shows "no rival" and the
  ///   result screen becomes UNREACHABLE. Reopening cannot create a second
  ///   reward opportunity — structurally, not via a guard flag.
  /// * The ad grants nothing anyway: it gates dismissal of the result, so
  ///   there is no reward to duplicate.
  Future<bool> settleMySide(RivalryData rivalry) async {
    final uid = _uid;
    if (uid == null) return false;
    if (!rivalry.isParticipant(uid)) return false;
    try {
      await _rivalries.doc(rivalry.id).update(<String, dynamic>{
        'unsettledFor': FieldValue.arrayRemove(<String>[uid]),
      });
      return true;
    } catch (e) {
      debugPrint('RivalryService.settleMySide: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRANSITION 8 — ABANDON  (leaving participant: status, unsettledFor)
  // ══════════════════════════════════════════════════════════════════════
  //
  // Implemented in `AccountDeletionService._releaseRivalries`, not here.
  // That service deliberately owns an EXPLICIT inventory of every user-owned
  // Firestore path and runs against its own injectable FirebaseFirestore
  // handle, so putting the cleanup there keeps the deletion footprint
  // auditable in one place instead of splitting it across two services.
  //
  // The policy it applies: `pending` is deleted outright (either party may
  // withdraw a request, matching the existing duel_requests cleanup);
  // `active` becomes `abandoned` with the leaver removed from unsettledFor,
  // which fabricates no result and awards no XP while unblocking the
  // remaining hunter immediately; anything else just removes the leaver so
  // the stored verdict survives for the other participant. The shared
  // document is never deleted out from under the other hunter, matching the
  // existing policy for shared duel records.

  // ══════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════

  String _busyMessage(RivalryData rivalry, String uid) {
    switch (rivalry.status) {
      case RivalryStatus.pending:
        return rivalry.toUid == uid
            ? 'Answer your incoming Rivalry request first.'
            : 'You already have a Rivalry request pending.';
      case RivalryStatus.active:
        return 'You already have an active Rivalry.';
      case RivalryStatus.completed:
        return 'View your last Rivalry result first.';
      default:
        return 'You already have a Rivalry in progress.';
    }
  }

  String _firebaseMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Rivalries are not enabled yet. Please try again later.';
    }
    if (e.code == 'unavailable') {
      return 'Internet connection required.';
    }
    return 'Something went wrong. Please try again.';
  }
}
