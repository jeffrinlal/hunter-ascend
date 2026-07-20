import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Immutable metadata describing a single Hunter Rank tier.
///
/// A rank is derived purely from the hunter's **level** (never from the stored
/// `xp` field, which is only the remainder toward the next level). All rank
/// presentation — letter, titles and color — lives here so every screen shows
/// exactly the same thing.
///
/// Future phases can extend this class with additional metadata (rewards,
/// titles, borders, auras, unlockable achievements, celebration copy, ...)
/// in ONE place, and every screen benefits automatically.
@immutable
class HunterRank {
  /// Compact rank code shown in badges/crests: `E`,`D`,`C`,`B`,`A`,`S` for the
  /// letter ranks, and a short 2-char code (`NH`,`MO`,`SM`,`AH`,`CH`,`AL`) for
  /// the named ranks. Unique across all ranks.
  final String letter;

  /// Ordinal position of the rank, `E = 0` … `Ascend Legend = 11`. Useful for
  /// scoring and comparisons without hard-coding the order elsewhere.
  final int tier;

  /// Inclusive minimum level required to hold this rank (`level >= minLevel`).
  final int minLevel;

  /// Sentence-case label, e.g. `"S Rank"` (used by leaderboards).
  final String label;

  /// Upper-case short title, e.g. `"S RANK"` (used by the dashboard badge).
  final String shortTitle;

  /// Upper-case long title, e.g. `"S RANK HUNTER"` (used by public profiles).
  final String longTitle;

  // ── Future-phase cosmetic metadata ──────────────────────────────────────
  /// Premium cosmetic title for this rank — an ALTERNATE visual presentation of
  /// the exact same canonical rank (e.g. the Max dashboard renders "SUPREME
  /// HUNTER" for rank S). "Shadow Monarch" is reserved for the real Level-200
  /// rank, so each milestone stays unique. This is display-only: it never
  /// affects how a rank is calculated. Screens that don't opt into the premium
  /// presentation simply use [letter]/[shortTitle]/[longTitle] instead.
  final String displayTitle;

  // These are intentionally optional so new phases can attach rewards/cosmetics
  // to a rank centrally, with NO data migration and NO per-screen changes.
  /// Optional identifiers for future cosmetic unlocks tied to this rank.
  final String? borderId;
  final String? auraId;

  const HunterRank({
    required this.letter,
    required this.tier,
    required this.minLevel,
    required this.label,
    required this.shortTitle,
    required this.longTitle,
    required this.displayTitle,
    this.borderId,
    this.auraId,
  });

  /// Theme-aware accent color for this rank. Implemented as a getter (not a
  /// stored value) so it follows the active light/dark theme at read time.
  /// Keyed on [tier] so it covers the full expanded ladder.
  Color get color {
    switch (tier) {
      case 0:  return HunterTheme.textSecondary; // E
      case 1:  return HunterTheme.success;       // D
      case 2:  return HunterTheme.info;          // C
      case 3:  return HunterTheme.purple;        // B
      case 4:  return HunterTheme.danger;        // A
      case 5:  return HunterTheme.gold;          // S
      case 6:  return HunterTheme.primary;       // National Hunter
      case 7:  return HunterTheme.purpleLight;   // Monarch
      case 8:  return HunterTheme.purple;        // Shadow Monarch
      case 9:  return HunterTheme.goldBright;    // Ascendant Hunter
      case 10: return HunterTheme.silver;        // Celestial Hunter
      case 11: return HunterTheme.gold;          // Ascend Legend
      default: return HunterTheme.textSecondary;
    }
  }
}

/// Centralized source of truth for the Hunter Rank system.
///
/// Every screen (dashboard, profile, public profile, compare, leaderboards,
/// reports and share images) resolves rank through this service, so ranks are
/// calculated identically everywhere.
///
/// IMPORTANT: this service does NOT change XP progression. It only *reads*
/// `level` (and optionally the in-level `xp` remainder) to present a rank.
/// [xpPerLevel] mirrors [XpService]'s constant purely for progress math and is
/// never used to mutate data.
class RankService {
  RankService._();
  static final RankService instance = RankService._();

