import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// The master list of permanent Hunter Rank rewards.
///
/// Purely data — no logic. [RankRewardService] grants every entry whose
/// [RankReward.rankTier] is `<= ` the hunter's current tier (from
/// `RankService`) and that the hunter doesn't already own. Adding a future
/// reward is as simple as appending a row here; no service or screen code
/// needs to change.
///
/// [RankReward.rankTier] MUST correspond to a real tier in
/// `RankService.ranks` (`E = 0` … `Ascend Legend = 11`).
final List<RankReward> kRankRewards = [
  // ── E Rank (tier 0) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_awakened',
    rankTier: 0,
    type: RankRewardType.title,
    name: 'Awakened',
    description: 'Granted the moment you first awaken as a Hunter.',
    color: HunterTheme.textSecondary,
  ),
  RankReward(
    id: 'badge_e_rank',
    rankTier: 0,
    type: RankRewardType.badge,
    name: 'E-Rank Badge',
    description: 'Proof that your journey has begun.',
    color: HunterTheme.textSecondary,
  ),

  // ── D Rank (tier 1) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_rising_hunter',
    rankTier: 1,
    type: RankRewardType.title,
    name: 'Rising Hunter',
    description: 'Your strength is beginning to show.',
    color: HunterTheme.success,
  ),
  RankReward(
    id: 'border_bronze',
    rankTier: 1,
    type: RankRewardType.border,
    name: 'Bronze Border',
    description: 'A modest frame for a hunter on the rise.',
    color: HunterTheme.bronze,
  ),

  // ── C Rank (tier 2) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_elite_hunter',
    rankTier: 2,
    type: RankRewardType.title,
    name: 'Elite Hunter',
    description: 'Recognized among competent hunters.',
    color: HunterTheme.info,
  ),
  RankReward(
    id: 'badge_c_rank',
    rankTier: 2,
    type: RankRewardType.badge,
    name: 'C-Rank Badge',
    description: 'A mark of proven competence.',
    color: HunterTheme.info,
  ),
  RankReward(
    id: 'report_style_field_report',
    rankTier: 2,
    type: RankRewardType.reportStyle,
    name: 'Field Report',
    description: 'A cleaner report layout for capable hunters.',
    color: HunterTheme.info,
  ),

  // ── B Rank (tier 3) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_master_hunter',
    rankTier: 3,
    type: RankRewardType.title,
    name: 'Master Hunter',
    description: 'Your discipline has become mastery.',
    color: HunterTheme.purple,
  ),
  RankReward(
    id: 'border_silver',
    rankTier: 3,
    type: RankRewardType.border,
    name: 'Silver Border',
    description: 'A distinguished frame for a master hunter.',
    color: HunterTheme.silver,
  ),

  // ── A Rank (tier 4) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_sovereign',
    rankTier: 4,
    type: RankRewardType.title,
    name: 'Sovereign',
    description: 'You command respect among hunters.',
    color: HunterTheme.danger,
  ),
  RankReward(
    id: 'badge_a_rank',
    rankTier: 4,
    type: RankRewardType.badge,
    name: 'A-Rank Badge',
    description: 'Few hunters ever reach this mark.',
    color: HunterTheme.danger,
  ),
  RankReward(
    id: 'aura_ember',
    rankTier: 4,
    type: RankRewardType.aura,
    name: 'Ember Aura',
    description: 'A faint warmth radiates from your presence.',
    color: HunterTheme.dangerAlt,
  ),

  // ── S Rank (tier 5) ────────────────────────────────────────────────────
  RankReward(
    id: 'title_supreme_hunter',
    rankTier: 5,
    type: RankRewardType.title,
    name: 'Supreme Hunter',
    description: 'The pinnacle of the letter ranks.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'border_gold',
    rankTier: 5,
    type: RankRewardType.border,
    name: 'Gold Border',
    description: 'A radiant frame befitting an S-Rank Hunter.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'dashboard_theme_supreme',
    rankTier: 5,
    type: RankRewardType.dashboardTheme,
    name: 'Supreme Dashboard Accent',
    description: 'A gilded accent for your dashboard, earned in blood and sweat.',
    color: HunterTheme.goldBright,
  ),

  // ── National Hunter (tier 6) ───────────────────────────────────────────
  RankReward(
    id: 'title_national_hunter',
    rankTier: 6,
    type: RankRewardType.title,
    name: 'National Hunter',
    description: 'Your name is known beyond your own guild.',
    color: HunterTheme.primary,
  ),
  RankReward(
    id: 'badge_national_hunter',
    rankTier: 6,
    type: RankRewardType.badge,
    name: 'National Hunter Badge',
    description: 'Officially recognized at the national level.',
    color: HunterTheme.primary,
  ),

  // ── Monarch (tier 7) ───────────────────────────────────────────────────
  RankReward(
    id: 'title_monarch',
    rankTier: 7,
    type: RankRewardType.title,
    name: 'Monarch',
    description: 'You rule over your own domain of discipline.',
    color: HunterTheme.purpleLight,
  ),
  RankReward(
    id: 'aura_royal_violet',
    rankTier: 7,
    type: RankRewardType.aura,
    name: 'Royal Violet Aura',
    description: 'A regal violet glow surrounds a true Monarch.',
    color: HunterTheme.purpleLight,
  ),
  RankReward(
    id: 'profile_effect_crown_glint',
    rankTier: 7,
    type: RankRewardType.profileEffect,
    name: 'Crown Glint',
    description: 'A subtle glint of royalty on your profile.',
    color: HunterTheme.purpleLight,
  ),

  // ── Shadow Monarch (tier 8) ────────────────────────────────────────────
  RankReward(
    id: 'title_shadow_monarch',
    rankTier: 8,
    type: RankRewardType.title,
    name: 'Shadow Monarch',
    description: 'The one true rank whispered about by every hunter.',
    color: HunterTheme.purple,
  ),
  RankReward(
    id: 'border_shadow',
    rankTier: 8,
    type: RankRewardType.border,
    name: 'Shadow Border',
    description: 'A frame woven from darkness itself.',
    color: HunterTheme.purple,
  ),
  RankReward(
    id: 'aura_shadow',
    rankTier: 8,
    type: RankRewardType.aura,
    name: 'Shadow Aura',
    description: 'Shadows gather quietly at your command.',
    color: HunterTheme.purple,
  ),
  RankReward(
    id: 'dashboard_theme_shadow_monarch',
    rankTier: 8,
    type: RankRewardType.dashboardTheme,
    name: 'Shadow Monarch Accent',
    description: 'A dashboard accent fit for the ruler of shadows.',
    color: HunterTheme.purple,
  ),

  // ── Ascendant Hunter (tier 9) ──────────────────────────────────────────
  RankReward(
    id: 'title_ascendant_hunter',
    rankTier: 9,
    type: RankRewardType.title,
    name: 'Ascendant Hunter',
    description: 'You have transcended ordinary limits.',
    color: HunterTheme.goldBright,
  ),
  RankReward(
    id: 'badge_ascendant',
    rankTier: 9,
    type: RankRewardType.badge,
    name: 'Ascendant Badge',
    description: 'A mark of transcendence beyond the known ranks.',
    color: HunterTheme.goldBright,
  ),
  RankReward(
    id: 'report_style_ascendant_dossier',
    rankTier: 9,
    type: RankRewardType.reportStyle,
    name: 'Ascendant Dossier',
    description: 'An elevated report style for an elevated hunter.',
    color: HunterTheme.goldBright,
  ),

  // ── Celestial Hunter (tier 10) ─────────────────────────────────────────
  RankReward(
    id: 'title_celestial_hunter',
    rankTier: 10,
    type: RankRewardType.title,
    name: 'Celestial Hunter',
    description: 'Your presence feels almost otherworldly.',
    color: HunterTheme.silver,
  ),
  RankReward(
    id: 'border_celestial',
    rankTier: 10,
    type: RankRewardType.border,
    name: 'Celestial Border',
    description: 'A frame that shimmers like distant starlight.',
    color: HunterTheme.silver,
  ),
  RankReward(
    id: 'aura_starlight',
    rankTier: 10,
    type: RankRewardType.aura,
    name: 'Starlight Aura',
    description: 'A faint constellation seems to follow you.',
    color: HunterTheme.silver,
  ),

  // ── Ascend Legend (tier 11) ────────────────────────────────────────────
  RankReward(
    id: 'title_ascend_legend',
    rankTier: 11,
    type: RankRewardType.title,
    name: 'Ascend Legend',
    description: 'The final, permanent title of the Ascended.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'badge_ascend_legend',
    rankTier: 11,
    type: RankRewardType.badge,
    name: 'Legend Badge',
    description: 'There is no rank beyond this.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'aura_legend',
    rankTier: 11,
    type: RankRewardType.aura,
    name: 'Legend Aura',
    description: 'An aura reserved for those who never stopped ascending.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'profile_effect_legend_glow',
    rankTier: 11,
    type: RankRewardType.profileEffect,
    name: 'Legend Glow',
    description: 'A permanent glow marking your legendary status.',
    color: HunterTheme.gold,
  ),
  RankReward(
    id: 'dashboard_theme_ascend_legend',
    rankTier: 11,
    type: RankRewardType.dashboardTheme,
    name: 'Ascend Legend Accent',
    description: 'The most prestigious dashboard accent in the game.',
    color: HunterTheme.gold,
  ),
];

/// Sanity check (debug-time helper, not called in production paths): every
/// [RankReward.rankTier] used above must correspond to a real
/// `RankService.ranks` entry. Kept here so any future catalog edit that adds
/// an out-of-range tier is easy to catch with a single assertion call.
bool debugRankRewardsCatalogIsValid() {
  final maxTier = RankService.ranks.length - 1;
  return kRankRewards.every((r) => r.rankTier >= 0 && r.rankTier <= maxTier);
}
