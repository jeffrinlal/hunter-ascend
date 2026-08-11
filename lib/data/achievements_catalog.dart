import 'package:flutter/material.dart';
import 'package:hunter_ascend/data/models/achievement.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';

// ── Derived-stat helpers (read-only from HunterData) ────────────────────────
bool _hasSpec(HunterData h) => h.fatLoss || h.discipline || h.muscleGain || h.selfImprovement;
double _weightLost(HunterData h) => h.startingWeight > 0 ? (h.startingWeight - h.weight) : 0.0;
String _tier(HunterData h) => (h.membershipType ?? '').toLowerCase();
bool _isPro(HunterData h) => _tier(h) == 'pro' || _tier(h) == 'max';
bool _isMax(HunterData h) => _tier(h) == 'max';
int _duelTotal(HunterData h) => h.duelWins + h.duelLosses;

/// The master list of achievements. Every entry below is backed by real,
/// already-written `HunterData` fields — there are no `_todo()`/always-false
/// placeholder predicates left in this catalog; every achievement is
/// obtainable through a genuine trigger site (see AchievementsService for
/// wiring and each screen's corresponding write for where the backing field
/// is actually set).
final List<Achievement> kAchievements = [
  // ══════════════ ACCOUNT ══════════════
  Achievement(
    id: 'hunter_awakened',
    name: 'Hunter Awakened',
    description: 'Accept the System and begin your journey.',
    icon: Icons.flash_on_rounded,
    category: AchievementCategory.account,
    rarity: AchievementRarity.common,
    rewardXp: 50,
    isDone: (h) => true,
  ),
  Achievement(
    id: 'first_login',
    name: 'First Login',
    description: 'Enter Hunter Ascend for the first time.',
    icon: Icons.login_rounded,
    category: AchievementCategory.account,
    rarity: AchievementRarity.common,
    rewardXp: 50,
    isDone: (h) => true,
  ),
  Achievement(
    id: 'profile_completed',
    name: 'Profile Completed',
    description: 'Set your height and weight.',
    icon: Icons.assignment_turned_in_rounded,
    category: AchievementCategory.account,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => h.height > 0 && h.weight > 0,
  ),
  Achievement(
    id: 'choose_specialization',
    name: 'Choose a Specialization',
    description: 'Pick your hunter path.',
    icon: Icons.route_rounded,
    category: AchievementCategory.account,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: _hasSpec,
  ),

  // ══════════════ PROGRESS — Level ══════════════
  _level('lvl_5', 'Rising Hunter', 5, AchievementRarity.common, 100),
  _level('lvl_10', 'Seasoned Hunter', 10, AchievementRarity.common, 150),
  _level('lvl_25', 'Elite Hunter', 25, AchievementRarity.rare, 300),
  _level('lvl_50', 'Master Hunter', 50, AchievementRarity.epic, 600),
  _level('lvl_75', 'Grandmaster Hunter', 75, AchievementRarity.epic, 900),
  _level('lvl_100', 'The Monarch', 100, AchievementRarity.legendary, 2000, reward: 'Title: Monarch'),

  // ══════════════ PROGRESS — XP ══════════════
  _xp('xp_1k', 'Spark', 1000, AchievementRarity.common, 100),
  _xp('xp_5k', 'Ember', 5000, AchievementRarity.common, 150),
  _xp('xp_10k', 'Blaze', 10000, AchievementRarity.rare, 300),
  _xp('xp_25k', 'Inferno', 25000, AchievementRarity.rare, 500),
  _xp('xp_50k', 'Supernova', 50000, AchievementRarity.epic, 800),
  _xp('xp_100k', 'Ascended', 100000, AchievementRarity.legendary, 2000, reward: 'Badge: Ascended'),

  // ══════════════ QUESTS ══════════════
  _quest('q_1', 'First Steps', 1, AchievementRarity.common, 50),
  _quest('q_10', 'Getting Serious', 10, AchievementRarity.common, 150),
  _quest('q_50', 'Quest Hunter', 50, AchievementRarity.rare, 300),
  _quest('q_100', 'Centurion', 100, AchievementRarity.rare, 500),
  _quest('q_500', 'Relentless', 500, AchievementRarity.epic, 900),
  _quest('q_1000', 'Legend of Quests', 1000, AchievementRarity.legendary, 2000, reward: 'Title: Relentless'),

  // ══════════════ DISCIPLINE — Streaks ══════════════
  _streak('streak_3', 'Warming Up', 3, AchievementRarity.common, 75),
  _streak('streak_7', 'One Week Strong', 7, AchievementRarity.common, 150),
  _streak('streak_14', 'Fortnight Fighter', 14, AchievementRarity.rare, 300),
  _streak('streak_30', 'Unstoppable', 30, AchievementRarity.rare, 500),
  _streak('streak_50', 'Iron Will', 50, AchievementRarity.epic, 800, reward: 'Title: Iron Will'),
  _streak('streak_100', 'Century of Fire', 100, AchievementRarity.epic, 1200),
  _streak('streak_365', 'Eternal Flame', 365, AchievementRarity.legendary, 3650, reward: 'Border: Eternal Flame'),
  Achievement(
    id: 'discipline_initiate',
    name: 'Discipline Initiate',
    description: 'Commit to the discipline path.',
    icon: Icons.self_improvement_rounded,
    category: AchievementCategory.discipline,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => h.discipline,
  ),
  Achievement(
    id: 'perfect_discipline',
    name: 'Perfect Discipline',
    description: 'Hold a 14-day streak on the discipline path.',
    icon: Icons.shield_moon_rounded,
    category: AchievementCategory.discipline,
    rarity: AchievementRarity.epic,
    rewardXp: 700,
    target: 14,
    currentValue: (h) => h.discipline ? h.streak : 0,
    isDone: (h) => h.discipline && h.streak >= 14,
  ),

  // ══════════════ DUELS ══════════════
  Achievement(
    id: 'duel_first',
    name: 'First Duel',
    description: 'Enter your first rivalry.',
    icon: Icons.sports_kabaddi_rounded,
    category: AchievementCategory.duels,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => _duelTotal(h) >= 1,
  ),
  Achievement(
    id: 'duel_first_win',
    name: 'First Victory',
    description: 'Win your first duel.',
    icon: Icons.emoji_events_rounded,
    category: AchievementCategory.duels,
    rarity: AchievementRarity.common,
    rewardXp: 150,
    isDone: (h) => h.duelWins >= 1,
  ),
  _duelWins('duel_5', 'Rival Slayer', 5, AchievementRarity.rare, 300),
  _duelWins('duel_25', 'Duel Champion', 25, AchievementRarity.epic, 700),
  _duelWins('duel_100', 'Arena Legend', 100, AchievementRarity.legendary, 2000, reward: 'Title: Arena Legend'),
  Achievement(
    id: 'duel_undefeated',
    name: 'Undefeated',
    description: 'Win 10 duels without a single loss.',
    icon: Icons.workspace_premium_rounded,
    category: AchievementCategory.duels,
    rarity: AchievementRarity.legendary,
    rewardXp: 1500,
    reward: 'Badge: Undefeated',
    isDone: (h) => h.duelWins >= 10 && h.duelLosses == 0,
  ),

  // ══════════════ DUNGEON ══════════════
  // Progress comes from the all-time counters on HunterData, incremented only
  // by a claimed DUNGEON CLEARED (see `HunterData.monstersDefeated`).
  // Deliberately driven by the MONSTER counter, not the dungeon counter: the
  // monster counter only ever moves on a claimed clear, so `>= 1` literally
  // means "you finished a dungeon that had monsters in it". The name states
  // the behaviour that is actually tracked instead of implying per-monster
  // detection, which does not exist yet.
  Achievement(
    id: 'dungeon_monster_1',
    name: 'First Dungeon Clear',
    description: 'Defeat every monster in a dungeon and clear it.',
    icon: Icons.pest_control_rounded,
    category: AchievementCategory.dungeon,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    target: 1,
    currentValue: (h) => h.monstersDefeated.clamp(0, 1),
    isDone: (h) => h.monstersDefeated >= 1,
  ),
  _monsters('dungeon_monster_25', 'Monster Hunter', 25, AchievementRarity.rare, 300),
  _monsters('dungeon_monster_100', 'Elite Hunter', 100, AchievementRarity.epic, 700),
  _bosses('dungeon_boss_1', 'First Boss', 1, AchievementRarity.rare, 150),
  _bosses('dungeon_boss_10', 'Boss Slayer', 10, AchievementRarity.epic, 700, reward: 'Title: Boss Slayer'),
  _dungeons('dungeon_clear_1', 'Dungeon Awakening', 1, AchievementRarity.common, 100),
  _dungeons('dungeon_clear_25', 'Dungeon Master', 25, AchievementRarity.legendary, 2000, reward: 'Title: Dungeon Master'),

  // ══════════════ BODY ══════════════
  Achievement(
    id: 'body_first_update',
    name: 'First Weight Update',
    description: 'Log your body weight.',
    icon: Icons.monitor_weight_rounded,
    category: AchievementCategory.body,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => h.weight > 0,
  ),
  Achievement(
    id: 'body_lose_5',
    name: 'Lighter Steps',
    description: 'Lose 5 kg since you started.',
    icon: Icons.trending_down_rounded,
    category: AchievementCategory.body,
    rarity: AchievementRarity.rare,
    rewardXp: 400,
    target: 5,
    currentValue: (h) => _weightLost(h).clamp(0, 5),
    isDone: (h) => _weightLost(h) >= 5,
  ),
  Achievement(
    id: 'body_lose_10',
    name: 'Transformation',
    description: 'Lose 10 kg since you started.',
    icon: Icons.local_fire_department_rounded,
    category: AchievementCategory.body,
    rarity: AchievementRarity.epic,
    rewardXp: 900,
    target: 10,
    currentValue: (h) => _weightLost(h).clamp(0, 10),
    isDone: (h) => _weightLost(h) >= 10,
    reward: 'Badge: Transformed',
  ),
  Achievement(
    id: 'body_gain_muscle',
    name: 'Gain Muscle',
    description: 'Add 2 kg on the muscle-gain path.',
    icon: Icons.fitness_center_rounded,
    category: AchievementCategory.body,
    rarity: AchievementRarity.epic,
    rewardXp: 700,
    isDone: (h) => h.muscleGain && (h.weight - h.startingWeight) >= 2,
  ),
  Achievement(
    id: 'body_bmi_improved',
    name: 'BMI Improved',
    description: 'Reduce your weight below your starting point.',
    icon: Icons.monitor_heart_outlined,
    category: AchievementCategory.body,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    isDone: (h) => h.height > 0 && _weightLost(h) > 0,
  ),

  // ══════════════ HYDRATION ══════════════
  Achievement(
    id: 'hydration_expert',
    name: 'Hydration Expert',
    description: 'Hit your daily water goal.',
    icon: Icons.water_drop_rounded,
    category: AchievementCategory.hydration,
    rarity: AchievementRarity.rare,
    rewardXp: 200,
    target: 1,
    currentValue: (h) => (h.waterGoalMl > 0 && h.waterIntakeMl >= h.waterGoalMl) ? 1 : 0,
    isDone: (h) => h.waterGoalMl > 0 && h.waterIntakeMl >= h.waterGoalMl,
  ),
  Achievement(
    id: 'hydration_100',
    name: 'Drink Water 100 Times',
    description: 'Log water 100 times.',
    icon: Icons.local_drink_rounded,
    category: AchievementCategory.hydration,
    rarity: AchievementRarity.epic,
    rewardXp: 600,
    target: 100,
    currentValue: (h) => h.waterLogCount.clamp(0, 100),
    isDone: (h) => h.waterLogCount >= 100,
  ),
  Achievement(
    id: 'hydration_streak',
    name: 'Stay Hydrated',
    description: 'Hit your water goal 7 days in a row.',
    icon: Icons.opacity_rounded,
    category: AchievementCategory.hydration,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    target: 7,
    currentValue: (h) => h.waterGoalStreak.clamp(0, 7),
    isDone: (h) => h.waterGoalStreak >= 7,
  ),

  // ══════════════ NUTRITION ══════════════
  Achievement(
    id: 'nutri_first',
    name: 'First Meal Logged',
    description: 'Log your first meal.',
    icon: Icons.restaurant_rounded,
    category: AchievementCategory.nutrition,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => h.mealsLoggedCount >= 1,
  ),
  Achievement(
    id: 'nutri_100',
    name: '100 Healthy Meals',
    description: 'Log 100 meals.',
    icon: Icons.dinner_dining_rounded,
    category: AchievementCategory.nutrition,
    rarity: AchievementRarity.epic,
    rewardXp: 700,
    target: 100,
    currentValue: (h) => h.mealsLoggedCount.clamp(0, 100),
    isDone: (h) => h.mealsLoggedCount >= 100,
  ),
  Achievement(
    id: 'nutri_protein',
    name: 'Protein Master',
    description: 'Hit your protein goal repeatedly.',
    icon: Icons.egg_alt_rounded,
    category: AchievementCategory.nutrition,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    target: 7,
    currentValue: (h) => h.proteinGoalHitDays.clamp(0, 7),
    isDone: (h) => h.proteinGoalHitDays >= 7,
  ),
  Achievement(
    id: 'nutri_balanced',
    name: 'Balanced Diet',
    description: 'Log a full day of balanced macros.',
    icon: Icons.pie_chart_rounded,
    category: AchievementCategory.nutrition,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    isDone: (h) => h.balancedMacroDays >= 1,
  ),

  // ══════════════ WALKING ══════════════
  Achievement(
    id: 'walk_5',
    name: 'Walk 5 km',
    description: 'Cover 5 km on foot.',
    icon: Icons.directions_walk_rounded,
    category: AchievementCategory.walking,
    rarity: AchievementRarity.common,
    rewardXp: 100,
    target: 5,
    currentValue: (h) => h.totalRunDistanceKm.clamp(0, 5),
    isDone: (h) => h.totalRunDistanceKm >= 5,
  ),
  Achievement(
    id: 'walk_25',
    name: 'Walk 25 km',
    description: 'Cover 25 km on foot.',
    icon: Icons.directions_walk_rounded,
    category: AchievementCategory.walking,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    target: 25,
    currentValue: (h) => h.totalRunDistanceKm.clamp(0, 25),
    isDone: (h) => h.totalRunDistanceKm >= 25,
  ),
  Achievement(
    id: 'walk_100',
    name: 'Walk 100 km',
    description: 'Cover 100 km on foot.',
    icon: Icons.hiking_rounded,
    category: AchievementCategory.walking,
    rarity: AchievementRarity.epic,
    rewardXp: 700,
    target: 100,
    currentValue: (h) => h.totalRunDistanceKm.clamp(0, 100),
    isDone: (h) => h.totalRunDistanceKm >= 100,
  ),
  Achievement(
    id: 'walk_500',
    name: 'Walk 500 km',
    description: 'Cover 500 km on foot.',
    icon: Icons.terrain_rounded,
    category: AchievementCategory.walking,
    rarity: AchievementRarity.legendary,
    rewardXp: 1500,
    reward: 'Badge: Pathfinder',
    target: 500,
    currentValue: (h) => h.totalRunDistanceKm.clamp(0, 500),
    isDone: (h) => h.totalRunDistanceKm >= 500,
  ),
  Achievement(
    id: 'walk_million',
    name: '1 Million Steps',
    description: 'Take one million steps.',
    icon: Icons.emoji_events_rounded,
    category: AchievementCategory.walking,
    rarity: AchievementRarity.legendary,
    rewardXp: 2000,
    reward: 'Title: Millionaire',
    target: 1000000,
    currentValue: (h) => h.totalStepsAllTime.clamp(0, 1000000),
    isDone: (h) => h.totalStepsAllTime >= 1000000,
  ),

  // ══════════════ EXPLORER (Maps / Running) ══════════════
  Achievement(
    id: 'explore_first',
    name: 'First Route',
    description: 'Record your first run route.',
    icon: Icons.explore_rounded,
    category: AchievementCategory.explorer,
    rarity: AchievementRarity.common,
    rewardXp: 100,
    isDone: (h) => h.totalRunsCompleted >= 1,
  ),
  Achievement(
    id: 'explore_10',
    name: 'Explore 10 Routes',
    description: 'Record 10 run routes.',
    icon: Icons.map_rounded,
    category: AchievementCategory.explorer,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    target: 10,
    currentValue: (h) => h.totalRunsCompleted.clamp(0, 10),
    isDone: (h) => h.totalRunsCompleted >= 10,
  ),
  Achievement(
    id: 'explore_100',
    name: 'Explore 100 Routes',
    description: 'Record 100 run routes.',
    icon: Icons.travel_explore_rounded,
    category: AchievementCategory.explorer,
    rarity: AchievementRarity.epic,
    rewardXp: 800,
    target: 100,
    currentValue: (h) => h.totalRunsCompleted.clamp(0, 100),
    isDone: (h) => h.totalRunsCompleted >= 100,
  ),
  Achievement(
    id: 'explore_longest',
    name: 'Longest Adventure',
    description: 'Complete a run over 10 km.',
    icon: Icons.route_rounded,
    category: AchievementCategory.explorer,
    rarity: AchievementRarity.legendary,
    rewardXp: 1500,
    reward: 'Badge: Adventurer',
    isDone: (h) => h.longestRunKm >= 10,
  ),

  // ══════════════ SOCIAL ══════════════
  Achievement(
    id: 'social_compare',
    name: 'First Hunter Compared',
    description: 'Compare yourself with another hunter.',
    icon: Icons.compare_arrows_rounded,
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    rewardXp: 75,
    isDone: (h) => h.hasComparedHunter,
  ),
  Achievement(
    id: 'social_share_profile',
    name: 'Share Profile',
    description: 'Share your hunter profile card.',
    icon: Icons.ios_share_rounded,
    category: AchievementCategory.social,
    rarity: AchievementRarity.common,
    rewardXp: 100,
    isDone: (h) => h.hasSharedProfile,
  ),
  Achievement(
    id: 'social_share_report',
    name: 'Share Report',
    description: 'Share your progress report.',
    icon: Icons.summarize_rounded,
    category: AchievementCategory.social,
    rarity: AchievementRarity.rare,
    rewardXp: 150,
    isDone: (h) => h.hasSharedReport,
  ),
  Achievement(
    id: 'social_share_activity',
    name: 'Share Activity',
    description: 'Share a run activity card.',
    icon: Icons.directions_run_rounded,
    category: AchievementCategory.social,
    rarity: AchievementRarity.rare,
    rewardXp: 150,
    isDone: (h) => h.hasSharedActivity,
  ),
  Achievement(
    id: 'social_invite',
    name: 'Invite a Friend',
    description: 'Invite a friend to Hunter Ascend.',
    icon: Icons.person_add_alt_1_rounded,
    category: AchievementCategory.social,
    rarity: AchievementRarity.epic,
    rewardXp: 400,
    reward: 'Badge: Recruiter',
    isDone: (h) => h.hasSharedApp,
  ),

  // ══════════════ MEMBERSHIP ══════════════
  Achievement(
    id: 'member_pro',
    name: 'Become Pro',
    description: 'Unlock the Pro tier.',
    icon: Icons.workspace_premium_rounded,
    category: AchievementCategory.membership,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    isDone: _isPro,
  ),
  Achievement(
    id: 'member_max',
    name: 'Become Max',
    description: 'Unlock the Max tier.',
    icon: Icons.auto_awesome_rounded,
    category: AchievementCategory.membership,
    rarity: AchievementRarity.epic,
    rewardXp: 700,
    reward: 'Border: Max Aura',
    isDone: _isMax,
  ),
  Achievement(
    id: 'member_support',
    name: 'Support Hunter Ascend',
    description: 'Support the app with a membership.',
    icon: Icons.favorite_rounded,
    category: AchievementCategory.membership,
    rarity: AchievementRarity.rare,
    rewardXp: 250,
    isDone: (h) => h.subscriptionActive || _isPro(h),
  ),

  // ══════════════ SPECIAL ══════════════
  Achievement(
    id: 'special_never_give_up',
    name: 'Never Give Up',
    description: 'Rebuild your streak after a setback.',
    icon: Icons.replay_rounded,
    category: AchievementCategory.special,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    isDone: (h) => h.previousStreak >= 3 && h.streak >= 1,
  ),
  Achievement(
    id: 'special_perfect_week',
    name: 'Perfect Week',
    description: 'Complete a flawless 7-day streak.',
    icon: Icons.calendar_view_week_rounded,
    category: AchievementCategory.special,
    rarity: AchievementRarity.rare,
    rewardXp: 350,
    target: 7,
    currentValue: (h) => h.streak.clamp(0, 7),
    isDone: (h) => h.streak >= 7,
  ),
  Achievement(
    id: 'special_perfect_month',
    name: 'Perfect Month',
    description: 'Complete a flawless 30-day streak.',
    icon: Icons.calendar_month_rounded,
    category: AchievementCategory.special,
    rarity: AchievementRarity.epic,
    rewardXp: 900,
    target: 30,
    currentValue: (h) => h.streak.clamp(0, 30),
    isDone: (h) => h.streak >= 30,
    reward: 'Badge: Flawless',
  ),

  // ══════════════ HIDDEN (secret — surprise the player) ══════════════
  // hitMidnightAction/hitEarlyBirdAction/hitNightOwlAction are set by
  // AchievementTimeTracker (see below) the moment the hunter performs any
  // XP-earning/tracked action (quest complete, water log, weight log, step
  // milestone, run save, duel) within the relevant local-time window — see
  // each real trigger call site for where AchievementTimeTracker.recordNow()
  // is invoked.
  Achievement(
    id: 'hidden_midnight',
    name: 'Midnight Hunter',
    description: 'Some hunt when the world sleeps.',
    icon: Icons.nightlight_round,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.epic,
    rewardXp: 500,
    hidden: true,
    isDone: (h) => h.hitMidnightAction,
  ),
  Achievement(
    id: 'hidden_early_bird',
    name: 'Early Bird',
    description: 'The dawn belongs to the disciplined.',
    icon: Icons.wb_twilight_rounded,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.epic,
    rewardXp: 500,
    hidden: true,
    isDone: (h) => h.hitEarlyBirdAction,
  ),
  Achievement(
    id: 'hidden_night_owl',
    name: 'Night Owl',
    description: 'A late-night legend.',
    icon: Icons.dark_mode_rounded,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.rare,
    rewardXp: 300,
    hidden: true,
    isDone: (h) => h.hitNightOwlAction,
  ),
  Achievement(
    id: 'hidden_comeback',
    name: 'The Comeback',
    description: 'Rise again when it matters most.',
    icon: Icons.auto_awesome_motion_rounded,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.legendary,
    rewardXp: 1500,
    hidden: true,
    reward: 'Title: Phoenix',
    // A genuine comeback: previously lost the streak entirely (>=7 days
    // built up before breaking to 0) and has since rebuilt to a full week.
    isDone: (h) => h.previousStreak >= 7 && h.streak >= 7,
  ),
  Achievement(
    id: 'hidden_completionist',
    name: 'Completionist',
    description: 'Only the obsessed will find this.',
    icon: Icons.workspace_premium_rounded,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.legendary,
    rewardXp: 2500,
    hidden: true,
    reward: 'Border: Completionist',
    // Every other non-hidden achievement in the catalog is unlocked.
    isDone: (h) => kAchievements
        .where((a) => a.category != AchievementCategory.hidden)
        .every((a) => a.isDone(h)),
  ),
  Achievement(
    id: 'hidden_secret_rank',
    name: 'Beyond the System',
    description: '???',
    icon: Icons.blur_on_rounded,
    category: AchievementCategory.hidden,
    rarity: AchievementRarity.legendary,
    rewardXp: 2000,
    hidden: true,
    // Reaching the final rank tier (Ascend Legend, level 600+).
    isDone: (h) => h.level >= 600,
  ),
];

