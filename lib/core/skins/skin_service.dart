import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/core/skins/skin_catalog.dart';
import 'package:hunter_ascend/core/skins/skin_data.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';

/// Result of a skin unlock attempt (coin purchase or ad reward).
class SkinPurchaseResult {
  const SkinPurchaseResult({
    required this.success,
    this.skinId,
    this.expiresAt,
    this.error,
    this.message,
  });

  final bool success;
  final SkinId? skinId;
  final DateTime? expiresAt;

  /// Machine-readable failure reason (e.g. `'insufficient_coins'`,
  /// `'already_unlocked'`, `'unauthenticated'`, `'firestore_error'`). `null`
  /// on success.
  final String? error;

  /// Human-readable message safe to show directly to the user.
  final String? message;
}

/// Manages skin selection, unlock access (coins or rewarded ad), expiry, and
/// the mutual-exclusivity relationship with the Premium Theme system.
///
/// ## Access model
/// [SkinId.classic] is always available, permanently, for free. Every other
/// skin ([SkinCatalog.all]) grants only *temporary* access via exactly one
/// of two paths, both defined per-skin in the catalog:
/// - [purchaseSkinWithCoins]: pay the skin's `coinPrice` in coins, get
///   `coinUnlockDuration` of access (currently 14 days for every non-default
///   skin).
/// - [grantAdUnlock]: watch one rewarded ad, get `adUnlockDuration` of
///   access (currently 7 days). This method is the integration point for
///   a future ad-flow UI — it does NOT show an ad itself. The caller is
///   responsible for showing the ad (reusing the app's existing
///   [RewardedAdManager]/ad infrastructure) and must only call this method
///   from a genuine `onUserEarnedReward` callback. No access is granted if
///   the ad fails to load/show, or the user closes it before the reward
///   callback fires — this method is simply never called in those cases.
///
/// ## Persistence
/// - **Ownership/expiry** (account data) is stored in Firestore, at
///   `hunters/{uid}/skinUnlocks/{skinId}` — one document per skin the user
///   has ever unlocked, mirroring the existing `planUnlocks` subcollection
///   pattern used by `PlanShopService`. This is the source of truth for
///   "does this user actually have access to this skin right now."
/// - **Which skin is currently selected on this device**, and **whether the
///   Skin or the Premium Theme is the active appearance**, remain in
///   `SharedPreferences` exactly as before (device-local display
///   preference, not account data) — this mirrors `ThemeService`'s own
///   precedent for the active *theme* selection.
///
/// ## Skin vs Premium Theme (mutual exclusivity) — UNCHANGED
/// A Skin and a Premium Theme ([ThemeService]) can never be the active visual
/// appearance at the same time — but choosing one never destroys the other's
/// state. [skinAppearanceActiveNotifier] tracks which one is currently active
/// as a *separate* flag from "which skin is selected" ([activeSkinNotifier])
/// and "how long it has left" (Firestore `skinUnlocks`) so that:
/// - Switching to a Premium Theme via [suppressForTheme] never touches the
///   selected skin, its ownership, or its remaining unlock time.
/// - Switching back via [resumeSkinAppearance] restores the same skin,
///   provided it has not expired in the meantime.
class SkinService with WidgetsBindingObserver {
  SkinService._();
  static final SkinService instance = SkinService._();

  static const String _huntersCollection = 'hunters';
  static const String _skinUnlocksSubcollection = 'skinUnlocks';

  static const String _activeSkinKey = 'activeSkinId';

  /// Whether the Skin (as opposed to a Premium Theme) should be treated as
  /// the active visual appearance. Independent of [_activeSkinKey] so that
  /// suppressing/resuming never touches the selected skin or its expiry.
  static const String _appearanceActiveKey = 'skinAppearanceActive';

  final ValueNotifier<SkinId> activeSkinNotifier =
      ValueNotifier<SkinId>(SkinId.classic);

  /// Fires whenever the Skin's status as the *active appearance* changes
  /// (independent of which skin is selected or its remaining time). `true`
  /// means the Skin should currently be rendered instead of the active
  /// Premium Theme.
  final ValueNotifier<bool> skinAppearanceActiveNotifier =
      ValueNotifier<bool>(false);

