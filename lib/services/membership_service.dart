import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    required this.unlimitedAI,
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

  /// Whether AI-powered features are unlimited (no usage cap).
  final bool unlimitedAI;

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
    unlimitedAI: false,
  );

  /// Feature configuration for the Pro tier.
  static const MembershipFeatures pro = MembershipFeatures(
    bannerAds: true,
    rewardedAds: true,
    unlimitedProfileChanges: true,
    goldBadge: true,
    goldFrame: true,
    goldGlow: true,
    animatedFrame: false,
    animatedGlow: false,
    unlimitedAI: false,
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
    unlimitedAI: true,
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
///   `unlimitedAI`, etc.) so screens never compare raw membership strings
///   directly.
/// - Keeps every Basic/Pro/Max feature rule in a single place: the
///   [MembershipFeatures] configuration model.
///
/// ## What this service does NOT do
/// - It never writes to Firestore. Membership is only ever upgraded by the
///   backend after a Razorpay payment is verified server-side.
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
/// if (MembershipService.instance.unlimitedAI) {
///   // skip AI usage limit checks
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

  /// Whether a successful load has completed at least once this session.
  bool _hasLoaded = false;

  /// Guards against duplicate concurrent Firestore reads if [loadMembership]
  /// or [reload] is called multiple times before the first call resolves.
  Future<void>? _pendingFetch;

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
  /// right after the backend confirms a Razorpay payment and updates
  /// Firestore).
  ///
  /// If there is no signed-in user, or the hunter document / fields are
  /// missing, membership safely falls back to [MembershipTier.basic] with no
  /// active subscription rather than throwing.
  Future<void> loadMembership() async {
    if (_hasLoaded) return;
    await _fetchAndCache();
  }

  /// Forces a fresh read of membership data from Firestore, discarding the
  /// in-memory cache.
  ///
  /// Intended to be called after an event that may have changed the user's
  /// membership server-side (e.g. the backend just verified a Razorpay
  /// payment and updated `hunters/{uid}`), or when the user pulls-to-refresh
  /// a membership/account screen.
  Future<void> reload() async {
    _hasLoaded = false;
    await _fetchAndCache();
  }

  /// Resets all cached membership data back to the Basic defaults.
  ///
  /// Intended to be called on logout (or when switching accounts) so the
  /// next signed-in hunter never inherits the previous hunter's cached
  /// membership state. After calling this, [loadMembership] will perform a
  /// fresh Firestore read the next time it is called.
  void clearCache() {
    _applyDefaults();
    _hasLoaded = false;
    _pendingFetch = null;
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

  /// Reads `hunters/{uid}` (read-only) and updates the in-memory cache.
  ///
  /// This method NEVER writes to Firestore. Membership fields are owned
  /// exclusively by the backend, which updates them after verifying a
  /// Razorpay payment.
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

    _tier = MembershipTier.fromString(data['membership']?.toString());
    _subscriptionActive = data['subscriptionActive'] == true;
    _membershipExpiry = _parseExpiry(data['membershipExpiry']);
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
  MembershipFeatures get _features => MembershipFeatures.forTier(_tier);

  // ───────────────────────────────────────────────────────────────────────
  // Tier getters
  //
  // Screens should always check membership via these getters (or the
  // feature getters below) — never by comparing a raw membership string.
  // ───────────────────────────────────────────────────────────────────────

  /// Whether the current hunter is on the free/default Basic tier.
  bool get isBasic => _tier == MembershipTier.basic;

  /// Whether the current hunter has an active Pro membership.
  bool get isPro => _tier == MembershipTier.pro;

  /// Whether the current hunter has an active Max membership.
  bool get isMax => _tier == MembershipTier.max;

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
    switch (_tier) {
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

  /// Whether this hunter has unlimited access to AI-powered features (e.g.
  /// AI quest generation) without hitting usage limits.
  ///
  /// Basic: false · Pro: false · Max: true.
  bool get unlimitedAI => _features.unlimitedAI;
}
