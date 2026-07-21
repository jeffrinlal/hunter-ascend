import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The membership tiers supported by Hunter Ascend.
///
/// Order matters only for readability — tier comparisons in this service are
/// always done via the exposed boolean getters (e.g. [MembershipService.isPro]),
/// never by comparing this enum directly from UI code.
enum MembershipTier {
  basic,
  pro,
  max;

  /// Parses a raw tier string (e.g. `"basic"`, `"pro"`, `"max"`) into the
  /// corresponding [MembershipTier].
  ///
  /// Unrecognized, empty, or null-like values safely fall back to
  /// [MembershipTier.basic] so a malformed/legacy value never grants premium
  /// features by accident.
  ///
  /// This is the single canonical place for tier-string parsing — both
  /// [MembershipService] (for the current user's Firestore document) and
  /// widgets displaying other hunters' tiers should use this factory.
  static MembershipTier fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pro':
        return MembershipTier.pro;
      case 'max':
        return MembershipTier.max;
      case 'basic':
      default:
        return MembershipTier.basic;
    }
  }
}

/// Immutable configuration describing every premium feature flag unlocked by
/// a given [MembershipTier].
///
/// All membership business rules (which tier unlocks which feature) live
/// exclusively in the [MembershipFeatures.basic], [MembershipFeatures.pro]
/// and [MembershipFeatures.max] configurations below. [MembershipService]'s
/// public feature getters simply forward to the configuration that matches
/// the currently cached tier — this keeps the rules in exactly one place and
/// makes future changes (e.g. adjusting what Pro unlocks) a one-line edit.
@immutable
class MembershipFeatures {
  const MembershipFeatures({
    required this.bannerAds,
    required this.rewardedAds,
    required this.unlimitedProfileChanges,
    required this.goldBadge,
    required this.goldFrame,
    required this.goldGlow,
    required this.animatedFrame,
    required this.animatedGlow,
  });

  /// Whether banner ads should be shown.
  final bool bannerAds;

  /// Whether rewarded ads should be offered.
  final bool rewardedAds;

  /// Whether profile changes are unlimited (no cooldown/limit).
  final bool unlimitedProfileChanges;

  /// Whether the static gold badge cosmetic is unlocked.
  final bool goldBadge;

  /// Whether the static gold profile frame cosmetic is unlocked.
  final bool goldFrame;

  /// Whether the static gold glow cosmetic is unlocked.
  final bool goldGlow;

  /// Whether the animated profile frame cosmetic is unlocked.
  final bool animatedFrame;

  /// Whether the animated glow cosmetic is unlocked.
  final bool animatedGlow;

  /// Feature configuration for the Basic (free/default) tier.
  static const MembershipFeatures basic = MembershipFeatures(
    bannerAds: true,
    rewardedAds: true,
    unlimitedProfileChanges: false,
    goldBadge: false,
    goldFrame: false,
    goldGlow: false,
    animatedFrame: false,
    animatedGlow: false,
  );

  /// Feature configuration for the Pro tier.
  static const MembershipFeatures pro = MembershipFeatures(
    bannerAds: false,
    rewardedAds: true,
    unlimitedProfileChanges: true,
    goldBadge: true,
    goldFrame: true,
    goldGlow: true,
    animatedFrame: false,
    animatedGlow: false,
  );

  /// Feature configuration for the Max tier.
  static const MembershipFeatures max = MembershipFeatures(
    bannerAds: false,
    rewardedAds: false,
    unlimitedProfileChanges: true,
    goldBadge: true,
    goldFrame: false,
    goldGlow: false,
    animatedFrame: true,
    animatedGlow: true,
  );

  /// Returns the feature configuration that corresponds to [tier].
  static MembershipFeatures forTier(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.basic:
        return MembershipFeatures.basic;
      case MembershipTier.pro:
        return MembershipFeatures.pro;
      case MembershipTier.max:
        return MembershipFeatures.max;
    }
  }
}