  /// Mirror of the XP-per-level constant used by `XpService` (500). Used only
  /// for computing "XP to next rank" / progress bars — never to award XP.
  static const int xpPerLevel = 500;

  /// The rank ladder, ordered ascending by [minLevel]. Single source of truth.
  ///
  /// Expanded level bands (Phase 2) so progression continues far beyond S Rank:
  ///   E: 1–9 · D: 10–19 · C: 20–34 · B: 35–49 · A: 50–69 · S: 70–99 ·
  ///   National Hunter: 100–149 · Monarch: 150–199 · Shadow Monarch: 200–299 ·
  ///   Ascendant Hunter: 300–399 · Celestial Hunter: 400–599 · Ascend Legend: 600+.
  ///
  /// [letter] is a compact code shown in badges/crests (single letter for E–S,
  /// a short 2-char code for the named ranks). [displayTitle] is a premium,
  /// cosmetic-only alias used by the Max dashboard. Everything else on every
  /// screen is derived from this list, so adding future tiers means appending
  /// one row here — no screen changes required.
  static const List<HunterRank> ranks = [
    HunterRank(letter: 'E',  tier: 0,  minLevel: 1,   label: 'E Rank',           shortTitle: 'E RANK',           longTitle: 'E RANK HUNTER',     displayTitle: 'AWAKENED'),
    HunterRank(letter: 'D',  tier: 1,  minLevel: 10,  label: 'D Rank',           shortTitle: 'D RANK',           longTitle: 'D RANK HUNTER',     displayTitle: 'RISING HUNTER'),
    HunterRank(letter: 'C',  tier: 2,  minLevel: 20,  label: 'C Rank',           shortTitle: 'C RANK',           longTitle: 'C RANK HUNTER',     displayTitle: 'ELITE HUNTER'),
    HunterRank(letter: 'B',  tier: 3,  minLevel: 35,  label: 'B Rank',           shortTitle: 'B RANK',           longTitle: 'B RANK HUNTER',     displayTitle: 'MASTER HUNTER'),
    HunterRank(letter: 'A',  tier: 4,  minLevel: 50,  label: 'A Rank',           shortTitle: 'A RANK',           longTitle: 'A RANK HUNTER',     displayTitle: 'SOVEREIGN'),
    HunterRank(letter: 'S',  tier: 5,  minLevel: 70,  label: 'S Rank',           shortTitle: 'S RANK',           longTitle: 'S RANK HUNTER',     displayTitle: 'SUPREME HUNTER'),
    HunterRank(letter: 'NH', tier: 6,  minLevel: 100, label: 'National Hunter',  shortTitle: 'NATIONAL HUNTER',  longTitle: 'NATIONAL HUNTER',   displayTitle: 'NATIONAL HUNTER'),
    HunterRank(letter: 'MO', tier: 7,  minLevel: 150, label: 'Monarch',          shortTitle: 'MONARCH',          longTitle: 'MONARCH',           displayTitle: 'MONARCH'),
    HunterRank(letter: 'SM', tier: 8,  minLevel: 200, label: 'Shadow Monarch',   shortTitle: 'SHADOW MONARCH',   longTitle: 'SHADOW MONARCH',    displayTitle: 'SHADOW MONARCH'),
    HunterRank(letter: 'AH', tier: 9,  minLevel: 300, label: 'Ascendant Hunter', shortTitle: 'ASCENDANT HUNTER', longTitle: 'ASCENDANT HUNTER',  displayTitle: 'ASCENDANT HUNTER'),
    HunterRank(letter: 'CH', tier: 10, minLevel: 400, label: 'Celestial Hunter', shortTitle: 'CELESTIAL HUNTER', longTitle: 'CELESTIAL HUNTER',  displayTitle: 'CELESTIAL HUNTER'),
    HunterRank(letter: 'AL', tier: 11, minLevel: 600, label: 'Ascend Legend',    shortTitle: 'ASCEND LEGEND',    longTitle: 'ASCEND LEGEND',     displayTitle: 'ASCEND LEGEND'),
  ];

