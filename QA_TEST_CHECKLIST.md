# Hunter Ascend — Production QA Test Checklist
## Achievement & Reward System (Post-Implementation Verification)

---

## Prerequisites

- [ ] `firebase deploy --only firestore:rules` completed (new `unlockedAchievements` subcollection rules deployed)
- [ ] `flutter analyze` reports zero errors
- [ ] Full release build compiles successfully
- [ ] Test device has GPS/location services available (for run/walk achievements)
- [ ] Test device has internet connectivity (Firestore writes required)
- [ ] Two test accounts available: one fresh (new user), one existing (upgrade scenario)

---

## SECTION A: Achievement System — Core Mechanics

### A1. First-time evaluation (new user)

| # | Test | Expected | Pass |
|---|---|---|---|
| 1 | Create a fresh account, complete onboarding (name, height, weight, specialization) | `hunter_awakened`, `first_login`, `profile_completed`, `choose_specialization` unlock automatically via background evaluation | [ ] |
| 2 | Check Firestore: `hunters/{uid}/unlockedAchievements/` | Documents exist for all 4 with `xpAwarded: true` | [ ] |
| 3 | Check hunter doc `xp` field | XP increased by sum of rewardXp (50+50+75+75 = 250 XP) | [ ] |
| 4 | Check hunter doc `level` field | Level unchanged (250 < 500 threshold) | [ ] |
| 5 | Open Achievements tab | All 4 show "unlocked" state with checkmark | [ ] |
| 6 | Verify NO "Achievement Unlocked" dialog floods on first login | Baseline pass silently adopts pre-existing state — no celebration dialogs | [ ] |

### A2. Existing user upgrade (already has stats, first time with new system)

| # | Test | Expected | Pass |
|---|---|---|---|
| 7 | Sign in with existing account that has level 25, 50 quests done, 10 duel wins | Background evaluation fires, claims all qualifying achievements | [ ] |
| 8 | Check Firestore: `unlockedAchievements/` subcollection | All qualifying achievement docs created with `xpAwarded: true` | [ ] |
| 9 | Verify XP was awarded for ALL qualifying achievements | Hunter doc `xp` increased correctly (sum of all rewardXp values for qualifying achievements) | [ ] |
| 10 | Verify level-up occurred if XP crossed 500 thresholds | `level` field updated correctly | [ ] |
| 11 | Verify level-up celebration dialog shows (if level changed) | MilestoneService queue fires level-up dialog(s) | [ ] |
| 12 | Verify achievement unlock dialogs show via MilestoneService queue | Dialogs appear sequentially (not all at once) | [ ] |

### A3. Duplicate prevention

| # | Test | Expected | Pass |
|---|---|---|---|
| 13 | After achievements are already claimed, kill and restart app | No new dialogs, no additional XP granted | [ ] |
| 14 | Open Achievements tab repeatedly | XP does not increase, no new Firestore docs created | [ ] |
| 15 | Sign in on a second device with same account | Already-claimed achievements show as unlocked, no re-grant | [ ] |
| 16 | Attempt to manually create a duplicate doc via Firestore console (simulate race) | Firestore rules reject with permission-denied | [ ] |

### A4. Persistence

| # | Test | Expected | Pass |
|---|---|---|---|
| 17 | Unlock an achievement, force-kill app, reopen | Achievement still shows as unlocked | [ ] |
| 18 | Unlock an achievement, uninstall app, reinstall, sign in | Achievement still shows as unlocked (Firestore-backed) | [ ] |
| 19 | Unlock an achievement on Device A, sign in on Device B | Achievement shows as unlocked on Device B | [ ] |

### A5. XP crash recovery

| # | Test | Expected | Pass |
|---|---|---|---|
| 20 | Simulate: create claim doc manually in Firestore with `xpAwarded: false` | On next app launch/evaluation, XP is awarded and flag flipped to `true` | [ ] |
| 21 | After recovery, verify no duplicate XP on subsequent evaluations | XP stable, no additional grants | [ ] |

---

## SECTION B: Achievement Triggers — Individual Verification

### B1. Account achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 22 | `hunter_awakened` | Create account | Auto-unlocks (isDone always true) | [ ] |
| 23 | `first_login` | Sign in | Auto-unlocks (isDone always true) | [ ] |
| 24 | `profile_completed` | Set height > 0 AND weight > 0 | Unlocks after onboarding | [ ] |
| 25 | `choose_specialization` | Select any path (fatLoss/discipline/muscleGain/selfImprovement) | Unlocks after quest selection | [ ] |