/// O(1) id -> [Achievement] lookup, built once from [kAchievements]. Used by
/// [AchievementsService] to resolve pending-XP-award recovery without a
/// linear scan.
final Map<String, Achievement> kAchievementsById = {
  for (final a in kAchievements) a.id: a,
};

// ── Factory helpers to reduce boilerplate for common ladders ────────────────

Achievement _level(String id, String name, int lvl, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Reach level $lvl.',
      icon: Icons.military_tech_rounded,
      category: AchievementCategory.progress,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: lvl,
      currentValue: (h) => h.level.clamp(0, lvl),
      isDone: (h) => h.level >= lvl,
    );

Achievement _xp(String id, String name, int amount, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Earn ${_fmt(amount)} total XP.',
      icon: Icons.bolt_rounded,
      category: AchievementCategory.progress,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: amount,
      currentValue: (h) => h.xp.clamp(0, amount),
      isDone: (h) => h.xp >= amount,
    );

Achievement _quest(String id, String name, int count, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Complete ${_fmt(count)} quests.',
      icon: Icons.task_alt_rounded,
      category: AchievementCategory.quests,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: count,
      currentValue: (h) => h.questsDone.clamp(0, count),
      isDone: (h) => h.questsDone >= count,
    );

Achievement _streak(String id, String name, int days, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Reach a $days-day streak.',
      icon: Icons.local_fire_department_rounded,
      category: AchievementCategory.discipline,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: days,
      currentValue: (h) => h.streak.clamp(0, days),
      isDone: (h) => h.streak >= days,
    );

