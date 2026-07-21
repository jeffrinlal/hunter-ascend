import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/data/rank_rewards_catalog.dart';
import 'package:hunter_ascend/services/badge_equip_service.dart';
import 'package:hunter_ascend/services/equipped_rewards_service.dart';
import 'package:hunter_ascend/services/rank_reward_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Lightweight Hunter Rank reward inventory (hosted as a Profile tab).
///
/// Presentation only. Ownership is always answered EXCLUSIVELY by
/// [RankRewardService] (`isOwned`, `ownedRewards`, `rewardsForTier`,
/// `grantedAtFor`) — this screen never grants, revokes, or infers ownership
/// any other way. Owned/claimed rewards remain completely private; only the
/// currently-equipped BADGE (if any) is ever shown to other users.
///
/// **Equipped state** is split by reward type:
/// - [RankRewardType.badge] — the single publicly-visible slot. Read
///   directly off `widget.hunter.equippedBadgeId` (already streamed with the
///   rest of the hunter document — no extra read) and written through
///   [BadgeEquipService].
/// - Every other type (title, border, aura, dashboardTheme, reportStyle,
///   profileEffect) — private, answered by [EquippedRewardsService]
///   (`equippedIdFor`/`isEquipped`) exactly as before, written through
///   [EquippedRewardsService.equip]/`.unequip`.
///
/// This widget never writes to the ownership ledger.
class RewardsTab extends StatefulWidget {
  final HunterData hunter;
  const RewardsTab({super.key, required this.hunter});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

/// Ownership filter for the inventory list. Purely a display-side filter —
/// it never affects what is owned or granted.
enum _OwnershipFilter { all, owned, locked }

extension on _OwnershipFilter {
  String get label {
    switch (this) {
      case _OwnershipFilter.all:
        return 'All';
      case _OwnershipFilter.owned:
        return 'Owned';
      case _OwnershipFilter.locked:
        return 'Locked';
    }
  }
}

/// Sort order for the inventory list. Purely a display-side ordering — it
/// never affects ownership or equip state, only the order cards are shown.
enum _SortMode { ownedFirst, rankAscending, nameAscending }

extension on _SortMode {
  String get label {
    switch (this) {
      case _SortMode.ownedFirst:
        return 'Owned First';
      case _SortMode.rankAscending:
        return 'By Rank';
      case _SortMode.nameAscending:
        return 'By Name';
    }
  }

  IconData get icon {
    switch (this) {
      case _SortMode.ownedFirst:
        return Icons.workspace_premium_rounded;
      case _SortMode.rankAscending:
        return Icons.military_tech_rounded;
      case _SortMode.nameAscending:
        return Icons.sort_by_alpha_rounded;
    }
  }
}

class _RewardsTabState extends State<RewardsTab> {
  bool _ready = false;
  RankRewardType? _category; // null = All
  _OwnershipFilter _ownershipFilter = _OwnershipFilter.all;
  _SortMode _sortMode = _SortMode.ownedFirst;
  bool _busy = false; // guards equip/unequip taps while a write is in flight