  bool _initialized = false;
  SharedPreferences? _prefs;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Restores the persisted skin selection and appearance flag.
  ///
  /// Performs **at most one Firestore read**, and only when a non-classic
  /// skin was previously selected on this device (to verify it hasn't
  /// expired since the app was last closed). If [SkinId.classic] was
  /// selected — the common case — this does zero Firestore reads.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Re-check expiry every time the app returns to the foreground, so an
    // expired skin cannot stay equipped across a backgrounded session.
    // Registered before the early return below so it is always active,
    // including when Classic is the saved selection (the user may equip a
    // skin later in the same session). Mirrors ConnectivityService, which
    // also registers its own observer from its start method.
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    final savedId = SkinId.fromId(prefs.getString(_activeSkinKey));
    final wantsSkinAppearance = prefs.getBool(_appearanceActiveKey) ?? true;

    if (savedId == SkinId.classic) {
      activeSkinNotifier.value = SkinId.classic;
      skinAppearanceActiveNotifier.value = false;
      return;
    }

    final stillValid = await hasAccess(savedId);
    if (stillValid) {
      activeSkinNotifier.value = savedId;
      skinAppearanceActiveNotifier.value = wantsSkinAppearance;
    } else {
      // Expired while the app was closed -> revert.
      activeSkinNotifier.value = SkinId.classic;
      skinAppearanceActiveNotifier.value = false;
      await _persistActiveSkin(SkinId.classic);
      await _persistAppearanceActive(false);
    }
  }

  // ── Catalog / lookup ─────────────────────────────────────────────────

  /// All skins defined in the catalog (Phase 1: unfiltered — no level or
  /// membership gating yet).
  List<SkinData> getAvailableSkins() => SkinCatalog.all;

  /// The currently selected skin's id (may or may not currently be the
  /// active *appearance* — see [isSkinAppearanceActive]).
  SkinId getCurrentActiveSkin() => activeSkinNotifier.value;

  /// The currently selected skin's catalog metadata.
  SkinData getActiveSkinData() => SkinCatalog.getById(activeSkinNotifier.value);

  // ── Access checks ────────────────────────────────────────────────────

  /// Whether the current user currently has access to [skin] — i.e. it is
  /// either the always-free default skin, or an unexpired unlock exists in
  /// Firestore. Performs one on-demand Firestore read for non-classic
  /// skins (no listener, no caching — matches the existing
  /// `PlanShopService.isPlanUnlocked`/`CoinService.getCurrentBalance`
  /// precedent of a plain on-demand `.get()` for this kind of check).
  Future<bool> hasAccess(SkinId skin) async {
    if (skin == SkinId.classic) return true; // always free, permanent

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await _firestore
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_skinUnlocksSubcollection)
          .doc(skin.name)
          .get();

      if (!doc.exists) return false;
      final expiresAtRaw = doc.data()?['expiresAt'];
      if (expiresAtRaw is! Timestamp) return false;
      return expiresAtRaw.toDate().isAfter(DateTime.now());
    } catch (e) {
      debugPrint('SkinService.hasAccess: $e');
      return false;
    }
  }

  /// Batch-reads the expiry of every skin the user has ever unlocked in
  /// ONE Firestore query, instead of calling [hasAccess] once per skin in
  /// the catalog (which would be one round trip per skin — 4 separate
  /// reads today, more as the catalog grows). Intended for UI call sites
  /// that need to render every skin's state at once (e.g. a Shop grid).
  ///
  /// Returns a map of skin id -> expiry (including already-expired
  /// entries — callers should compare against `DateTime.now()` themselves,
  /// exactly like [hasAccess] does internally). [SkinId.classic] is never
  /// included since it has no expiry concept.
  Future<Map<SkinId, DateTime>> getAllUnlockExpiries() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    try {
      final snap = await _firestore
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_skinUnlocksSubcollection)
          .get();

      final result = <SkinId, DateTime>{};
      for (final doc in snap.docs) {
        final expiresAtRaw = doc.data()['expiresAt'];
        if (expiresAtRaw is Timestamp) {
          final skinId = SkinId.fromId(doc.id);
          if (skinId != SkinId.classic) {
            result[skinId] = expiresAtRaw.toDate();
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('SkinService.getAllUnlockExpiries: $e');
      return {};
    }
  }

  /// Remaining access time for [skin], or `null` if there is no active
  /// unlock (expired, never unlocked, or [skin] is the default).
  Future<Duration?> getRemainingTime(SkinId skin) async {
    if (skin == SkinId.classic) return null; // permanent, not time-limited

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_skinUnlocksSubcollection)
          .doc(skin.name)
          .get();

      if (!doc.exists) return null;
      final expiresAtRaw = doc.data()?['expiresAt'];
      if (expiresAtRaw is! Timestamp) return null;

      final expiresAt = expiresAtRaw.toDate();
      final remaining = expiresAt.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (e) {
      debugPrint('SkinService.getRemainingTime: $e');
      return null;
    }
  }

  // ── Activate / deactivate (device-local display state) ──────────────

  /// Makes [skin] the selected + active skin appearance.
  ///
  /// Requires [hasAccess] to be true for non-classic skins — returns
  /// `false` without changing any state if the user does not currently
  /// have access (e.g. it expired, or was never unlocked). [SkinId.classic]
  /// can always be activated.
  ///
  /// Activating [SkinId.classic] deliberately does NOT set the skin
  /// appearance as active — Classic has no distinct appearance to show, so
  /// the Premium Theme system continues to apply normally.
  Future<bool> activateSkin(SkinId skin) async {
    if (skin != SkinId.classic && !await hasAccess(skin)) {
      return false;
    }

    activeSkinNotifier.value = skin;
    await _persistActiveSkin(skin);

    final appearanceActive = skin != SkinId.classic;
    skinAppearanceActiveNotifier.value = appearanceActive;
    await _persistAppearanceActive(appearanceActive);
    return true;
  }

  /// Fully turns the skin system off: reverts the selected skin to
  /// [SkinId.classic] and deactivates the skin appearance.
  ///
  /// This is distinct from [suppressForTheme], which only hides the skin's
  /// appearance in favor of a Premium Theme while leaving the *selection*
  /// (and its remaining unlock time) untouched so it can be resumed later.
  /// [deactivateSkin] is a deliberate "turn this off" action — the skin's
  /// own unlock/expiry in Firestore is never affected either way.
  Future<void> deactivateSkin() async {
    activeSkinNotifier.value = SkinId.classic;
    await _persistActiveSkin(SkinId.classic);
    skinAppearanceActiveNotifier.value = false;
    await _persistAppearanceActive(false);
  }

  /// Re-checks skin expiry whenever the app returns to the foreground.
  ///
  /// This is what makes "an expired skin cannot remain equipped" hold during
  /// normal use: [initialize] covers the cold-start case, and this covers
  /// resume-after-background (by far the most common way a multi-day expiry
  /// is crossed). Costs at most one Firestore read per resume, and only
  /// while a non-classic skin is actually selected — [checkExpiry] returns
  /// immediately for Classic without touching Firestore.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkExpiry());
    }
  }

  /// Re-checks expiry and reverts to [SkinId.classic] if the selected skin's
  /// unlock window has elapsed. Wired to app-resume via
  /// [didChangeAppLifecycleState]; also safe to call manually.
  Future<void> checkExpiry() async {
    final current = activeSkinNotifier.value;
    if (current == SkinId.classic) return;

    if (!await hasAccess(current)) {
      activeSkinNotifier.value = SkinId.classic;
      await _persistActiveSkin(SkinId.classic);
      skinAppearanceActiveNotifier.value = false;
      await _persistAppearanceActive(false);
    }
  }

  // ── Skin vs Premium Theme mutual exclusivity — UNCHANGED behavior ────

  /// Whether the Skin is currently the active visual appearance (as opposed
  /// to a Premium Theme). Read this — not [activeSkinNotifier] alone — to
  /// decide whether to render the skin's UI.
  ///
  /// This is a synchronous snapshot; it is only refreshed by [initialize],
  /// [checkExpiry], or the mutual-exclusivity methods below. Prefer
  /// [isSkinAppearanceActiveNow] at decision points that must not act on
  /// stale state (e.g. right before showing the Skin/Theme conflict dialog).
  bool get isSkinAppearanceActive => skinAppearanceActiveNotifier.value;

  /// Whether the Skin is active AND still genuinely usable right now —
  /// re-validates expiry as a side effect (mirrors [checkExpiry]) rather
  /// than trusting a potentially-stale [skinAppearanceActiveNotifier] value.
  /// An expired skin is reverted to [SkinId.classic] and reported as not
  /// active, so it can never be surfaced as the reason to block a Premium
  /// Theme selection.
  Future<bool> isSkinAppearanceActiveNow() async {
    if (!skinAppearanceActiveNotifier.value) return false;
    return hasUsableSelectedSkin();
  }

  /// Whether the currently *selected* skin (if any) is still within its
  /// unlock window. Performs a fresh [hasAccess] check rather than trusting
  /// a potentially-stale [activeSkinNotifier] value; if the skin has
  /// expired, it is reverted to [SkinId.classic] as a side effect (mirroring
  /// [checkExpiry]) so an expired skin can never be reported as usable, and
  /// can therefore never be reactivated.
  Future<bool> hasUsableSelectedSkin() async {
    final skin = activeSkinNotifier.value;
    if (skin == SkinId.classic) return false;

    if (await hasAccess(skin)) return true;

    // Expired -> revert, exactly like checkExpiry().
    activeSkinNotifier.value = SkinId.classic;
    await _persistActiveSkin(SkinId.classic);
    skinAppearanceActiveNotifier.value = false;
    await _persistAppearanceActive(false);
    return false;
  }

  /// Switches the active appearance to the Premium Theme system.
  ///
  /// Does NOT touch the selected skin, its ownership, or its remaining
  /// unlock time in any way — only the "which one is active" flag changes.
  /// Call this when the user picks "Use Premium Theme" in the
  /// mutual-exclusivity dialog.
  Future<void> suppressForTheme() async {
    if (!skinAppearanceActiveNotifier.value) return; // already suppressed
    skinAppearanceActiveNotifier.value = false;
    await _persistAppearanceActive(false);
  }

  /// Switches the active appearance back to the currently selected skin, if
  /// it has not expired.
  ///
  /// Returns `true` if the skin is now active again. Returns `false` if the
  /// skin had expired in the meantime — in that case it cannot be
  /// reactivated and the Premium Theme remains the active appearance.
  Future<bool> resumeSkinAppearance() async {
    final usable = await hasUsableSelectedSkin();
    if (!usable) return false;

    skinAppearanceActiveNotifier.value = true;
    await _persistAppearanceActive(true);
    return true;
  }

  // ── Unlock: coins ────────────────────────────────────────────────────

  /// Purchases [skin] with coins, granting the catalog's
  /// `coinUnlockDuration` of access.
  ///
  /// Mirrors [ShopService.purchaseItem]'s exact transaction shape: coin
  /// balance is read, validated, and deducted in the SAME Firestore
  /// transaction as the unlock write, so the two can never desync (no
  /// scenario where coins are spent but no access is granted, or vice
  /// versa). Reuses the existing `hunters/{uid}.coins` field — no new coin
  /// system is introduced.
  ///
  /// Prevents duplicate/invalid purchases: fails with
  /// `error: 'already_unlocked'` (without touching coins) if the user
  /// already has unexpired access to [skin]; fails with
  /// `error: 'insufficient_coins'` if the balance is too low.
  ///
  /// On success, also activates the skin (see [activateSkin]) so the
  /// purchase is immediately reflected as the active appearance.
  Future<SkinPurchaseResult> purchaseSkinWithCoins(SkinId skin) async {
    if (skin == SkinId.classic) {
      return const SkinPurchaseResult(
        success: false,
        error: 'not_purchasable',
        message: 'The default skin is already free.',
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SkinPurchaseResult(
        success: false,
        error: 'unauthenticated',
        message: 'Please sign in to purchase this skin.',
      );
    }

    // Prevent duplicate purchases while an unexpired unlock already exists.
    if (await hasAccess(skin)) {
      return const SkinPurchaseResult(
        success: false,
        error: 'already_unlocked',
        message: 'You already have access to this skin.',
      );
    }

    final catalogEntry = SkinCatalog.getById(skin);
    final price = catalogEntry.coinPrice;
    final duration = catalogEntry.coinUnlockDuration;

    final hunterRef = _firestore.collection(_huntersCollection).doc(uid);
    final unlockRef = hunterRef.collection(_skinUnlocksSubcollection).doc(skin.name);

    try {
      final result = await _firestore.runTransaction<SkinPurchaseResult>((txn) async {
        final snap = await txn.get(hunterRef);
        final data = snap.data() ?? {};

        final currentCoins = (data['coins'] ?? 0) as int;
        if (currentCoins < price) {
          return const SkinPurchaseResult(
            success: false,
            error: 'insufficient_coins',
            message: 'Not enough coins to purchase this skin.',
          );
        }

        final now = DateTime.now();
        final expiresAt = now.add(duration);

        txn.update(hunterRef, {'coins': currentCoins - price});
        txn.set(unlockRef, {
          'skinId': skin.name,
          'source': 'coin',
          'unlockedAt': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });

        return SkinPurchaseResult(
          success: true,
          skinId: skin,
          expiresAt: expiresAt,
        );
      });

      if (result.success) {
        await activateSkin(skin);
      }
      return result;
    } catch (e) {
      debugPrint('SkinService.purchaseSkinWithCoins: $e');
      return const SkinPurchaseResult(
        success: false,
        error: 'firestore_error',
        message: 'Could not purchase this skin. Please try again.',
      );
    }
  }

  // ── Unlock: rewarded ad ──────────────────────────────────────────────

  /// Grants [skin] access for the catalog's `adUnlockDuration` (currently
  /// 7 days) after a rewarded ad has been successfully watched.
  ///
  /// ## Integration contract (Phase 1 — no ad UI is built here)
  /// This method does NOT show an ad and does NOT touch
  /// `RewardedAd`/`RewardedAdManager` in any way — a later phase's UI is
  /// expected to:
  /// 1. Own its own `RewardedAdManager` instance (mirroring
  ///    `ThemeGalleryScreen`'s existing pattern — no new/duplicate ad
  ///    system is created here).
  /// 2. Call `showAd(onRewardEarned: () => SkinService.instance
  ///    .grantAdUnlock(skin))`.
  /// 3. Only that `onRewardEarned` callback may call this method. If the ad
  ///    fails to load/show, or the user dismisses it before the reward
  ///    fires, this method must simply never be called — there is no
  ///    partial/fallback grant path.
  ///
  /// On success, also activates the skin (see [activateSkin]).
  Future<SkinPurchaseResult> grantAdUnlock(SkinId skin) async {
    if (skin == SkinId.classic) {
      return const SkinPurchaseResult(
        success: false,
        error: 'not_applicable',
        message: 'The default skin is already available.',
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const SkinPurchaseResult(
        success: false,
        error: 'unauthenticated',
        message: 'Please sign in to unlock this skin.',
      );
    }

    final duration = SkinCatalog.getById(skin).adUnlockDuration;
    final now = DateTime.now();
    final expiresAt = now.add(duration);

    // The reward grant itself: this write is the ONLY thing that determines
    // whether the ad unlock succeeded or failed. It must be isolated in its
    // own try/catch so that nothing which happens afterward can ever
    // overwrite a grant that has already durably succeeded.
    try {
      await _firestore
          .collection(_huntersCollection)
          .doc(uid)
          .collection(_skinUnlocksSubcollection)
          .doc(skin.name)
          .set({
        'skinId': skin.name,
        'source': 'ad',
        'unlockedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    } catch (e) {
      debugPrint('SkinService.grantAdUnlock: $e');
      return const SkinPurchaseResult(
        success: false,
        error: 'firestore_error',
        message: 'Could not unlock this skin. Please try again.',
      );
    }

    // The reward has been granted successfully at this point — everything
    // below is a best-effort UI convenience (auto-activating the skin as
    // the current appearance), NOT part of the reward itself.
    //
    // Root-cause note: activateSkin() re-verifies access via a fresh
    // hasAccess() Firestore read of the doc that was just written above. If
    // that immediate re-read ever hiccups (transient latency/cache timing),
    // it must NOT be reported back to the caller as "the reward failed" —
    // the unlock document already exists and is valid regardless. The user
    // can still equip the skin manually from the Shop if auto-activation
    // silently fails here.
    try {
      await activateSkin(skin);
    } catch (e) {
      debugPrint('SkinService.grantAdUnlock: auto-activation after a successful '
          'grant failed (non-fatal, reward already persisted): $e');
    }

    return SkinPurchaseResult(success: true, skinId: skin, expiresAt: expiresAt);
  }

  // ── Private persistence helpers (device-local) ──────────────────────

  Future<void> _persistActiveSkin(SkinId skin) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_activeSkinKey, skin.name);
  }

  Future<void> _persistAppearanceActive(bool active) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_appearanceActiveKey, active);
  }
}