### B2. Level achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 26 | `lvl_5` | Reach level 5 (via quest XP) | Unlock + 100 XP | [ ] |
| 27 | `lvl_10` | Reach level 10 | Unlock + 150 XP | [ ] |
| 28 | `lvl_25` | Reach level 25 | Unlock + 300 XP | [ ] |
| 29 | `lvl_50` | Reach level 50 | Unlock + 600 XP | [ ] |
| 30 | `lvl_75` | Reach level 75 | Unlock + 900 XP | [ ] |
| 31 | `lvl_100` | Reach level 100 | Unlock + 2000 XP + "Title: Monarch" | [ ] |

### B3. XP achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 32 | `xp_1k` | Accumulate 1000 total XP | Unlock + 100 XP | [ ] |
| 33 | `xp_5k` | Accumulate 5000 total XP | Unlock + 150 XP | [ ] |
| 34 | `xp_10k` | Accumulate 10000 total XP | Unlock + 300 XP | [ ] |
| 35 | `xp_25k` | Accumulate 25000 total XP | Unlock + 500 XP | [ ] |
| 36 | `xp_50k` | Accumulate 50000 total XP | Unlock + 800 XP | [ ] |
| 37 | `xp_100k` | Accumulate 100000 total XP | Unlock + 2000 XP + "Badge: Ascended" | [ ] |

### B4. Quest achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 38 | `q_1` | Complete 1 quest | Unlock + 50 XP, celebration dialog | [ ] |
| 39 | `q_10` | Complete 10th quest | Unlock + 150 XP | [ ] |
| 40 | `q_50` | Complete 50th quest | Unlock + 300 XP | [ ] |
| 41 | `q_100` | Complete 100th quest | Unlock + 500 XP | [ ] |
| 42 | `q_500` | Complete 500th quest | Unlock + 900 XP | [ ] |
| 43 | `q_1000` | Complete 1000th quest | Unlock + 2000 XP + "Title: Relentless" | [ ] |

### B5. Streak achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 44 | `streak_3` | Reach 3-day streak | Unlock + 75 XP | [ ] |
| 45 | `streak_7` | Reach 7-day streak | Unlock + 150 XP | [ ] |
| 46 | `streak_14` | Reach 14-day streak | Unlock + 300 XP | [ ] |
| 47 | `streak_30` | Reach 30-day streak | Unlock + 500 XP | [ ] |
| 48 | `streak_50` | Reach 50-day streak | Unlock + 800 XP + "Title: Iron Will" | [ ] |
| 49 | `streak_100` | Reach 100-day streak | Unlock + 1200 XP | [ ] |
| 50 | `streak_365` | Reach 365-day streak | Unlock + 3650 XP + "Border: Eternal Flame" | [ ] |
| 51 | `discipline_initiate` | Select discipline path | Unlock + 75 XP | [ ] |
| 52 | `perfect_discipline` | Hold 14-day streak on discipline path | Unlock + 700 XP | [ ] |

### B6. Duel achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 53 | `duel_first` | Complete 1 duel (win or loss) | Unlock + 75 XP | [ ] |
| 54 | `duel_first_win` | Win 1 duel | Unlock + 150 XP | [ ] |
| 55 | `duel_5` | Win 5 duels | Unlock + 300 XP | [ ] |
| 56 | `duel_25` | Win 25 duels | Unlock + 700 XP | [ ] |
| 57 | `duel_100` | Win 100 duels | Unlock + 2000 XP + "Title: Arena Legend" | [ ] |
| 58 | `duel_undefeated` | Win 10 duels with 0 losses | Unlock + 1500 XP + "Badge: Undefeated" | [ ] |

### B7. Body achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 59 | `body_first_update` | Log weight > 0 in Profile → Physique | Unlock + 75 XP, immediate dialog | [ ] |
| 60 | `body_lose_5` | Lose 5 kg from starting weight | Unlock + 400 XP | [ ] |
| 61 | `body_lose_10` | Lose 10 kg from starting weight | Unlock + 900 XP + "Badge: Transformed" | [ ] |
| 62 | `body_gain_muscle` | Gain 2 kg on muscle-gain path | Unlock + 700 XP | [ ] |
| 63 | `body_bmi_improved` | Weight drops below starting point (any amount) | Unlock + 300 XP | [ ] |

