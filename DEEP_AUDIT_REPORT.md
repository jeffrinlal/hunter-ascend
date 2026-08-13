# DEEP AUDIT REPORT — Hunter Ascend

**Date:** 2026-08-10
**Auditor:** Kiro AI (read-only, no code modifications)
**Commit:** `ef792cb` (main)
**Scope:** Full application — 80+ Dart files, Firestore rules, Cloud Functions, tests

---

## Executive Summary

| Metric | Count |
|--------|-------|
| Files/systems inspected | 80+ across lib/, firestore.rules, functions/, tests/ |
| **Critical findings** | **5** |
| **High findings** | **6** |
| **Medium findings** | **7** |
| **Low findings** | **4** |
| **Info observations** | **3** |
| Confirmed security vulnerabilities | 4 (all rooted in same rule gap) |
| Firestore cost concerns | 2 (duplicate listener, anti-pattern stream) |
| Most important architectural risk | `hunters/{userId}` has zero field-level validation — any authenticated owner can set coins, XP, level, membership, streak to arbitrary values via the Firestore SDK |

---

## Architecture Map

```
UI Layer
  MainShell (IndexedStack, 5 tabs)
    HomeDashboardScreen
    MissionsScreen
    GlobalRankingsScreen
    BattleHubScreen
    ProfileScreen
  + pushed screens: DuelScreen, DungeonPlayScreen, RivalryScreens, Shop, etc.

State / Services (singletons)
  XpService             — transactional XP/level writes
  CoinService           — transactional coin writes
  MembershipService     — tier detection + listener
  AchievementsService   — claim/award/evaluation
  RivalryService        — all rivalry Firestore access
  RankRewardService     — rank-up cosmetic grants
  EquippedRewardsService— cosmetic equip state
  ShopService           — shop purchase transactions
  RewardedAdManager     — per-screen ad lifecycle
  MissionEngine         — active quest timer state
  SleepService          — ambient audio
  ConnectivityService   — online/offline detection
  DungeonSessionManager — dungeon run state (local)
  DungeonDailyStore     — dungeon persistence (SharedPreferences)

Repositories (singletons, Firestore+Hive cache)
  HunterRepository      — hunters/{uid} live stream + Hive cache
  QuestRepository       — custom_quests stream + Hive cache
  WeightRepository      — weight_history stream + Hive cache
  CalorieRepository     — calorie_logs stream + Hive cache
  LeaderboardRepository — one-shot .get() + Hive TTL cache

Firestore Collections (10 + 4 subcollections)
  hunters/{uid}                     — profile, XP, level, coins, membership
    /rankRewards/{id}               — cosmetic rank grants (create-once)
    /unlockedAchievements/{id}      — achievement claims + XP flag
    /equippedRewards/current        — equipped cosmetics
    /planUnlocks/{planId}           — PDF plan unlocks
  hunterNames/{name}                — uniqueness reservation
  duel_requests/{id}                — PvP challenge inbox
  duels/{id}                        — active/completed duels
  rivalries/{pairId}                — rivalry lifecycle (NO RULES DEPLOYED)
  custom_quests/{id}                — user quests
  weight_history/{id}               — weight tracking
  runs/{id}                         — run logs
  calorie_logs/{id}                 — nutrition logs
  app_config/{id}                   — read-only config
  settings/{id}                     — read-only settings

External Services
  Firebase Auth (anonymous + Google)
  Google Mobile Ads (rewarded + banner)
  Cloudflare Worker (AI quest generation)
  Pedometer SDK (step counting)
```

---

## Confirmed Findings

### DA-001

**Severity:** 🔴 CRITICAL
**Title:** No field-level validation on `hunters/{userId}` — coins, XP, level, membership, streak all directly writable
**Status:** Confirmed

**Files:** `firestore.rules:9-17`
**Code path:** `match /hunters/{userId} { allow update: if request.auth != null && request.auth.uid == userId; }`
**Reproduce:** Any user with a valid Firebase Auth session can call `FirebaseFirestore.instance.collection('hunters').doc(myUid).update({'coins': 999999, 'level': 999, 'xp': 499, 'membershipType': 'max', 'membershipExpiry': Timestamp(...farFuture), 'streak': 9999})` directly via the Firestore SDK.
**What happens:** The write succeeds — the rule only checks `auth.uid == userId`, with zero field restrictions.
**Why:** Unlike `unlockedAchievements` (which restricts updates to `affectedKeys().hasOnly(['xpAwarded'])`), the top-level `hunters` doc has no `affectedKeys()`/`diff()` validation whatsoever.
**Impact:** Complete game economy bypass — infinite coins, max membership forever, fake level/rank, impossible streak. Affects leaderboard integrity, shop, achievements, profile display.
**Systems affected:** Coins, XP, Level, Membership, Streak, Leaderboard, Achievements, Profile, Shop
**Data/security impact:** 🔴 Any player with basic Firebase SDK knowledge can exploit this. No rooting/patching required — a web console with the user's ID token suffices.
**Firestore impact:** None (same write count)
**Recommended fix:** Add `affectedKeys().hasOnly([...])` validation per transition, or move all progression writes to Cloud Functions. The existing `functions/index.js` `claimMembershipReward` callable (with rate limiting) is already written but unused — wire it up.
**Regression risk:** High — every direct `.update()` in the app must be audited to ensure its fields are in the whitelist.

---

### DA-002

**Severity:** 🔴 CRITICAL
**Title:** `duels` collection rule is fully open — any authenticated user can read/write ANY duel
**Status:** Confirmed

