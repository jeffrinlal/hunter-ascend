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
  /// Single-character rank code: `E`, `D`, `C`, `B`, `A`, `S`.
  final String letter;

  /// Ordinal position of the rank, `E = 0` … `S = 5`. Useful for scoring and
  /// comparisons without hard-coding the letter order elsewhere.
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
  /// the exact same canonical rank (e.g. the Max dashboard renders "SHADOW
  /// MONARCH" for rank S). This is display-only: it never affects how a rank is
  /// calculated. Screens that don't opt into the premium presentation simply
  /// use [letter]/[shortTitle]/[longTitle] instead.
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
  Color get color {
    switch (letter) {
      case 'S':
        return HunterTheme.gold;
      case 'A':
        return HunterTheme.danger;
      case 'B':
        return HunterTheme.purple;
      case 'C':
        return HunterTheme.info;
      case 'D':
        return HunterTheme.success;
      case 'E':
      default:
        return HunterTheme.textSecondary;
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
  /// Thresholds preserve the app's existing level-based bands:
  /// E: 1–4 · D: 5–9 · C: 10–14 · B: 15–19 · A: 20–29 · S: 30+.
  ///
  /// [displayTitle] is a premium, cosmetic-only alias for each canonical rank
  /// (used by the Max dashboard). It escalates to "SHADOW MONARCH" at rank S.
  /// New tiers (e.g. National Level, Monarch) can be appended here in a future
  /// phase without touching any screen.
  static const List<HunterRank> ranks = [
    HunterRank(letter: 'E', tier: 0, minLevel: 1, label: 'E Rank', shortTitle: 'E RANK', longTitle: 'E RANK HUNTER', displayTitle: 'AWAKENED'),
    HunterRank(letter: 'D', tier: 1, minLevel: 5, label: 'D Rank', shortTitle: 'D RANK', longTitle: 'D RANK HUNTER', displayTitle: 'RISING HUNTER'),
    HunterRank(letter: 'C', tier: 2, minLevel: 10, label: 'C Rank', shortTitle: 'C RANK', longTitle: 'C RANK HUNTER', displayTitle: 'ELITE HUNTER'),
    HunterRank(letter: 'B', tier: 3, minLevel: 15, label: 'B Rank', shortTitle: 'B RANK', longTitle: 'B RANK HUNTER', displayTitle: 'MASTER HUNTER'),
    HunterRank(letter: 'A', tier: 4, minLevel: 20, label: 'A Rank', shortTitle: 'A RANK', longTitle: 'A RANK HUNTER', displayTitle: 'SOVEREIGN'),
    HunterRank(letter: 'S', tier: 5, minLevel: 30, label: 'S Rank', shortTitle: 'S RANK', longTitle: 'S RANK HUNTER', displayTitle: 'SHADOW MONARCH'),
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

  /// Ordinal tier for a level's rank (`E = 0` … `S = 5`).
  int tierForLevel(int level) => rankForLevel(level).tier;

  /// Ordinal index of a rank [letter] (`E = 0` … `S = 5`), clamped to range.
  /// Replaces the old free-standing `rankIndex` helper.
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