  /// Resolves the [HunterRank] for a given [level] (the ONLY input to rank).
  HunterRank rankForLevel(int level) {
    HunterRank current = ranks.first;
    for (final r in ranks) {
      if (level >= r.minLevel) {
        current = r;
      } else {
        break;
      }
    }
    return current;
  }

  // ── Convenience accessors (so screens never re-implement rank logic) ──────

  /// Rank letter for a level, e.g. `"S"`.
  String letterForLevel(int level) => rankForLevel(level).letter;

  /// Sentence-case label for a level, e.g. `"S Rank"`.
  String labelForLevel(int level) => rankForLevel(level).label;

  /// Upper-case short title for a level, e.g. `"S RANK"`.
  String shortTitleForLevel(int level) => rankForLevel(level).shortTitle;

  /// Upper-case long title for a level, e.g. `"S RANK HUNTER"`.
  String longTitleForLevel(int level) => rankForLevel(level).longTitle;

  /// Premium cosmetic display title for a level's rank, e.g. `"SHADOW MONARCH"`.
  /// This is purely an alternate presentation of the SAME canonical rank
  /// resolved by [rankForLevel] — it introduces no separate rank logic.
  String displayTitleForLevel(int level) => rankForLevel(level).displayTitle;

  /// Theme-aware accent color for a level's rank.
  Color colorForLevel(int level) => rankForLevel(level).color;

  /// Ordinal tier for a level's rank (`E = 0` … `Ascend Legend = 11`).
  int tierForLevel(int level) => rankForLevel(level).tier;

  /// Ordinal index of a rank [letter] code (`E = 0` … `Ascend Legend = 11`),
  /// clamped to range. Replaces the old free-standing `rankIndex` helper.
  int indexOfLetter(String letter) {
    final i = ranks.indexWhere((r) => r.letter == letter);
    return i < 0 ? 0 : i;
  }

  /// Whether the given [level] is already at the highest defined rank.
  bool isMaxRank(int level) => rankForLevel(level).tier >= ranks.last.tier;

  /// The next rank above the one held at [level], or `null` if already max.
  HunterRank? nextRank(int level) {
    final cur = rankForLevel(level);
    if (cur.tier >= ranks.last.tier) return null;
    return ranks[cur.tier + 1];
  }

  /// The level at which the next rank begins, or `null` if already max.
  int? nextRankLevel(int level) => nextRank(level)?.minLevel;

  /// XP remaining to reach the next rank, computed from [level] and the
  /// in-level [xpIntoLevel] remainder (the stored `xp` field, 0–499).
  /// Returns 0 when already at the max rank.
  int xpToNextRank(int level, int xpIntoLevel) {
    final nr = nextRank(level);
    if (nr == null) return 0;
    final levelsRemaining = nr.minLevel - level; // always >= 1 here
    final remaining = (levelsRemaining * xpPerLevel) - xpIntoLevel;
    return remaining < 0 ? 0 : remaining;
  }

  /// Progress (0.0–1.0) across the CURRENT rank band toward the next rank,
  /// factoring the in-level [xpIntoLevel] remainder for a smooth bar.
  /// Returns 1.0 at the max rank.
  double progressToNextRank(int level, int xpIntoLevel) {
    final cur = rankForLevel(level);
    final nr = nextRank(level);
    if (nr == null) return 1.0;
    final bandLevels = nr.minLevel - cur.minLevel; // e.g. 5
    if (bandLevels <= 0) return 1.0;
    final done = (level - cur.minLevel) * xpPerLevel + xpIntoLevel;
    final total = bandLevels * xpPerLevel;
    final p = done / total;
    if (p < 0.0) return 0.0;
    if (p > 1.0) return 1.0;
    return p;
  }
}