Achievement _duelWins(String id, String name, int wins, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Win $wins duels.',
      icon: Icons.emoji_events_rounded,
      category: AchievementCategory.duels,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: wins,
      currentValue: (h) => h.duelWins.clamp(0, wins),
      isDone: (h) => h.duelWins >= wins,
    );

Achievement _monsters(String id, String name, int count, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: 'Defeat ${_fmt(count)} dungeon monsters.',
      icon: Icons.pest_control_rounded,
      category: AchievementCategory.dungeon,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: count,
      currentValue: (h) => h.monstersDefeated.clamp(0, count),
      isDone: (h) => h.monstersDefeated >= count,
    );

Achievement _bosses(String id, String name, int count, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: count == 1
          ? 'Defeat your first dungeon boss.'
          : 'Defeat ${_fmt(count)} dungeon bosses.',
      icon: Icons.whatshot_rounded,
      category: AchievementCategory.dungeon,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: count,
      currentValue: (h) => h.bossesDefeated.clamp(0, count),
      isDone: (h) => h.bossesDefeated >= count,
    );

Achievement _dungeons(String id, String name, int count, AchievementRarity rarity, int xp, {String? reward}) => Achievement(
      id: id,
      name: name,
      description: count == 1
          ? 'Clear your first dungeon.'
          : 'Clear ${_fmt(count)} dungeons.',
      icon: Icons.castle_rounded,
      category: AchievementCategory.dungeon,
      rarity: rarity,
      rewardXp: xp,
      reward: reward,
      target: count,
      currentValue: (h) => h.dungeonsCompleted.clamp(0, count),
      isDone: (h) => h.dungeonsCompleted >= count,
    );

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
  return '$n';
}