/// Single source of truth for the user's membership tier and the premium
/// features it unlocks.
///
/// ## Responsibilities
/// - Reads the current hunter's membership fields from
///   `hunters/{uid}` (`membership`, `subscriptionActive`, `membershipExpiry`).
/// - Caches the result in memory so Firestore is only read once per app
///   session (call [reload] to force a refresh, e.g. after a purchase is
///   confirmed by the backend).
/// - Exposes simple boolean/string getters (`isPro`, `isMax`, `showBannerAds`,
///   etc.) so screens never compare raw membership strings
///   directly.
/// - Keeps every Basic/Pro/Max feature rule in a single place: the
///   [MembershipFeatures] configuration model.
///
/// ## What this service does NOT do
/// - It never writes to Firestore. Membership is only ever upgraded by the
///   backend after a Google Play Billing purchase is verified server-side.
/// - It never exposes the raw `membership` string from Firestore to callers
///   — the only string exposed is the human-readable [membershipName].
///
/// ## Usage
/// ```dart
/// await MembershipService.instance.loadMembership(); // once, e.g. on app start / login
///
/// if (MembershipService.instance.showBannerAds) {
///   // show banner ad
/// }
///
/// // On logout:
/// MembershipService.instance.clearCache();
/// ```
class MembershipService {
  MembershipService._();

  /// The single shared instance of this service.
  ///
  /// Always use [MembershipService.instance] rather than constructing this
  /// class directly, so the in-memory cache is shared across the whole app.
  static final MembershipService instance = MembershipService._();

  /// Firestore collection where hunter documents (including membership
  /// fields) are stored.
  static const String _huntersCollection = 'hunters';

  MembershipTier _tier = MembershipTier.basic;
  bool _subscriptionActive = false;
  DateTime? _membershipExpiry;

  /// Tracks which tier just expired (for the one-time expiration dialog).
  /// Set during [_applyDocumentData] when a premium tier is found expired.
  /// Consumed (reset to null) by [consumeExpiredTier].
  MembershipTier? _lastExpiredTier;

  /// The specific expiry timestamp for which the dialog has already been
  /// shown. Prevents re-arming [_lastExpiredTier] on subsequent Firestore
  /// snapshot emissions while the same expiry is still in effect.
  /// Reset on logout ([clearCache]) so a new session or a renewed-then-
  /// re-expired membership (with a different expiry) triggers the dialog.
  DateTime? _lastShownExpiryTimestamp;

  // ─────────────────────────────────────────────────────────────────────────
  // Basic Mode Override
  //
  // Allows a Pro/Max hunter to temporarily experience the app as Basic
  // (ads shown, premium features hidden) without modifying their actual
  // membership or expiry. Persisted across app restarts.
  // ─────────────────────────────────────────────────────────────────────────

  static const String _basicModePrefsKey = 'membership_basic_mode_override';

  /// When true, [_effectiveTier] returns Basic even if the actual membership
  /// is Pro/Max and not expired. Cleared automatically if the membership
  /// actually expires (no longer meaningful to override).
  bool _basicModeOverride = false;

  /// Whether a successful load has completed at least once this session.
  bool _hasLoaded = false;

  /// Guards against duplicate concurrent Firestore reads if [loadMembership]
  /// or [reload] is called multiple times before the first call resolves.
  Future<void>? _pendingFetch;

  /// The active Firestore real-time listener. Only one exists at a time.
  /// Cancelled on [clearCache] or when the listened UID changes.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _snapshotSub;

  /// The UID the current snapshot listener is bound to.
  String? _listeningUid;

  /// Listens to [FirebaseAuth.authStateChanges] so the membership listener
  /// can be (re)started whenever a UID actually becomes available — not
  /// just once at cold start.
  ///
  /// ## Why this exists
  /// [loadMembership] is awaited exactly once in `main()`, before the first
  /// frame renders. At that instant `FirebaseAuth.instance.currentUser` may
  /// still be `null` if the persisted auth session hasn't finished
  /// restoring yet (a real, observed race — especially right after
  /// anonymous sign-in). When that happens, [_readFromFirestore] and
  /// [_ensureListening] both bail out on the null UID *without* setting
  /// [_hasLoaded], and since nothing else in the app calls [loadMembership]
  /// or [reload] automatically, the service would otherwise stay stuck on
  /// the Basic default — with no Firestore listener running — for the rest
  /// of the session. Binding to auth state changes closes that race
  /// permanently: as soon as a UID appears (or changes, e.g. login after
  /// logout), the fetch + listener are (re)established.
  bool _authListenerBound = false;
  StreamSubscription<User?>? _authStateSub;