**Files:** `firestore.rules:100-101`, `lib/screens/duel/duel_screen.dart`
**Code path:** `match /duels/{duelId} { allow read, write: if request.auth != null; }`
**Reproduce:** Any signed-in user can write to any duel document (set winner, manipulate scores, flip XP-awarded flags) using the Firestore SDK.
**What happens:** No participant check exists in rules OR client code before writing. Client relies entirely on "users only navigate to their own duels."
**Why:** The rule was intentionally left open (comment: "retained to avoid changing game flows... hardening it requires a dedicated participant-only mutation schema").
**Impact:** A malicious client can: set `winner` on any duel, flip `player1XpAwarded`/`player2XpAwarded` to trigger/block XP grants, overwrite `player1Score`/`player2Score`, or create fake duels.
**Systems affected:** Duels, XP (via `_applyDuelXpOnce`), `duelWins`/`duelLosses` stats, achievements
**Data/security impact:** 🔴 Arbitrary manipulation of other users' duel outcomes
**Recommended fix:** `allow read, write: if request.auth != null && request.auth.uid in resource.data.participants;` (with `request.resource.data.participants == resource.data.participants` on update to prevent participant mutation)
**Regression risk:** Medium — existing flows only write to docs where the user is a participant, so the restriction would not break them.

---

### DA-003

**Severity:** 🔴 CRITICAL
**Title:** `rivalries` collection has NO Firestore rules — entire Rivalry feature is non-functional in production
**Status:** Confirmed

**Files:** `firestore.rules` (no `match /rivalries` block exists), `lib/services/rivalry_service.dart`
**Code path:** Any read/write to `rivalries/{pairId}` is evaluated against the catch-all `match /{document=**} { allow read, write: if false; }` and denied.
**Reproduce:** Send a rival request from the app — SnackBar shows "Rivalries are not enabled yet. Please try again later."
**What happens:** Every `RivalryService` operation fails with `permission-denied`. The UI degrades gracefully (friendly messages, no crash) but the feature is completely inert.
**Why:** Rules were deliberately left for manual deployment (per the commit message) but have not been deployed.
**Impact:** The entire Rivalry system (request, accept, compare, result, XP reward, ad gate) is dead code in production.
**Systems affected:** Rivalries, Battle Hub Rivals card, nav badge (rival half)
**Recommended fix:** Deploy the field-level-restricted rules documented in the commit message of `ef792cb`.
**Regression risk:** Low — only the rivalry feature is affected; deploying rules enables it.

---

### DA-004

**Severity:** 🔴 CRITICAL
**Title:** `updateDuelStats()` cross-user write fails silently — `duelWins`/`duelLosses` never update for one side
**Status:** Confirmed

**Files:** `lib/screens/duel/duel_screen.dart:179-183`, `firestore.rules:14-15`
**Code path:** `_autoCompleteDuel()` → `updateDuelStats(duel, winnerUid)` → `.update({'duelWins': FieldValue.increment(1)})` on winner doc + `.update({'duelLosses': FieldValue.increment(1)})` on loser doc. One of these is always a cross-user write.
**Reproduce:** Complete any duel. Observe in Firestore that the non-local player's `duelWins` or `duelLosses` field is NOT incremented.
**What happens:** The cross-user write throws `permission-denied`, caught by the outer `try/catch` in `_autoCompleteDuel` (only `debugPrint`). The sequential `await` means if the first write (winner doc) fails, the second (loser doc) never executes.
**Why:** Commit `5b172fa` dropped the temporary cross-user exception from rules (which was labelled "temporary, will migrate to Cloud Functions"). The code comment (line 213) still claims the exception exists — stale/wrong.
**Impact:** `duelWins`/`duelLosses` counters are permanently inaccurate for at least one participant of every duel. This degrades: `duel_5`/`duel_25`/`duel_100`/`duel_undefeated` achievements, Compare Hunters WIN RATE, Rivalry Comparison WIN RATE display.
**Systems affected:** Duels, Achievements, Profile, Rivalry Comparison
**Recommended fix:** Move stat writes to a Cloud Function triggered on duel completion, or restore the narrow field-limited cross-user exception in rules.
**Regression risk:** Low (either fix is additive).

---

### DA-005

**Severity:** 🔴 CRITICAL
**Title:** Membership tier directly settable by client — rewarded-ad grant bypasses unused Cloud Function
**Status:** Confirmed

**Files:** `lib/services/membership_reward_service.dart:96-198`, `functions/index.js` (dead code), `firestore.rules:14-15`
**Code path:** `MembershipScreen._claimReward` → `MembershipRewardService.instance.claimReward(tier)` → `runTransaction` → `txn.update(docRef, {'membershipType': tier, 'membershipExpiry': ...})`.
**Reproduce:** Bypass the app UI entirely: `FirebaseFirestore.instance.collection('hunters').doc(myUid).update({'membershipType': 'max', 'membershipExpiry': Timestamp.fromDate(DateTime(2099, 1, 1))})`.
**What happens:** Write succeeds. User has permanent Max membership without watching any ad.
**Why:** The same DA-001 root cause. `functions/index.js` contains a proper `claimMembershipReward` callable (with `MIN_CLAIM_INTERVAL_MS` rate limiting), but `pubspec.yaml` has no `cloud_functions` dependency and no Dart code ever calls it.
**Impact:** Permanent premium features (ad-free experience, cosmetics, skins) without watching ads.
**Systems affected:** Membership, Ads revenue, Skins, Dashboard, Shop, Premium features
**Recommended fix:** Wire the existing `claimMembershipReward` Cloud Function into the Dart app, or add field-level rules restricting `membershipType`/`membershipExpiry` writes.
**Regression risk:** Medium — requires adding `cloud_functions` dependency and changing the grant path.

