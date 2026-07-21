# Hunter Ascend — Post-Release Audit Backlog

This document tracks findings from the final pre-release audit that are **not**
part of the first-release priority fix list. They are deferred intentionally —
none of them are release blockers on their own, and several require
architectural, Firestore-rules, or backend decisions that are explicitly out of
scope until after the first production release.

## Resolved this pass (not duplicated below)

- **Hive box name mismatch** — `lib/services/milestone_service.dart` now
  reads `CacheConstants.hunterBox` (typed `Hive.box<HunterData>`) instead of
  the hardcoded, never-opened `'hunter_box'` literal. The weight-goal
  milestone celebration can now actually fire.
- **Compare Hunters loading/error handling** —
  `lib/screens/leaderboard/compare_hunters_screen.dart` converted to a
  `StatefulWidget` holding its Firestore future in state. The `FutureBuilder`
  now handles `snapshot.hasError` (with a Retry button) and a
  missing/nonexistent hunter document, instead of only checking
  `!snapshot.hasData` and getting stuck on "Analyzing hunters..." forever.
- **Live Privacy Policy** — `PrivacyPolicyScreen` in
  `lib/screens/settings/settings_screen.dart` (the text actually reachable
  via Settings → Privacy Policy) now accurately describes location, camera,
  step/activity data, the AI proxy providers, the rewarded-ad membership
  model, and the real account-deletion retention behavior. The false
  Firebase Storage claim was removed.

## Explicitly out of scope this pass (left untouched, not resolved)

- `lib/screens/legal/legal_content.dart` and `legal_document_screen.dart`
  remain **unmodified**. They are dead code (not imported/navigated to
  anywhere in the app) and were intentionally left alone per explicit
  instruction — do not edit them without first deciding whether to wire them
  up or delete them (see H-4 below).
- Map screen distance-tracking bug — diagnostic `[RunTrack]` logging is in
  place (merged to `main`) but the root cause is still unconfirmed. No fix
  has been attempted. See "Open verification needed" below.

---

## Open verification needed (carried forward)

### Map screen distance-tracking bug — root cause not yet confirmed
**File:** `lib/screens/map/map_screen.dart`
The `[RunTrack]` diagnostic logging (position-stream callback counter,
accuracy-filter verdict, raw pre-filter distance, rejection-category
breakdown, and full `_isTracking`/`_isPaused`/`_distanceKm` state-transition
timeline) is in place. No real-device log output has been captured yet.
**Next step:** run a real session (Start → walk → Pause → Resume → walk →
Stop) and capture the `[RunTrack]` log output so the exact failing stage can
be identified before any fix is written. **Do not fix speculatively.**

---

## Backlog Item 1 — Android Gradle wrapper missing from a fresh clone
**Severity:** High
**Category:** Android release build / repository integrity
**File:** `android/.gitignore`, `android/gradle/wrapper/`
**Status:** Verified — `gradlew`, `gradlew.bat`, and `gradle-wrapper.jar` are
absent from disk and matched by `.gitignore` rules (`gradle-wrapper.jar`,
`/gradlew`, `/gradlew.bat`). Only `gradle-wrapper.properties` is tracked.
**Impact:** A fresh clone cannot run `./gradlew` for local or CI Android
builds.
**Fix:** Remove the wrapper bootstrap files from `.gitignore` and commit
`gradlew`, `gradlew.bat`, and `gradle-wrapper.jar`. Continue ignoring
`/.gradle`, `/captures/`, `local.properties`, and keystore files.
**Why deferred:** Low risk, but touches build tooling — bundling with other
build-config changes post-release avoids re-triggering CI/signing
verification twice.

---

## Critical — Firestore security rules (explicitly deferred: no rules redesign until after release)

### C-1. Unrestricted reads and schema-free owner writes on `/hunters/{userId}`
**File:** `firestore.rules:8-13`
Any authenticated user can read every hunter's profile. The owner can write
any field to any value with no schema/transition validation — including
`xp`, `level`, `membershipType`, `membershipExpiry`, streaks, and rewards.
**Deferred because:** Fixing this requires a Firestore rules redesign
(splitting public/private fields, adding field-level validation) and
likely a backend/Cloud Function for authoritative writes — both explicitly
out of scope for this pass.

### C-2. Unrestricted authenticated read/write on `/duels/{duelId}`
**File:** `firestore.rules:89-90`
Any signed-in user can read, modify, or complete any duel — not just
participants.
**Deferred because:** Requires rules redesign (participant-only access +
state-machine validation) — out of scope.

### C-3. Membership entitlement granted by unverifiable client writes
**Files:** `lib/services/membership_reward_service.dart`, `firestore.rules`,
`functions/index.js`
The client writes membership fields directly after a local rewarded-ad
callback, which is not proof of ad completion. The unused Cloud Function in
`functions/index.js` has no AdMob Server-Side Verification.
**Deferred because:** Requires a backend/SSV integration — explicitly a
backend change, out of scope.

---

## High — carried forward from the full audit