  // ─────────────────────────────────────────────────────────────────────────
  // Reactive notifier
  //
  // A single ValueNotifier that fires whenever the effective tier changes.
  // Screens that cache membership-dependent objects (e.g. banner ads) can
  // listen; screens that already rebuild on Firestore streams do not need to.
  // ─────────────────────────────────────────────────────────────────────────

  /// Fires whenever the effective membership tier changes.
  ///
  /// Only screens that cache membership-dependent state at init (e.g.
  /// banner ads) need to listen. Screens with their own Firestore
  /// StreamBuilder on the hunter doc rebuild automatically.
  final ValueNotifier<MembershipTier> tierNotifier =
      ValueNotifier<MembershipTier>(MembershipTier.basic);

  /// Whether membership data has been successfully loaded at least once
  /// during this app session.
  ///
  /// Useful for callers that want to show a loading state until membership
  /// info is available, without triggering another Firestore read.
  bool get isLoaded => _hasLoaded;

  /// Loads the current hunter's membership data from Firestore and caches it
  /// in memory.
  ///
  /// This is a no-op if membership has already been loaded once during this
  /// app session — call [reload] instead to force a fresh read (for example
  /// right after the backend confirms a Google Play Billing purchase and updates
  /// Firestore).
  ///
  /// If there is no signed-in user, or the hunter document / fields are
  /// missing, membership safely falls back to [MembershipTier.basic] with no
  /// active subscription rather than throwing.
  Future<void> loadMembership() async {
    _bindAuthStateListener();
    if (_hasLoaded) return;
    await _loadBasicModeOverride();
    await _fetchAndCache();
    _ensureListening();
  }