---

### DA-006

**Severity:** 🟠 HIGH
**Title:** XP-ladder achievements (`xp_1k` through `xp_100k`) permanently unreachable due to XP wrap
**Status:** Confirmed

**Files:** `lib/data/achievements_catalog.dart` (the `_xp()` factory), `lib/services/xp_service.dart:93-96`
**Code path:** `_xp()` creates achievements with `isDone: (h) => h.xp >= amount` where amounts are 1000, 5000, 10000, 50000, 100000. But `xp_service.dart` runs `while (curXp >= 500) { curXp -= 500; curLevel++; }` — so `xp` (the persisted field) NEVER exceeds 499.
**Reproduce:** Reach any level. Check `h.xp` — always 0-499. No XP-ladder achievement ever unlocks.
**What happens:** 6 achievements (with reward XP 100-2000 each) are permanently locked for all users regardless of progression.
**Why:** The achievement catalog uses the raw `xp` field (in-level remainder) instead of the monotonic total `(level-1)*500 + xp`.
**Impact:** Missing ~4500 XP worth of achievement rewards across 6 milestones, plus incomplete achievement lists visible to users.
**Systems affected:** Achievements, XP, Profile
**Recommended fix:** Change `_xp()` to use `(h.level - 1) * 500 + h.xp >= amount` (total lifetime XP).
**Regression risk:** Low — purely an evaluation predicate change. Once fixed, users who already passed the threshold will unlock immediately on next evaluation.

---

### DA-007

**Severity:** 🟠 HIGH
**Title:** Anonymous logout orphans 8+ Firestore collections — never cleaned up
**Status:** Confirmed

**Files:** `lib/screens/settings/settings_screen.dart:112-131`
**Code path:** `_handleLogout()` anonymous branch: deletes only `hunters/{uid}` doc + calls `user.delete()`. Does NOT invoke `AccountDeletionService`.
**Reproduce:** Create an anonymous account, complete quests/runs/log weight/claim achievements, then tap "Logout." Check Firestore for the deleted uid's `custom_quests`, `weight_history`, `runs`, `calorie_logs`, `hunterNames`, `rankRewards`, `equippedRewards`, `unlockedAchievements`.
**What happens:** All those documents remain permanently in Firestore — orphaned, unreachable, never cleaned up.
**Why:** The Google-account delete path calls the thorough `AccountDeletionService.deleteCurrentUserData()`, but the anonymous path was apparently intended to be simpler and only deletes the top-level hunter doc.
**Impact:** Accumulated orphaned data across all anonymous users who ever log out. Billable storage on Spark (free tier has limits). No user-facing impact but a growing data integrity issue.
**Systems affected:** Account lifecycle, Firestore storage
**Recommended fix:** Call `AccountDeletionService.deleteCurrentUserData(uid)` in the anonymous path too (it already handles `_ensureNoActiveDuels`).
**Regression risk:** Low — the service is idempotent and already handles missing docs gracefully.

---

### DA-008

**Severity:** 🟠 HIGH
**Title:** Duel XP flag rollback (`true→false→true`) creates a replay window for +100 XP
**Status:** Probable

**Files:** `lib/screens/duel/duel_screen.dart:262-268`
**Code path:** `_applyDuelXpOnce()` claims `playerNXpAwarded = true` in a transaction, then calls `XpService.awardXp()`. If the grant throws, the flag is rolled back (`duelRef.update({flagField: false})`), and `_duelXpHandled = false` allows retry.
**Reproduce:** Force an `awardXp` failure (e.g., kill network after the claim transaction commits but before XP lands), then reopen the duel — the flag is already rolled back, so a fresh claim+grant cycle runs.
**What happens:** Each failure-then-retry cycle grants another +100 XP (or -20 XP deduction for loser). In theory, repeated forced failures could award unlimited XP.
**Why:** The `true→false` rollback is the mechanism that allows retry — but it also allows replay. The newer `RivalryService.claimWinnerXp()` explicitly avoids this design, documenting it as dangerous.
**Impact:** Exploitable by a determined user who can reliably force the XP grant to fail after the flag claim succeeds. Difficult to trigger accidentally.
**Systems affected:** Duels, XP, Level, Leaderboard
**Recommended fix:** Make the flag write-once (no rollback) and retry the XP grant in-session (same design as `rivalry_service.dart`).
**Regression risk:** Low — the grant retry loop is additive code; removing the rollback is a deletion.

---

### DA-009

**Severity:** 🟠 HIGH
**Title:** Quest completion is 4 non-atomic Firestore operations — crash between them causes permanent state desync
**Status:** Confirmed

**Files:** `lib/screens/dashboard/missions_screen.dart:397-441`
**Code path:** `completeQuest()` sequentially: (1) `_dailyEngine.clearRun()` (deletes active-mission fields), (2) `XpService.awardXp()`, (3) `updateStreak()` (separate transaction), (4) `saveCompletedQuest()` (separate `.update()`).
**Reproduce:** Kill the app immediately after step 2 (XP awarded) but before step 3 (streak update).
**What happens:** XP is granted but streak never increments and `questsDone` never increments. The active mission is already cleared (step 1), so there's nothing to retry — the quest is gone from the UI.
**Why:** Unlike the achievement flow (which has a `_pendingXpAwardIds` retry mechanism), quest completion has no recovery/replay. The 4 steps are independently awaited, not wrapped in one transaction.
**Impact:** Silent loss of streak progress and `questsDone` count. Low frequency (requires precise crash timing) but unrecoverable when it happens.
**Systems affected:** Quests, Streak, Achievements (quest-count-based)
**Recommended fix:** Wrap streak + questsDone writes into the same transaction as `awardXp`, or implement a completion-journal pattern with retry on next launch.
**Regression risk:** Medium — combining into one transaction touches `xp_service.dart`'s signature.