### H-1. Achievement XP can be duplicated after a crash between award and marker write
**File:** `lib/services/achievements_service.dart` (`_awardXpFor`, `_markPaid`)
XP award and the `xpAwarded: true` marker are two separate writes; a crash
between them causes the pending claim to be re-paid on the next evaluation.
**Deferred because:** Needs either an atomic write path or a server-side
ledger — architectural change.

### H-2. Duel completion can leave winner/loss stats partially updated
**File:** `lib/screens/duel/duel_screen.dart` (`updateDuelStats`)
Cross-user hunter-document writes are rejected by the owner-only update rule,
so only one participant's stat update can ever succeed per duel completion.
**Deferred because:** Requires either a rules change or moving the write to
a trusted backend — both out of scope.

### H-3. Onboarding completion recorded before specialization is persisted
**Files:** `lib/screens/auth/quest_selection_screen.dart`, `lib/main.dart`
App kill between the local "setup complete" flag and the Firestore path
write can leave a user permanently without their chosen specialization paths.
**Deferred because:** Requires reordering onboarding persistence and
migrating already-affected accounts — planned as a dedicated fix, not a
quick patch.

### H-4. Legal text — remaining gaps not touched this pass
- No Terms of Service screen is reachable anywhere in the app (the login
  screen references "Terms & Privacy Policy" as plain, non-tappable text).
- `lib/screens/legal/legal_content.dart` and `legal_document_screen.dart`
  are dead code — not wired into any navigation, and were **not edited**
  this pass (explicitly out of scope). They still contain stale/inaccurate
  text (e.g. a Google Play billing claim) that would need correcting if
  and when they are ever wired up.
- Two different support emails exist across legal text
  (`djdeveloper1202@gmail.com` in the live Privacy Policy vs.
  `hunterascendapp@gmail.com` in the dead `legal_content.dart`) — needs a
  decision on which is authoritative.
**Deferred because:** Adding a reachable Terms screen, or wiring/removing
the orphaned legal files, is navigation/architecture work — out of scope
until after release.

---

## Medium — carried forward from the full audit

- **`currentWeekId()` uses Gregorian year instead of ISO week-year**
  (`lib/core/utils/hunter_calculations.dart`) — weekly missions can
  regenerate prematurely around New Year.
- **Missions screen does not reload weekly missions at the Monday
  boundary** (`lib/screens/dashboard/missions_screen.dart`) — a
  long-open session can show/complete stale weekly missions.
- **App restart inflates lifetime step totals**
  (`lib/screens/dashboard/home_dashboard_screen.dart`) — the in-memory
  per-day watermark resets on restart, double-counting already-seen steps.
- **Sleep reward is device-global and consumed on failed XP writes**
  (`lib/services/sleep_service.dart`) — reward-date key isn't
  UID-scoped, and a failed XP transaction still marks the reward claimed.
- **Paused GPS travel can be credited; non-idempotent run save**
  (`lib/screens/map/map_screen.dart`) — pause doesn't reset the distance
  baseline; a retried save after a partial failure can duplicate a run
  and its XP/stat effects. (Do not touch until the Map bug investigation
  above concludes — they share the same file.)
- **Calorie tracker stream goes stale at midnight**
  (`lib/screens/nutrition/calorie_tracker_screen.dart`) — the
  date-scoped Firestore query is captured once in `initState` and never
  refreshed across the day boundary while the screen stays open.
- **Hive cache migration omits the leaderboard box**
  (`lib/data/hive_init.dart`) — `_deleteDataBoxes` doesn't close/delete
  the leaderboard box on a schema-breaking version bump.
- **Report service reads full historical weight/run data for a
  30-day report** (`lib/screens/profile/reports/services/report_service.dart`)
  — no server-side date/limit constraint on `weight_history`/`runs` queries.

## Low — carried forward from the full audit

- **Production logging includes precise GPS coordinates**
  (`lib/screens/map/map_screen.dart`) — `[RunTrack]` debug logs print raw
  lat/lng; should be removed or gated behind `kDebugMode` before final
  release (currently still needed for the open Map bug investigation above —
  remove only after that investigation concludes).
- **Max tier's "no rewarded ads" contract is inconsistently enforced**
  (`lib/screens/settings/theme_gallery_screen.dart`,
  `lib/screens/profile/membership_screen.dart`) — Theme Gallery and
  Membership extension flows still offer/require rewarded ads to Max users
  despite `MembershipFeatures.max.rewardedAds == false`.
- **Raw rewarded ads lack full-screen dismissal disposal callbacks**
  (`lib/screens/dashboard/home_dashboard_screen.dart`,
  `showStreakRecoveryAd`) — no `fullScreenContentCallback` to guarantee ad
  disposal.

---

## How to use this backlog

- Do not batch Critical items (C-1–C-3) with routine post-release patches —
  they require a deliberate Firestore-rules/backend design pass with its
  own review.
- Do not edit `lib/screens/legal/legal_content.dart` or
  `legal_document_screen.dart` until a decision is made on H-4 (wire up vs.
  delete) — they are intentionally left untouched.
- High/Medium/Low items can be triaged into normal sprint work once the
  first release has shipped.
- When an item is resolved, move it out of this file and note the fix
  commit/PR for traceability.