### B8. Hydration achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 64 | `hydration_expert` | Hit daily water goal (waterIntakeMl >= waterGoalMl) | Unlock + 200 XP | [ ] |
| 65 | `hydration_100` | Tap "Add Water" 100 times total (waterLogCount >= 100) | Unlock + 600 XP | [ ] |
| 66 | `hydration_streak` | Hit water goal 7 consecutive days (waterGoalStreak >= 7) | Unlock + 300 XP | [ ] |

### B9. Nutrition achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 67 | `nutri_first` | Log 1 meal in Calorie Tracker | Unlock + 75 XP, immediate dialog | [ ] |
| 68 | `nutri_100` | Log 100th meal | Unlock + 700 XP | [ ] |
| 69 | `nutri_protein` | Hit protein goal on 7 different days (proteinGoalHitDays >= 7) | Unlock + 300 XP | [ ] |
| 70 | `nutri_balanced` | Hit all macro targets (within 90%) on 1 day (balancedMacroDays >= 1) | Unlock + 300 XP | [ ] |

### B10. Walking/Explorer achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 71 | `walk_5` | Accumulate 5 km total run distance | Unlock + 100 XP | [ ] |
| 72 | `walk_25` | Accumulate 25 km total run distance | Unlock + 300 XP | [ ] |
| 73 | `walk_100` | Accumulate 100 km total run distance | Unlock + 700 XP | [ ] |
| 74 | `walk_500` | Accumulate 500 km total run distance | Unlock + 1500 XP + "Badge: Pathfinder" | [ ] |
| 75 | `walk_million` | Accumulate 1,000,000 total steps (totalStepsAllTime) | Unlock + 2000 XP + "Title: Millionaire" | [ ] |
| 76 | `explore_first` | Complete 1 run (save via map screen) | Unlock + 100 XP, immediate dialog | [ ] |
| 77 | `explore_10` | Complete 10 runs | Unlock + 300 XP | [ ] |
| 78 | `explore_100` | Complete 100 runs | Unlock + 800 XP | [ ] |
| 79 | `explore_longest` | Complete a single run > 10 km (longestRunKm >= 10) | Unlock + 1500 XP + "Badge: Adventurer" | [ ] |

### B11. Social achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 80 | `social_compare` | Open Compare Hunters screen from a public profile | Unlock + 75 XP, Firestore `hasComparedHunter: true` | [ ] |
| 81 | `social_share_profile` | Share stats card from Profile screen | Unlock + 100 XP, Firestore `hasSharedProfile: true` | [ ] |
| 82 | `social_share_report` | Share a progress report from Reports tab | Unlock + 150 XP, Firestore `hasSharedReport: true` | [ ] |
| 83 | `social_share_activity` | Share a run from the Map screen post-run dialog | Unlock + 150 XP, Firestore `hasSharedActivity: true` | [ ] |
| 84 | `social_invite` | Tap "Invite Friends" from Create Duel screen | Unlock + 400 XP + "Badge: Recruiter", Firestore `hasSharedApp: true` | [ ] |

### B12. Membership achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 85 | `member_pro` | Activate Pro membership (via rewarded ads) | Unlock + 300 XP | [ ] |
| 86 | `member_max` | Activate Max membership | Unlock + 700 XP + "Border: Max Aura" | [ ] |
| 87 | `member_support` | Any active membership (subscriptionActive or Pro/Max) | Unlock + 250 XP | [ ] |

### B13. Special achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 88 | `special_never_give_up` | Break a streak (previousStreak >= 3), then rebuild streak >= 1 | Unlock + 300 XP | [ ] |
| 89 | `special_perfect_week` | Reach 7-day streak | Unlock + 350 XP | [ ] |
| 90 | `special_perfect_month` | Reach 30-day streak | Unlock + 900 XP + "Badge: Flawless" | [ ] |

### B14. Hidden achievements