  /// Binds a single, idempotent listener to [FirebaseAuth.authStateChanges]
  /// so membership is (re)fetched and the live listener (re)started the
  /// moment a UID becomes available or changes — instead of relying solely
  /// on the one-shot call in `main()`, which can race with auth restoration.
  ///
  /// Safe to call multiple times; only binds once per app session.
  void _bindAuthStateListener() {
    if (_authListenerBound) return;
    _authListenerBound = true;
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        // Signed out — handled explicitly by clearCache() on logout flows,
        // but guard here too in case auth drops out from under us.
        return;
      }
      if (_listeningUid == user.uid && _hasLoaded) {
        // Already tracking this exact user — nothing to do.
        return;
      }
      // New/changed UID became available — fetch once and (re)start the
      // live listener for it.
      unawaited(_fetchAndCache().then((_) => _ensureListening()));
    });
  }

  /// Forces a fresh read of membership data from Firestore, discarding the
  /// in-memory cache.
  ///
  /// Intended to be called after an event that may have changed the user's
  /// membership server-side (e.g. the backend just verified a Google Play
  /// Billing purchase and updated `hunters/{uid}`), or when the user pulls-to-refresh
  /// a membership/account screen.
  Future<void> reload() async {
    _hasLoaded = false;
    await _fetchAndCache();
    _ensureListening();
  }

  /// Resets all cached membership data back to the Basic defaults.
  ///
  /// Intended to be called on logout (or when switching accounts) so the
  /// next signed-in hunter never inherits the previous hunter's cached
  /// membership state. After calling this, [loadMembership] will perform a
  /// fresh Firestore read the next time it is called.
  void clearCache() {
    _stopListening();
    _applyDefaults();
    _hasLoaded = false;
    _pendingFetch = null;
    _lastShownExpiryTimestamp = null;
    _basicModeOverride = false;
    tierNotifier.value = MembershipTier.basic;
  }

  /// Clears the account-scoped membership preference as part of permanent
  /// account deletion. Visual app preferences are intentionally retained.
  Future<void> clearAccountData() async {
    clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_basicModePrefsKey);
  }

  /// Performs the actual Firestore read, coalescing concurrent calls into a
  /// single in-flight request.
  Future<void> _fetchAndCache() async {
    if (_pendingFetch != null) {
      // Another load/reload is already in progress — await it instead of
      // issuing a second redundant Firestore read.
      await _pendingFetch;
      return;
    }

    final fetch = _readFromFirestore();
    _pendingFetch = fetch;
    try {
      await fetch;
    } finally {
      _pendingFetch = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Real-time Firestore listener (single instance, idempotent)
  // ─────────────────────────────────────────────────────────────────────────

  /// Starts a real-time listener on `hunters/{uid}` if one is not already
  /// active for the current user. If the UID has changed (account switch),
  /// the old listener is cancelled first.
  ///
  /// This is intentionally idempotent — calling it multiple times with the
  /// same UID is a no-op and cannot create duplicate subscriptions.
  void _ensureListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Already listening for this exact user — nothing to do.
    if (_snapshotSub != null && _listeningUid == uid) return;

    // Different user or no listener yet — (re)start.
    _stopListening();
    _listeningUid = uid;

    _snapshotSub = FirebaseFirestore.instance
        .collection(_huntersCollection)
        .doc(uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          _applyDefaults();
        } else {
          _applyDocumentData(snapshot.data());
        }
        _hasLoaded = true;
        _notifyIfChanged();
      },
      onError: (e) {
        debugPrint('MembershipService: snapshot listener error — $e');
      },
    );
  }

  /// Cancels the active Firestore listener.
  void _stopListening() {
    _snapshotSub?.cancel();
    _snapshotSub = null;
    _listeningUid = null;
  }

  /// Updates [tierNotifier] only if the effective tier has actually changed.
  /// This prevents spurious rebuilds when unrelated document fields update.
  void _notifyIfChanged() {
    final effective = _effectiveTier;
    if (tierNotifier.value != effective) {
      tierNotifier.value = effective;
    }
  }

  /// Reads `hunters/{uid}` (read-only) and updates the in-memory cache.
  ///
  /// This method NEVER writes to Firestore. Membership fields are owned
  /// exclusively by the backend, which updates them after verifying a
  /// Google Play Billing purchase.
  Future<void> _readFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        // No signed-in user — treat as Basic rather than crash.
        _applyDefaults();
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection(_huntersCollection)
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        _applyDefaults();
        return;
      }

      _applyDocumentData(snapshot.data());
      _hasLoaded = true;
      _notifyIfChanged();
    } catch (e) {
      debugPrint('MembershipService: failed to load membership — $e');
      // Keep whatever was previously cached (or the Basic defaults) instead
      // of throwing, so a transient Firestore/network failure never crashes
      // a screen that depends on membership getters.
    }
  }

  /// Parses the raw Firestore document fields into the cached, typed state.
  void _applyDocumentData(Map<String, dynamic>? data) {
    if (data == null) {
      _applyDefaults();
      return;
    }

    _tier = MembershipTier.fromString(
        (data['membershipType'] ?? data['membership'])?.toString());
    _subscriptionActive = data['subscriptionActive'] == true;
    _membershipExpiry = _parseExpiry(data['membershipExpiry']);

    // ── Auto-expiration check ──
    // If the stored tier is premium but the expiry is in the past,
    // record it for the one-time dialog — but only if this specific expiry
    // hasn't already been shown. This prevents re-arming the flag on every
    // Firestore snapshot while the same expired membership persists.
    if (_tier != MembershipTier.basic && _membershipExpiry != null &&
        _membershipExpiry!.isBefore(DateTime.now())) {
      if (_lastShownExpiryTimestamp != _membershipExpiry) {
        _lastExpiredTier = _tier;
      }
      // Clear Basic Mode override — membership has actually expired, so
      // the override is no longer meaningful (user is already Basic).
      if (_basicModeOverride) {
        _basicModeOverride = false;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_basicModePrefsKey, false);
        });
      }
    }
  }

  /// Resets the cache to the safe, no-purchase default: Basic membership,
  /// no active subscription, no expiry.
  void _applyDefaults() {
    _tier = MembershipTier.basic;
    _subscriptionActive = false;
    _membershipExpiry = null;
  }

  /// Parses the raw `membershipExpiry` Firestore field, which may be stored
  /// as a Firestore [Timestamp] or an ISO-8601 [String], into a [DateTime].
  ///
  /// Returns `null` if the field is missing or in an unrecognized format.
  DateTime? _parseExpiry(dynamic rawExpiry) {
    if (rawExpiry == null) return null;
    if (rawExpiry is Timestamp) return rawExpiry.toDate();
    if (rawExpiry is DateTime) return rawExpiry;
    if (rawExpiry is String) return DateTime.tryParse(rawExpiry);
    return null;
  }

  /// The feature configuration for the currently cached membership tier.
  ///
  /// All public feature getters below simply forward to this configuration,
  /// so every Basic/Pro/Max rule lives in exactly one place:
  /// [MembershipFeatures].
  MembershipFeatures get _features => MembershipFeatures.forTier(_effectiveTier);

  /// The effective tier: if the stored tier is premium but expired,
  /// this returns Basic. If Basic Mode override is active (and membership
  /// is still valid), this also returns Basic. Otherwise returns the stored tier.
  /// All public getters use this — never [_tier] directly.
  MembershipTier get _effectiveTier {
    // Expired membership → always Basic (regardless of override).
    if (_tier != MembershipTier.basic && _membershipExpiry != null &&
        _membershipExpiry!.isBefore(DateTime.now())) {
      return MembershipTier.basic;
    }
    // Basic Mode override active → treat as Basic.
    if (_basicModeOverride && _tier != MembershipTier.basic) {
      return MembershipTier.basic;
    }
    return _tier;
  }

  /// The stored membership tier from Firestore (may be expired).
  /// Use [_effectiveTier] for feature gating.
  MembershipTier get storedTier => _tier;

  // ───────────────────────────────────────────────────────────────────────
  // Tier getters
  //
  // Screens should always check membership via these getters (or the
  // feature getters below) — never by comparing a raw membership string.
  // ───────────────────────────────────────────────────────────────────────

  /// Whether the current hunter is on the free/default Basic tier.
  bool get isBasic => _effectiveTier == MembershipTier.basic;

  /// Whether the current hunter has an active Pro membership.
  bool get isPro => _effectiveTier == MembershipTier.pro;

  /// Whether the current hunter has an active Max membership.
  bool get isMax => _effectiveTier == MembershipTier.max;

  /// Whether the current hunter has any paid membership (Pro or Max).
  ///
  /// Convenience getter for call sites that only need to know "is this a
  /// paying member" without caring which specific paid tier it is.
  bool get hasPremium => isPro || isMax;

  /// Human-readable membership name for display in the UI (e.g. on a
  /// profile or settings screen).
  ///
  /// This is the ONLY place the membership tier is exposed as a string —
  /// it is derived from the cached [MembershipTier], never the raw
  /// Firestore value, so it is always one of `"Basic"`, `"Pro"` or `"Max"`.
  String get membershipName {
    switch (_effectiveTier) {
      case MembershipTier.basic:
        return 'Basic';
      case MembershipTier.pro:
        return 'Pro';
      case MembershipTier.max:
        return 'Max';
    }
  }

  /// Whether the hunter's paid subscription is currently active, as reported
  /// by the backend (`subscriptionActive` field in Firestore).
  ///
  /// This is informational only — feature access should always be checked
  /// through the tier/feature getters, not this flag directly, since the
  /// backend is responsible for keeping `membership` consistent with
  /// subscription state.
  bool get subscriptionActive => _subscriptionActive;

  /// The date/time the hunter's current membership expires, if any.
  ///
  /// `null` when there is no subscription or no expiry has been set (e.g.
  /// Basic tier, or a Pro/Max grant with no expiry configured).
  DateTime? get membershipExpiry => _membershipExpiry;

  // ─────────────────────────────────────────────────────────────────────────
  // Basic Mode Override — Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether the Basic Mode override is currently active.
  ///
  /// When true, the app behaves as Basic even though the user holds a valid
  /// Pro/Max membership. The actual membership and expiry are unchanged.
  bool get isBasicModeActive => _basicModeOverride && _tier != MembershipTier.basic;

  /// The user's actual (non-overridden) membership tier. Returns the real
  /// tier even while Basic Mode is active. Returns Basic if expired.
  MembershipTier get actualTier {
    if (_tier != MembershipTier.basic && _membershipExpiry != null &&
        _membershipExpiry!.isBefore(DateTime.now())) {
      return MembershipTier.basic;
    }
    return _tier;
  }

  /// Enables Basic Mode: the app will behave as Basic until [disableBasicMode]
  /// is called or the membership actually expires.
  Future<void> enableBasicMode() async {
    if (_tier == MembershipTier.basic) return; // No-op for Basic users.
    _basicModeOverride = true;
    _notifyIfChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_basicModePrefsKey, true);
  }

  /// Disables Basic Mode: restores the user's actual Pro/Max experience.
  Future<void> disableBasicMode() async {
    _basicModeOverride = false;
    _notifyIfChanged();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_basicModePrefsKey, false);
  }

  /// Loads the persisted Basic Mode override state from SharedPreferences.
  /// Called once during [loadMembership].
  Future<void> _loadBasicModeOverride() async {
    final prefs = await SharedPreferences.getInstance();
    _basicModeOverride = prefs.getBool(_basicModePrefsKey) ?? false;
  }

  /// Whether a membership expiration was detected on the most recent load.
  ///
  /// Returns `true` only once per expiration event. After calling
  /// [consumeExpiredTier], this returns `false` until the next expiration.
  bool get hasJustExpired => _lastExpiredTier != null;

  /// Returns the tier that just expired and clears the flag.
  ///
  /// Call this once to show the expiration dialog. Subsequent calls
  /// return `null` until a new expiration is detected (i.e. the user
  /// renews and their membership expires again with a different timestamp).
  MembershipTier? consumeExpiredTier() {
    final tier = _lastExpiredTier;
    _lastExpiredTier = null;
    if (tier != null) {
      // Record the specific expiry that was shown so it won't re-arm.
      _lastShownExpiryTimestamp = _membershipExpiry;
    }
    return tier;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Feature getters
  //
  // Every premium-gated behavior in the app should be driven by one of
  // these getters so the Basic/Pro/Max rules live in exactly one place:
  // the MembershipFeatures configuration model above.
  // ───────────────────────────────────────────────────────────────────────

  /// Whether banner ads should be shown to this hunter.
  ///
  /// Basic: true · Pro: true · Max: false.
  bool get showBannerAds => _features.bannerAds;

  /// Whether rewarded ads should be offered to this hunter.
  ///
  /// Basic: true · Pro: true · Max: false.
  bool get showRewardedAds => _features.rewardedAds;

  /// Whether this hunter can change their profile an unlimited number of
  /// times (as opposed to a limited/cooldown-gated number of changes).
  ///
  /// Basic: false · Pro: true · Max: true.
  bool get unlimitedProfileChanges => _features.unlimitedProfileChanges;

  /// Whether this hunter is entitled to display the gold badge cosmetic.
  ///
  /// Basic: false · Pro: true · Max: true.
  bool get goldBadge => _features.goldBadge;

  /// Whether this hunter is entitled to display the static gold profile
  /// frame cosmetic.
  ///
  /// Basic: false · Pro: true · Max: false.
  bool get goldFrame => _features.goldFrame;

  /// Whether this hunter is entitled to display the static gold glow
  /// cosmetic.
  ///
  /// Basic: false · Pro: true · Max: false.
  bool get goldGlow => _features.goldGlow;

  /// Whether this hunter is entitled to display the animated profile frame
  /// cosmetic (Max-exclusive, replaces the static gold frame).
  ///
  /// Basic: false · Pro: false · Max: true.
  bool get animatedFrame => _features.animatedFrame;

  /// Whether this hunter is entitled to display the animated glow cosmetic
  /// (Max-exclusive, replaces the static gold glow).
  ///
  /// Basic: false · Pro: false · Max: true.
  bool get animatedGlow => _features.animatedGlow;

  // ───────────────────────────────────────────────────────────────────────
  // Rewarded Ad Skips (Max-only)
  //
  // Max members receive a fixed monthly allowance of rewarded ad skips.
  // When a skip is available, the ad is not shown and the reward is granted
  // immediately. Once all skips are consumed, rewarded ads behave normally.
  // Skips reset automatically when a new subscription period begins,
  // determined by the existing `membershipExpiry` field.
  // ───────────────────────────────────────────────────────────────────────

  /// The number of rewarded ad skips granted to Max members each
  /// subscription month.
  static const int _monthlySkipAllowance = 5;

  /// Attempts to consume a rewarded ad skip for the current user.
  ///
  /// Returns `true` (skip the ad, grant the reward immediately) only when
  /// ALL of the following are true:
  /// 1. The current user is a Max member.
  /// 2. The user has remaining monthly skips for the current subscription
  ///    period.
  /// 3. The skip count was successfully decremented in Firestore (via a
  ///    transaction to prevent race conditions from concurrent calls).
  ///
  /// Returns `false` in all other cases (non-Max tier, no remaining skips,
  /// no signed-in user, Firestore failure). When `false` is returned, the
  /// caller should proceed to show the rewarded ad as usual.
  ///
  /// ## Firestore fields (on `hunters/{uid}`)
  /// - `rewardedAdSkipsRemaining` (int): skips left this subscription period.
  /// - `rewardedAdSkipsPeriodEnd` (Timestamp): the `membershipExpiry` value
  ///   that was active when skips were last reset. When this differs from
  ///   the current `membershipExpiry`, a new subscription period has begun
  ///   and skips are auto-reset to [_monthlySkipAllowance].
  ///
  /// ## Usage (screens will adopt later)
  /// ```dart
  /// if (await MembershipService.instance.shouldSkipRewardedAd()) {
  ///   // Grant reward immediately — no ad shown.
  /// } else {
  ///   // Show the rewarded ad as usual.
  /// }
  /// ```
  Future<bool> shouldSkipRewardedAd() async {
    // Only Max members are eligible for ad skips.
    if (!isMax) return false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    // Verify the membership is still active before touching skips.
    // If expiry is null or in the past, the subscription has lapsed —
    // do not grant a skip and do not modify any Firestore fields.
    if (_membershipExpiry == null ||
        _membershipExpiry!.isBefore(DateTime.now().toUtc())) {
      return false;
    }

    final docRef =
        FirebaseFirestore.instance.collection(_huntersCollection).doc(uid);

    try {
      final result =
          await FirebaseFirestore.instance.runTransaction<bool>((txn) async {
        final snapshot = await txn.get(docRef);
        final data = snapshot.data() ?? {};

        // Read the current subscription period boundary from the document.
        final currentExpiry = _parseExpiry(data['membershipExpiry']);
        // Read the period boundary that was active when skips were last set.
        final storedPeriodEnd = _parseExpiry(data['rewardedAdSkipsPeriodEnd']);

        int remaining = (data['rewardedAdSkipsRemaining'] ?? 0) as int;

        // Auto-reset: if the subscription has renewed (expiry moved forward)
        // or if no period has been recorded yet, this is a new cycle.
        final bool isNewPeriod = storedPeriodEnd == null ||
            currentExpiry == null ||
            !currentExpiry.isAtSameMomentAs(storedPeriodEnd);

        if (isNewPeriod) {
          remaining = _monthlySkipAllowance;
        }

        // No skips left — caller should show the ad.
        if (remaining <= 0) return false;

        // Consume one skip atomically.
        remaining -= 1;

        // Store the updated count and the current period boundary.
        final periodEndToStore = currentExpiry != null
            ? Timestamp.fromDate(currentExpiry)
            : null;

        txn.set(
          docRef,
          {
            'rewardedAdSkipsRemaining': remaining,
            if (periodEndToStore != null)
              'rewardedAdSkipsPeriodEnd': periodEndToStore,
          },
          SetOptions(merge: true),
        );

        return true;
      });

      return result;
    } catch (e) {
      debugPrint('MembershipService.shouldSkipRewardedAd: $e');
      // On failure, fall back to showing the ad — never silently grant a
      // reward if Firestore can't confirm the decrement.
      return false;
    }
  }
}