---

### DA-010

**Severity:** 🟠 HIGH
**Title:** Dungeon rewards are entirely client-computed and client-trusted — no server validation
**Status:** Confirmed

**Files:** `lib/screens/dungeon/dungeon_session_manager.dart:305-360`, `lib/screens/dungeon/dungeon_rewards.dart:60-78`, `lib/services/xp_service.dart:47-141`
**Code path:** `claimClearReward()` computes `reward.xp`/`reward.coins` from client-bundled templates via a seeded RNG, then passes them directly to `XpService.awardXp(amount: reward.xp, dungeonScore: reward.xp, ...)`.
**Reproduce:** Patch the app or call `XpService.awardXp(amount: 99999, dungeonScore: 99999, ...)` directly.
**What happens:** The transaction accepts any `amount`/`dungeonScore`/`monstersDefeated`/`bossesDefeated`/`dungeonsCompleted` values — there's no server-side bound.
**Why:** The entire dungeon outcome is computed locally. `XpService`'s transaction trusts the caller-supplied amounts unconditionally.
**Impact:** A modified client can claim arbitrarily large dungeon XP/scores/stats per claim. Combined with DA-001's lack of field-level rules, this is fully exploitable.
**Systems affected:** Dungeons, XP, Level, Leaderboard (dungeonScore), Achievements (monster/boss/dungeon counts)
**Recommended fix:** Server-side validation of dungeon rewards (Cloud Function verifying session legitimacy), or at minimum, rule-level bounds on field increments per write.
**Regression risk:** High — adding server validation is a significant architectural change.

---

### DA-011

**Severity:** 🟠 HIGH
**Title:** Coin-earning ad flow (`_awardCoinsAfterAd`) has no idempotency guard against duplicate SDK reward callbacks
**Status:** Probable

**Files:** `lib/screens/shop/coin_shop_screen.dart:703-736`
**Code path:** `onRewardEarned: () { _awardCoinsAfterAd(amount); }` — `_awardCoinsAfterAd` directly calls `CoinService.instance.awardCoins(amount: amount)` with no idempotency key, flag, or deduplication.
**Reproduce:** If AdMob fires `onUserEarnedReward` twice for a single ad session (a known platform quirk on some devices/networks), coins are awarded twice.
**What happens:** +40/+100 coins instead of +20/+50 from a single ad watch.
**Why:** No ad-transaction-scoped idempotency key is stored/checked. The only guard is a same-tick `_isResponding` boolean for UI re-entry, which doesn't protect against sequential duplicate SDK callbacks.
**Impact:** Inflated coin balance. Low frequency (depends on ad network behavior) but real when it occurs.
**Systems affected:** Coins, Shop economy
**Recommended fix:** Add a per-ad-show nonce (e.g., store the timestamp of the last successful coin grant and reject a second grant within 5 seconds of the same session).
**Regression risk:** Low — additive guard.

---

### DA-012

**Severity:** 🟡 MEDIUM
**Title:** Dungeon daily reset uses device-local date — manipulable for unlimited re-clears
**Status:** Confirmed