| # | Achievement | Trigger action | Expected result | Pass |
|---|---|---|---|---|
| 91 | `hidden_comeback` | previousStreak >= 7 AND streak >= 7 (break a 7+ streak, rebuild to 7) | Unlock + 1500 XP + "Title: Phoenix" | [ ] |
| 92 | `hidden_completionist` | Unlock every non-hidden achievement | Unlock + 2500 XP + "Border: Completionist" | [ ] |
| 93 | `hidden_secret_rank` | Reach level 600 (Ascend Legend rank) | Unlock + 2000 XP | [ ] |
| 94 | `hidden_midnight` | **DEFERRED** — predicate exists (`hitMidnightAction`), writer not wired | Shows as locked "???" | [ ] |
| 95 | `hidden_early_bird` | **DEFERRED** — predicate exists (`hitEarlyBirdAction`), writer not wired | Shows as locked "???" | [ ] |
| 96 | `hidden_night_owl` | **DEFERRED** — predicate exists (`hitNightOwlAction`), writer not wired | Shows as locked "???" | [ ] |

---

## SECTION C: Reward System (35 rewards)

### C1. Automatic unlock on rank-up

| # | Test | Expected | Pass |
|---|---|---|---|
| 97 | Reach level 10 (D Rank, tier 1) | `title_rising_hunter` and `border_bronze` auto-granted | [ ] |
| 98 | Check Firestore: `hunters/{uid}/rankRewards/title_rising_hunter` | Document exists with `grantedAt` timestamp | [ ] |
| 99 | Check Firestore: `hunters/{uid}/rankRewards/border_bronze` | Document exists with `grantedAt` timestamp | [ ] |
| 100 | Reward Unlock celebration dialog appears | One grouped dialog listing both rewards | [ ] |

### C2. Persistence

| # | Test | Expected | Pass |
|---|---|---|---|
| 101 | Force-kill app after reward granted, reopen | Reward still shows as owned | [ ] |
| 102 | Uninstall/reinstall, sign in | Reward still shows as owned | [ ] |
| 103 | Sign in on second device | Same rewards owned | [ ] |

### C3. Duplicate prevention

| # | Test | Expected | Pass |
|---|---|---|---|
| 104 | Trigger same rank-up evaluation twice (e.g., two app restarts) | No duplicate Firestore docs, same single `grantedAt` | [ ] |
| 105 | Attempt manual second `set()` via code for same reward ID | Firestore rules return permission-denied (create-only) | [ ] |

### C4. Equip / Unequip

| # | Test | Expected | Pass |
|---|---|---|---|
| 106 | Tap EQUIP on an owned reward | Button changes to UNEQUIP, checkmark appears, Firestore `equippedRewards/current` updated | [ ] |
| 107 | Tap UNEQUIP | Button reverts to EQUIP, checkmark removed, field deleted from Firestore doc | [ ] |
| 108 | Equip a title, then equip a different title | Previous title unequipped, new one equipped (one per type) | [ ] |
| 109 | Attempt to equip a locked reward (via modified client) | `EquippedRewardsService.equip` returns false, no write | [ ] |

### C5. UI refresh

| # | Test | Expected | Pass |
|---|---|---|---|
| 110 | Stay on Rewards tab, trigger a level-up that crosses a rank boundary (e.g., via quest completion on another tab returning to profile) | New rewards appear as "Owned" without closing/reopening the tab | [ ] |
| 111 | Equip/unequip a reward | Immediate visual update (no lag, no flicker) | [ ] |

### C6. Full reward ladder spot-check

| # | Tier | Rewards | Verify count | Pass |
|---|---|---|---|---|
| 112 | E (tier 0) | title_awakened, badge_e_rank | 2 owned on any account | [ ] |
| 113 | D (tier 1) | title_rising_hunter, border_bronze | 2 at level 10+ | [ ] |
| 114 | C (tier 2) | title_elite_hunter, badge_c_rank, report_style_field_report | 3 at level 20+ | [ ] |
| 115 | B (tier 3) | title_master_hunter, border_silver | 2 at level 35+ | [ ] |
| 116 | A (tier 4) | title_sovereign, badge_a_rank, aura_ember | 3 at level 50+ | [ ] |
| 117 | S (tier 5) | title_supreme_hunter, border_gold, dashboard_theme_supreme | 3 at level 70+ | [ ] |

---

## SECTION D: Edge Cases & Compatibility

### D1. Offline behavior