  @override
  void initState() {
    super.initState();
    // Ownership and equipped state are loaded from their own independent
    // services — neither call depends on, or reaches into, the other's data.
    Future.wait([
      RankRewardService.instance.ensureLoadedForCurrentUser(),
      EquippedRewardsService.instance.ensureLoadedForCurrentUser(),
    ]).then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HunterTheme.gold.withOpacity(0.16), HunterTheme.cardColor],
            ),
            border: Border.all(color: HunterTheme.gold.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: CircularProgressIndicator(color: HunterTheme.gold, strokeWidth: 2.5),
          ),
        ),
      );
    }

    // Live refresh: RankRewardService/EquippedRewardsService now notify on
    // every ownership/equip change (including grants that happen in the
    // BACKGROUND while this tab is open, via RankRewardService's own
    // HunterRepository listener). Wrapping the list in this builder means a
    // newly-crossed rank tier repaints "Owned" state immediately, with no
    // need to leave and re-open this tab.
    return ListenableBuilder(
      listenable: Listenable.merge([RankRewardService.instance, EquippedRewardsService.instance]),
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final level = widget.hunter.level;
    final tier = RankService.instance.tierForLevel(level);

    // ── Ownership comes ONLY from RankRewardService ──
    final owned = RankRewardService.instance.ownedRewards.toSet();

    // ── Filtering (category + ownership) — display-side only ──
    final filtered = kRankRewards.where((r) {
      if (_category != null && r.type != _category) return false;
      switch (_ownershipFilter) {
        case _OwnershipFilter.owned:
          return owned.contains(r);
        case _OwnershipFilter.locked:
          return !owned.contains(r);
        case _OwnershipFilter.all:
          return true;
      }
    }).toList();

    // ── Sorting — display-side only, never affects ownership/equip data ──
    filtered.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.ownedFirst:
          final aOwned = owned.contains(a);
          final bOwned = owned.contains(b);
          if (aOwned != bOwned) return aOwned ? -1 : 1;
          if (a.rankTier != b.rankTier) return a.rankTier.compareTo(b.rankTier);
          return a.name.compareTo(b.name);
        case _SortMode.rankAscending:
          if (a.rankTier != b.rankTier) return a.rankTier.compareTo(b.rankTier);
          return a.name.compareTo(b.name);
        case _SortMode.nameAscending:
          return a.name.compareTo(b.name);
      }
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _buildHeader(owned, tier),
        const SizedBox(height: 16),
        _buildCategoryChips(),
        const SizedBox(height: 10),
        _buildFilterSortRow(),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ...filtered.map((r) => _buildCard(r, owned.contains(r))),
      ],
    );
  }

  // ── Header: ownership completion + current rank ─────────────────────────
  Widget _buildHeader(Set<RankReward> owned, int tier) {
    final total = kRankRewards.length;
    final unlockedCount = owned.length;
    final pct = total == 0 ? 0.0 : unlockedCount / total;
    final currentRank = RankService.instance.rankForLevel(widget.hunter.level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HunterTheme.gold.withOpacity(0.12), HunterTheme.primary.withOpacity(0.06), HunterTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HunterTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(HunterTheme.isDark ? 0.22 : 0.05), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 9,
                    valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.border),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => SizedBox(
                    width: 92,
                    height: 92,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.gold),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(pct * 100).round()}%',
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('OWNED',
                        style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('REWARDS',
                    style: TextStyle(color: HunterTheme.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('$unlockedCount of $total unlocked',
                    style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: currentRank.color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: currentRank.color.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_moon_rounded, color: currentRank.color, size: 13),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Current: ${currentRank.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: currentRank.color, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category filter chips (by reward type) ──────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', Icons.grid_view_rounded, _category == null, () => setState(() => _category = null)),
          for (final t in RankRewardType.values)
            _chip(t.label, t.icon, _category == t, () => setState(() => _category = t)),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [HunterTheme.gold, HunterTheme.goldBright])
                : null,
            color: selected ? null : HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : HunterTheme.border),
            boxShadow: selected
                ? [BoxShadow(color: HunterTheme.gold.withOpacity(0.3 * HunterTheme.glowStrength), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.black : HunterTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? Colors.black : HunterTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ownership filter + sort control row ─────────────────────────────────
  Widget _buildFilterSortRow() {
    return Row(
      children: [
        Expanded(child: _buildOwnershipFilter()),
        const SizedBox(width: 10),
        _buildSortButton(),
      ],
    );
  }

  Widget _buildOwnershipFilter() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HunterTheme.border),
      ),
      child: Row(
        children: _OwnershipFilter.values.map((f) {
          final selected = _ownershipFilter == f;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _ownershipFilter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? HunterTheme.gold.withOpacity(0.16) : null,
                  borderRadius: BorderRadius.circular(9),
                  border: selected ? Border.all(color: HunterTheme.gold.withOpacity(0.5)) : null,
                ),
                child: Text(
                  f.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? HunterTheme.gold : HunterTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<_SortMode>(
      tooltip: 'Sort',
      initialValue: _sortMode,
      onSelected: (mode) => setState(() => _sortMode = mode),
      color: HunterTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: HunterTheme.border),
      ),
      itemBuilder: (context) => _SortMode.values.map((mode) {
        final selected = _sortMode == mode;
        return PopupMenuItem<_SortMode>(
          value: mode,
          child: Row(
            children: [
              Icon(mode.icon, size: 16, color: selected ? HunterTheme.gold : HunterTheme.textSecondary),
              const SizedBox(width: 10),
              Text(
                mode.label,
                style: TextStyle(
                  color: selected ? HunterTheme.gold : HunterTheme.textPrimary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HunterTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_sortMode.icon, size: 15, color: HunterTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              _sortMode.label,
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more_rounded, size: 15, color: HunterTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Whether [reward] is currently equipped. Badges are read directly off
  /// `widget.hunter.equippedBadgeId` (the publicly-visible field, already
  /// streamed with the rest of the hunter document); every other type is
  /// answered by [EquippedRewardsService] exactly as before. Never derived
  /// from `owned` or any other ownership signal.
  bool _isEquipped(RankReward reward) {
    if (reward.type == RankRewardType.badge) {
      return widget.hunter.equippedBadgeId == reward.id;
    }
    return EquippedRewardsService.instance.isEquipped(reward);
  }

  // ── Reward card ───────────────────────────────────────────────────────
  Widget _buildCard(RankReward reward, bool owned) {
    final rc = reward.color;
    final equipped = _isEquipped(reward);
    final grantedAt = RankRewardService.instance.grantedAtFor(reward.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: owned
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [rc.withOpacity(0.13), HunterTheme.cardColor])
            : null,
        color: owned ? null : HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? rc : (owned ? rc.withOpacity(0.5) : HunterTheme.border),
          width: equipped ? 1.8 : (owned ? 1.4 : 1),
        ),
        boxShadow: [
          if (equipped)
            BoxShadow(color: rc.withOpacity(0.32 * HunterTheme.glowStrength), blurRadius: 22, spreadRadius: 0.5, offset: const Offset(0, 4))
          else
            BoxShadow(color: Colors.black.withOpacity(HunterTheme.isDark ? 0.16 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medallion
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: owned
                    ? [rc.withOpacity(0.30), rc.withOpacity(0.10)]
                    : [HunterTheme.border, HunterTheme.cardColor],
              ),
              border: Border.all(color: owned ? rc.withOpacity(0.6) : HunterTheme.border),
              boxShadow: owned ? [BoxShadow(color: rc.withOpacity(0.30 * HunterTheme.glowStrength), blurRadius: 14)] : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  owned ? reward.type.icon : Icons.lock_rounded,
                  color: owned ? rc : HunterTheme.textTertiary,
                  size: owned ? 26 : 22,
                ),
                if (equipped)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rc,
                        border: Border.all(color: HunterTheme.cardColor, width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded, size: 10, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reward.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: owned ? HunterTheme.textPrimary : HunterTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (equipped) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, color: rc, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  reward.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _pill(reward.type.label, rc),
                    const SizedBox(width: 6),
                    Flexible(child: _pill(RankService.ranks[reward.rankTier].label, HunterTheme.textTertiary)),
                  ],
                ),
                if (owned && grantedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.event_available_rounded, color: HunterTheme.textTertiary, size: 12),
                    const SizedBox(width: 5),
                    Text('Unlocked ${_dateLabel(grantedAt)}',
                        style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ]),
                ],
                if (owned) ...[
                  const SizedBox(height: 10),
                  _buildEquipButton(reward, equipped, rc),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipButton(RankReward reward, bool equipped, Color rc) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : () => _onEquipToggle(reward, equipped),
        icon: Icon(
          equipped ? Icons.close_rounded : Icons.check_circle_outline_rounded,
          size: 15,
          color: equipped ? HunterTheme.textSecondary : rc,
        ),
        label: Text(
          equipped ? 'UNEQUIP' : 'EQUIP',
          style: TextStyle(
            color: equipped ? HunterTheme.textSecondary : rc,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: equipped ? HunterTheme.border : rc.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  /// Equips/unequips [reward]. Badges are routed through [BadgeEquipService]
  /// (writes the public `equippedBadgeId` field on the hunter document —
  /// the update is picked up automatically by the live `HunterData` stream
  /// this tab already listens to, so no local state needs to be set here).
  /// Every other type keeps going through [EquippedRewardsService] exactly
  /// as before. Never touches [RankRewardService] — ownership is completely
  /// unaffected by this action, in either direction.
  Future<void> _onEquipToggle(RankReward reward, bool currentlyEquipped) async {
    setState(() => _busy = true);
    final bool ok;
    if (reward.type == RankRewardType.badge) {
      ok = currentlyEquipped
          ? await BadgeEquipService.instance.unequip()
          : await BadgeEquipService.instance.equip(reward);
    } else if (currentlyEquipped) {
      ok = await EquippedRewardsService.instance.unequip(reward.type);
    } else {
      ok = await EquippedRewardsService.instance.equip(reward);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentlyEquipped ? 'Could not unequip. Try again.' : 'Could not equip. Try again.')),
      );
    }
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HunterTheme.gold.withOpacity(0.14), HunterTheme.cardColor],
              ),
              border: Border.all(color: HunterTheme.gold.withOpacity(0.28), width: 1.4),
            ),
            child: Icon(Icons.workspace_premium_outlined, color: HunterTheme.gold, size: 36),
          ),
          const SizedBox(height: 18),
          Text('No rewards found',
              style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Try a different category or ownership filter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