**Files:** `lib/screens/dungeon/dungeon_daily_store.dart:53-54`
**Code path:** `static String get today => DateTime.now().toString().substring(0, 10);` — every "is this today's dungeon?" check uses this value.
**Reproduce:** Complete and claim a dungeon. Set device clock forward 1 day. Reopen app. The dungeon appears as a fresh, uncompleted dungeon for the "new" day.
**What happens:** Unlimited dungeon re-clears (each awarding XP + coins + `dungeonsCompleted` increment + leaderboard `dungeonScore`).
**Why:** No server-epoch anchor for dungeon state (unlike `XpService`'s `dailyResetEpoch` which uses UTC midnight). The dungeon system is entirely local.
**Impact:** Farmable XP/coins/leaderboard-score via clock manipulation. Exploitable by any user without app modification.
**Systems affected:** Dungeons, XP, Coins, Leaderboard, Achievements
**Recommended fix:** Anchor dungeon daily state to `dailyResetEpoch` (from the hunter doc, server-stamped) or add a `lastDungeonClaimDate` field written with `FieldValue.serverTimestamp()` and checked before granting.
**Regression risk:** Medium — requires changing the persistence model from purely-local to server-anchored.

---

### DA-013

**Severity:** 🟡 MEDIUM
**Title:** Streak manipulation via device clock changes
**Status:** Confirmed

**Files:** `lib/screens/dashboard/missions_screen.dart:443-465`
**Code path:** `updateStreak()` computes day difference from `lastQuestDate` (a local date string) vs `DateTime.now().toString().substring(0, 10)`. Setting clock forward 1 day makes `difference == 1` → streak increments.
**Reproduce:** Complete quest. Set clock +1 day. Complete another quest. Repeat.
**What happens:** Streak climbs indefinitely without waiting real days.
**Why:** No server timestamp validation. `lastQuestDate` is written as a client-computed string.
**Impact:** Artificially high streaks, affecting streak-based achievements and profile display.
**Systems affected:** Quests, Streak, Achievements, Profile
**Recommended fix:** Use `FieldValue.serverTimestamp()` for `lastQuestDate` writes and compare against the server-anchored `dailyResetEpoch`.
**Regression risk:** Low-medium — changes the date comparison logic.

---

### DA-014

**Severity:** 🟡 MEDIUM
**Title:** `RewardedAdManager` retry chain survives `dispose()` — leaked ad-load cycles
**Status:** Confirmed

**Files:** `lib/services/rewarded_ad_manager.dart:84-97`
**Code path:** `onAdFailedToLoad` → `Future.delayed(Duration(seconds: 2 * _loadFailures), loadAd)`. `dispose()` (line 155-158) only nulls `_rewardedAd` — does NOT cancel pending `Future.delayed` callbacks and has no `_disposed` flag.
**Reproduce:** Open a screen with a `RewardedAdManager`, trigger an ad load failure (airplane mode), then navigate away (popping the screen) before the retry fires.
**What happens:** The delayed `loadAd()` still fires after the screen is gone, calling `onAdStatusChanged` on the manager (which calls `if (mounted) setState(...)` — safe from crash but the ad SDK call + network request still execute uselessly). Up to 3 orphaned ad loads can fire per disposed manager.
**Why:** No cancellation mechanism for `Future.delayed` in Dart without storing and checking a flag.
**Impact:** Wasted network/SDK resources. Not a crash (callers guard with `mounted`), but a resource leak.
**Systems affected:** All screens using RewardedAdManager (6 screens)
**Recommended fix:** Add `bool _disposed = false;` field, set in `dispose()`, check at the top of `loadAd()`.
**Regression risk:** None — purely additive guard.

---

### DA-015

**Severity:** 🟡 MEDIUM
**Title:** `PublicHunterProfileScreen` recreates `.snapshots()` stream on every theme/tier notifier tick
**Status:** Confirmed

**Files:** `lib/screens/profile/public_hunter_profile_screen.dart:66-70`
**Code path:** The screen is a `StatelessWidget` with a `ListenableBuilder` wrapping `_themedBuild()`. Inside `_themedBuild`, a `StreamBuilder(stream: FirebaseFirestore...doc(hunterUid).snapshots(), ...)` constructs a NEW stream object on every rebuild.
**Reproduce:** Open any public profile. Toggle theme or change tier → the ListenableBuilder rebuilds, creating a new `.snapshots()` stream, causing StreamBuilder to cancel the old subscription and open a fresh one.
**What happens:** Unnecessary Firestore listener teardown/recreation on unrelated UI events. Each resubscription costs a document read.
**Why:** `StatelessWidget` has no `initState`/field to cache the stream. Should be `StatefulWidget` with `late final _stream`.
**Impact:** Extra reads (1 per theme/tier change while the screen is open). Not a leak (StreamBuilder disposes on pop) but wasteful.
**Systems affected:** Performance, Firestore cost
**Recommended fix:** Convert to `StatefulWidget`, cache the stream in a `late final` field.
**Regression risk:** None.

---

### DA-016

**Severity:** 🟡 MEDIUM
**Title:** Duplicate Firestore listener on `hunters/{uid}` — HunterRepository + MembershipService both subscribe
**Status:** Confirmed

**Files:** `lib/data/repositories/hunter_repository.dart:122`, `lib/services/membership_service.dart:393`
**Code path:** Both are singletons that call `.snapshots()` on `hunters/{uid}` independently. Both are permanent for the app's lifetime.
**Reproduce:** Sign in. Observe two active Firestore listeners on the same document in the Firebase console.
**What happens:** Every write to the hunter doc triggers TWO snapshot events, TWO Hive writes (HunterRepository), TWO membership-tier re-evaluations.
**Why:** `MembershipService` was implemented independently of `HunterRepository` and subscribes to the same doc for tier/expiry detection rather than consuming `HunterRepository.watch()`.
**Impact:** 2x read cost for every hunter-doc write. On Spark's free tier (50K reads/day), this doubles the baseline read consumption from the most-written document.
**Systems affected:** Performance, Firestore cost
**Recommended fix:** Have `MembershipService` consume `HunterRepository.watch()` broadcast stream instead of opening its own listener.
**Regression risk:** Low — `HunterRepository.watch()` already exposes a broadcast stream.

---

### DA-017

**Severity:** 🟡 MEDIUM
**Title:** Battle Hub shows stale Duel/Rivalry card state after app background/foreground
**Status:** Confirmed

**Files:** `lib/screens/battle/battle_hub_screen.dart`, entire `lib/` tree
**Code path:** `_loadDuelState()`/`_loadRivalryState()` are one-shot `.get()` reads fired only on `initState` and when `activeIndex` changes to the Battles tab. No `WidgetsBindingObserver`/`AppLifecycleState` handler exists anywhere in the app (confirmed via grep: zero matches for `AppLifecycleState`/`didChangeAppLifecycleState` across all of `lib/`).
**Reproduce:** Open app on Battles tab. Background app. Opponent accepts a duel request or rivalry expires. Foreground app. Card still shows old state.
**What happens:** Card state is stale until the user navigates away from and back to the Battles tab (or enters/exits a sub-screen via `_openAndRefresh`).
**Why:** IndexedStack keeps BattleHubScreen alive without re-triggering lifecycle methods on foreground. No lifecycle observer was ever added.
**Impact:** Users may not see incoming challenges or available results until they manually trigger a refresh. UX confusion, not data corruption.
**Systems affected:** Battle Hub, Duels, Rivalries
**Recommended fix:** Add `WidgetsBindingObserver` to `_BattleHubScreenState`, call `_loadHubState()` on `resumed`.
**Regression risk:** None.

---

### DA-018

**Severity:** 🟡 MEDIUM
**Title:** Dungeon claim-first-then-XP design can silently lose rewards on app kill
**Status:** Confirmed

**Files:** `lib/screens/dungeon/dungeon_session_manager.dart:305-360`
**Code path:** `claimClearReward()`: (1) sets local `rewardClaimed = true` + persists to SharedPreferences, (2) calls `XpService.awardXp(...)`, (3) on null result, rolls back. If the app is killed AFTER step 1 persists but BEFORE step 2's Firestore transaction commits or is evaluated...
**Reproduce:** Kill the app process immediately after the SharedPreferences write in step 1 lands but before the Firestore round-trip for `awardXp` completes.
**What happens:** On restart, `rewardClaimed = true` is read from SharedPreferences → the claim button is gone → XP/coins were never actually written to Firestore. The reward is silently lost, not retried.
**Why:** The rollback (step 3) only fires if `awardXp` returns `null` within the same session. If the session is terminated, the rollback never runs.
**Impact:** Rare (narrow timing window), but unrecoverable when it happens — the user loses their dungeon reward permanently.
**Systems affected:** Dungeons, XP, Coins
**Recommended fix:** Write `xpAwarded: false` alongside `rewardClaimed: true` in the local store, and on next launch, retry `awardXp` if `rewardClaimed && !xpAwarded`.
**Regression risk:** Low — additive retry logic.

---

### DA-019

**Severity:** 🔵 LOW
**Title:** Rival search debounce cancels timer but not in-flight Firestore query — stale-result race
**Status:** Confirmed

**Files:** `lib/screens/battle/rival_search_screen.dart:63-105`
**Code path:** `_searchTimer?.cancel()` cancels the pending debounce timer, but if a previous timer already fired and its `.get()` is in-flight, nothing cancels that network call. A slow response from an older query can overwrite a newer query's result.
**Reproduce:** Type "Al" (fires query A on slow network), quickly continue to "Alex" (fires query B). If A's response arrives after B's, the UI shows results for "Al" while displaying "Alex" in the search box.
**What happens:** Wrong search results displayed.
**Why:** No request-generation counter or cancellation token for in-flight Firestore queries.
**Impact:** Brief incorrect results in the rival search UI. Requires unlucky network timing.
**Systems affected:** Rival Search UX
**Recommended fix:** Add an `int _searchGeneration` counter; increment on each new search; ignore results from stale generations.
**Regression risk:** None.

---

### DA-020

**Severity:** 🔵 LOW
**Title:** SharedPreferences keys not namespaced by UID — leak between accounts on same device
**Status:** Confirmed

**Files:** `lib/screens/auth/quest_selection_screen.dart` (`hasCompletedSetup`), `lib/services/user_activity_service.dart` (`lastActiveDateUtc`)
**Code path:** These keys are written without a UID prefix and never cleared on logout/delete.
**Reproduce:** User A completes onboarding. Logs out. User B signs in on same device. `hasCompletedSetup` is still `true` from user A.
**What happens:** Benign — the actual onboarding gate is the Firestore `onboardingComplete` field (read fresh per UID). `hasCompletedSetup` is only used as a minor optimization flag. `lastActiveDateUtc` could cause a new account's "mark active today" to be skipped on its first day if it matches.
**Impact:** Negligible. No security or data integrity issue.
**Systems affected:** Account lifecycle (cosmetic only)
**Recommended fix:** Prefix keys with UID or clear all SharedPreferences on logout.
**Regression risk:** None.

---

### DA-021

**Severity:** 🔵 LOW
**Title:** `CalorieRepository` listener is never torn down once started
**Status:** Confirmed

**Files:** `lib/data/repositories/calorie_repository.dart:205`
**Code path:** `.snapshots()` listener is created when Nutrition/CalorieTracker is first opened. `dispose()` exists but is never called (grep confirms zero call sites for `CalorieRepository.instance.dispose()`).
**Reproduce:** Open Nutrition once, then navigate away. The listener persists for the entire app session.
**What happens:** Permanent listener on `calorie_logs` even after leaving the nutrition section.
**Why:** Singleton repository pattern — designed to live for app lifetime, like `HunterRepository`.
**Impact:** Minor unnecessary reads if calorie_logs are written externally (which doesn't happen in practice since it's single-user data). Consistent with the app's singleton-repository design.
**Systems affected:** Firestore cost (marginal)
**Recommended fix:** Accept as-designed (consistent with other repositories) or add lazy teardown with a usage counter.
**Regression risk:** N/A — cosmetic.

---

### DA-022

**Severity:** 🔵 LOW
**Title:** MembershipRewardService Pro/Max grant is vulnerable to sequential duplicate ad callbacks
**Status:** Probable

**Files:** `lib/services/membership_reward_service.dart:96-198`
**Code path:** `isClaiming.value` guards concurrent (same-tick) re-entry, but if AdMob fires `onUserEarnedReward` twice sequentially (first call completes + resets `isClaiming`, then second fires), the transaction runs again and extends membership by another day.
**Reproduce:** Requires the ad network to fire the reward callback twice for one ad (platform quirk, not reliably reproducible).
**What happens:** +2 days of membership from a single ad instead of +1.
**Impact:** Minor (1 extra day of membership). Very low frequency.
**Systems affected:** Membership, Ads
**Recommended fix:** Store the timestamp of the last successful claim; reject a second claim within N seconds.
**Regression risk:** None.

---

### DA-023

**Severity:** ⚪ INFO
**Title:** `functions/index.js` `claimMembershipReward` is dead code — never called from the Flutter app
**Status:** Confirmed

**Files:** `functions/index.js`, `pubspec.yaml` (no `cloud_functions` dep)
**Notes:** A well-written Cloud Function with rate limiting exists but is entirely unused. This represents a missed security hardening opportunity. The function's logic (MIN_CLAIM_INTERVAL_MS, membership-tier progression, expiry extension) is properly implemented server-side but the client bypasses it entirely with a direct Firestore transaction.

---

### DA-024

**Severity:** ⚪ INFO
**Title:** `hunter_data.g.dart` field count comment says "79" but actual fields span to HiveField(80)
**Status:** Confirmed

**Files:** `lib/data/models/hunter_data.g.dart`
**Notes:** The `writeByte(79)` in the Hive adapter's `write()` method is likely an off-by-one in a comment/count, not a functional bug — Hive's binary format uses field-index pairs (not positional), so the count byte doesn't gate field serialization. No data loss occurs.

---

### DA-025

**Severity:** ⚪ INFO
**Title:** No `AppLifecycleState` observer exists anywhere in the app
**Status:** Confirmed

**Notes:** Grep for `AppLifecycleState`/`WidgetsBindingObserver`/`didChangeAppLifecycleState` across all `lib/` returns zero results. This means no screen in the app reacts to background/foreground transitions. The only impact identified is DA-017 (stale Battle Hub), but the absence is noted as a broader architectural observation — any feature that depends on "refresh when app returns to foreground" (e.g., checking if a rivalry expired while backgrounded) has the same limitation.

---

## Security Findings Summary

| ID | Severity | Root Cause | Exploit Type |
|---|---|---|---|
| DA-001 | 🔴 | No field-level rules on `hunters/{uid}` | Direct SDK write |
| DA-002 | 🔴 | Open `duels` rule, no participant check | Direct SDK write |
| DA-005 | 🔴 | Same as DA-001, specific to membership | Direct SDK write |
| DA-004 | 🔴 | Cross-user write blocked by rules, code doesn't handle | Silent data loss |
| DA-010 | 🟠 | Client-trusted dungeon rewards | Modified client |
| DA-012 | 🟡 | Client-trusted device clock for daily reset | Clock manipulation |
| DA-013 | 🟡 | Client-trusted device clock for streak | Clock manipulation |

**Common theme:** The app trusts the client for ALL progression writes. Firestore rules act only as an authentication layer (`uid == userId`), never as a business-logic validator. Every field on the hunter document, every duel document, and every dungeon outcome is exploitable by a modified client or direct SDK call.

---

## Firestore & Cost Analysis

### Listeners (permanent, active once MainShell mounts)

| # | Collection/Doc | Source | Notes |
|---|---|---|---|
| 1 | `hunters/{uid}` | HunterRepository | Primary profile stream |
| 2 | `hunters/{uid}` | MembershipService | **DUPLICATE** of #1 |
| 3 | `custom_quests where uid==` | QuestRepository | Missions tab |
| 4 | `weight_history where uid==` | WeightRepository | Profile tab |
| 5 | `duel_requests where toUid== && status=='pending' limit(1)` | MainShell | Badge |
| 6 | `rivalries where toUid== && status=='pending' limit(1)` | MainShell | Badge |
| 7* | `calorie_logs where uid==` | CalorieRepository | *Only after Nutrition opened once* |

**Total:** 6 permanent (7 once Nutrition visited). Listener #2 is the only confirmed waste.

### Per-operation costs (key flows)

| Operation | Reads | Writes |
|---|---|---|
| Complete a quest | 2 (txn read + streak txn read) | 3 (XP txn + streak txn + questsDone update) |
| Open leaderboard tab | 1 query (20-30 docs, cached 5min) | 0 |
| Open public profile | 1 doc (stream, but recreated on theme tick) | 0 |
| Claim dungeon reward | 2 (XP txn read + coin txn read) | 2 (XP txn write + coin txn write) |
| Send rivalry request | 3 (sender check + target check + existing doc) | 1 |
| Accept rivalry | 4 (both hunters + self-check + txn re-read) | 1 |
| Finalize rivalry | 4 (both hunters + rivalry txn re-read) | 1 |

---

## Race Conditions & Data Integrity

| ID | Type | Severity | Protection |
|---|---|---|---|
| DA-008 | Duel XP replay via flag rollback | 🟠 | Probable (requires forced failure) |
| DA-009 | Quest completion partial writes | 🟠 | None — no recovery mechanism |
| DA-011 | Coin double-grant on duplicate ad callback | 🟠 | Only same-tick concurrency guard |
| DA-018 | Dungeon reward loss on app kill | 🟡 | Narrow window, unrecoverable |
| DA-019 | Rival search stale results | 🔵 | None — needs unlucky timing |

---

## Performance Findings

| ID | Issue | Impact |
|---|---|---|
| DA-015 | Profile screen stream recreation | Extra reads per theme tick |
| DA-016 | Duplicate hunter doc listener | 2x baseline read cost |
| DA-014 | RewardedAdManager orphaned retries | Wasted network/SDK calls |

---

## Cross-System Regression Findings

| Systems | Issue | Root Cause |
|---|---|---|
| Achievements ↔ XP | 6 XP-ladder achievements permanently locked | Catalog reads wrapping `xp` field instead of total |
| Duels ↔ Profile ↔ Achievements | `duelWins`/`duelLosses` never update for one side | Cross-user write blocked by rules |
| Dungeons ↔ Leaderboard ↔ XP | Unlimited re-clears via clock | No server date anchor |
| Rivalries ↔ Everything | Entire feature dead | No rules deployed |
| Anonymous Accounts ↔ Firestore | Orphaned data | Logout skips full cleanup |
| BattleHub ↔ Duels/Rivalries ↔ Lifecycle | Stale cards | No foreground observer |

---

## Positive Findings

The following systems were thoroughly investigated and found to be **correctly implemented**:

1. **Achievement claim exactly-once guarantee** — Firestore `create`-once semantics on `unlockedAchievements/{id}` + rules permitting `update` only for `xpAwarded` flip + client rollback logic that matches rules exactly. Structurally sound.
2. **XpService transaction** — properly serialized via Firestore transaction, lazy daily/weekly reset inside the same txn, level-up math correct, no two-caller race possible.
3. **Rivalry winner XP claim** (`claimWinnerXp`) — write-once `xpAwarded` flag with no rollback, explicitly documented tradeoff (rare loss > duplication). Best-in-class among the app's exactly-once patterns.
4. **Rivalry loser ad gate** — genuinely idempotent (`arrayRemove` + structural unreachability after settlement). Cannot be bypassed via double-fire, rebuild, or restart.
5. **LeaderboardRepository** — one-shot `.get()` with TTL cache, no live listener, no fan-out cost. Correctly designed for a read-heavy leaderboard.
6. **All widget-owned Timers** — every `Timer`/`Timer.periodic` in widget code is cancelled in `dispose()`. No leaked periodic timers calling setState on disposed widgets.
7. **IndexedStack navigation** — tabs built once, kept alive correctly. `ValueNotifier`-based refresh signals fire exactly once per genuine tab switch (dual guards prevent redundancy).
8. **Dungeon corruption handling** — `DungeonDailyStore` wraps JSON parsing in try/catch, returns a `_corrupted` sentinel, blocks further writes, and runs an in-memory fallback. Defensively coded.
9. **AccountDeletionService (Google path)** — thorough, idempotent, best-effort per sub-operation, blocks on active duels, retains awarded achievements for the resurrection edge case, and the retained-achievements design is logically sound.
10. **RankRewards subcollection** — structurally prevents re-granting via `allow update: if false` + stable document IDs. No exploit found.
11. **Shop purchases** — atomic single-transaction design (deduct coins AND grant item in one write). No split-write risk.

---

## Top 10 Priority Fixes

| Priority | ID | Title | Category |
|---|---|---|---|
| 1 | DA-001 | Field-level rules on `hunters/{userId}` | Security |
| 2 | DA-002 | Participant-scoped `duels` rule | Security |
| 3 | DA-003 | Deploy `rivalries` rules | Security / Feature |
| 4 | DA-005 | Wire existing Cloud Function for membership | Security |
| 5 | DA-004 | Fix duelWins/duelLosses cross-user write | Data Integrity |
| 6 | DA-006 | Fix XP-ladder achievement predicate | Data Integrity |
| 7 | DA-010 | Server-validate dungeon rewards | Security |
| 8 | DA-012 | Server-anchor dungeon daily reset | Security |
| 9 | DA-009 | Atomic quest completion | Data Integrity |
| 10 | DA-016 | Eliminate duplicate hunter listener | Performance |

---

## Recommended Fix Order

### Phase 1 — Critical Security (deploy immediately, no app update required)
- **DA-003**: Deploy rivalry rules (documented in commit `ef792cb`)
- **DA-002**: Add participant check to `duels` rule
- **DA-001**: Add `affectedKeys()` restrictions to `hunters/{userId}` update rule (requires auditing every `.update()` call site to whitelist fields)

### Phase 2 — High Priority (app update required)
- **DA-005**: Wire `claimMembershipReward` Cloud Function (already exists in `functions/index.js`)
- **DA-004**: Move `updateDuelStats` to a Cloud Function or restore narrow rule exception
- **DA-006**: Fix `_xp()` achievement predicate to use total XP
- **DA-007**: Call `AccountDeletionService` for anonymous logout path
- **DA-008**: Remove XP flag rollback in `_applyDuelXpOnce`, adopt write-once pattern

### Phase 3 — Medium Priority
- **DA-012**: Server-anchor dungeon daily state
- **DA-013**: Server-anchor streak date
- **DA-009**: Atomic quest completion (combine into single transaction)
- **DA-017**: Add `WidgetsBindingObserver` to BattleHubScreen
- **DA-014**: Add `_disposed` flag to `RewardedAdManager`
- **DA-018**: Add dungeon reward retry-on-next-launch

### Phase 4 — Low Priority / Cleanup
- **DA-015**: Convert `PublicHunterProfileScreen` to StatefulWidget
- **DA-016**: Have `MembershipService` consume `HunterRepository.watch()`
- **DA-011**: Add per-ad-show nonce for coin grants
- **DA-019**: Add search-generation counter to rival search
- **DA-020**: Namespace SharedPreferences keys by UID
- **DA-021**: Accept CalorieRepository listener as-designed
- **DA-022**: Add claim-timestamp guard for membership

---

*End of audit report.*