| # | Test | Expected | Pass |
|---|---|---|---|
| 118 | Put device in airplane mode, complete a quest | Quest completes locally; achievement evaluation queues but Firestore write fails gracefully (logged, no crash) | [ ] |
| 119 | Restore connectivity | Background evaluation retries; achievements that qualified while offline now claim and award XP | [ ] |
| 120 | Verify no duplicate XP after reconnect | Only one claim doc per achievement; `xpAwarded: true` set exactly once | [ ] |

### D2. Delete account compatibility

| # | Test | Expected | Pass |
|---|---|---|---|
| 121 | Delete account via Settings | `AchievementsService.clearCache()` called (no stale state), sign-out completes | [ ] |
| 122 | Create a new account after deletion | Fresh start — no achievements carried over, clean `unlockedAchievements/` subcollection | [ ] |

### D3. Firestore security rules

| # | Test | Expected | Pass |
|---|---|---|---|
| 123 | Attempt to read another user's `unlockedAchievements/` | Permission denied | [ ] |
| 124 | Attempt to update an existing achievement doc (change `achievementId` field) | Permission denied (only `xpAwarded` false→true allowed) | [ ] |
| 125 | Attempt to delete a claimed achievement doc where `xpAwarded: true` | Permission denied | [ ] |
| 126 | Attempt to delete a claimed achievement doc where `xpAwarded: false` | Allowed (crash-recovery rollback path) | [ ] |
| 127 | Attempt to create a doc in `rankRewards/` that already exists | Permission denied (create-only) | [ ] |

### D4. Performance

| # | Test | Expected | Pass |
|---|---|---|---|
| 128 | Monitor Firestore reads during normal app usage (dashboard, no actions) | Background evaluation fires only when hunter doc actually changes (not polling) | [ ] |
| 129 | Complete a quest — count Firestore writes | Quest write + achievement claim + xpAwarded update + XP award = ~4 writes max (acceptable) | [ ] |
| 130 | Step counter running for 10 minutes | `totalStepsAllTime` increments periodically (not on every single pedometer tick); achievement check fires only at 100k boundaries | [ ] |

### D5. UI correctness

| # | Test | Expected | Pass |
|---|---|---|---|
| 131 | Open Achievements tab — verify unlocked achievements show checkmark + colored medallion | Correct | [ ] |
| 132 | Locked achievements with progress > 0 show progress bar | Bar fills proportionally (e.g., 5/10 quests = 50%) | [ ] |
| 133 | Hidden locked achievements show "???" name and generic help icon | No name/icon leak | [ ] |
| 134 | Hidden UNLOCKED achievements show real name and icon | Secret revealed | [ ] |
| 135 | Reward pill on each achievement card shows "+XP" or reward title | Matches catalog `rewardXp`/`reward` values | [ ] |
| 136 | Rewards tab header shows correct "X of 35 unlocked" count | Matches actual owned count | [ ] |
| 137 | Achievements tab header shows correct "X of 75 unlocked" and "Y XP earned" | Matches actual data | [ ] |

---

## Summary

| Category | Total tests | Critical | Nice-to-have |
|---|---|---|---|
| Core mechanics (A) | 21 | 21 | 0 |
| Individual triggers (B) | 75 | 75 | 0 |
| Rewards (C) | 20 | 20 | 0 |
| Edge cases (D) | 20 | 14 | 6 (performance) |
| **Total** | **137** | **130** | **7** |

**Minimum viable QA:** pass all 130 critical tests before release.
**Full QA:** pass all 137 tests.

---

## Notes for QA team

1. **Time-based hidden achievements (94–96):** These are documented placeholders. They should display as locked "???". If they somehow unlock, that's a bug.
2. **High-level achievements (lvl_100, xp_100k, streak_365, q_1000, duel_100, walk_million, hidden_secret_rank, hidden_completionist):** These require significant play time. For QA, temporarily set the hunter doc values in Firestore console to just below the threshold, then trigger one more action to cross it.
3. **Firestore rule tests (123–127):** Use the Firebase Emulator Suite's rules playground or the Firestore console's "Rules playground" tab to simulate cross-user and disallowed-field writes without writing client code.
4. **After ALL tests pass:** Remove the temporary debug logging from `map_screen.dart` (the `[RunTrack]` tagged `debugPrint` statements from the earlier run-tracking fix — these are marked as temporary in code comments).
