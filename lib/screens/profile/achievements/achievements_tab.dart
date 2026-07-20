import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/achievement.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/services/achievements_service.dart';

/// Premium RPG-style Achievements screen (hosted as a Profile tab).
///
/// Unlock state and XP are driven by [AchievementsService] against Firestore
/// (see that service's doc comment) — this screen never claims anything or
/// awards XP itself; it only calls [AchievementsService.evaluate] to get an
/// up-to-date status list for display and to surface any celebration dialogs
/// queued by evaluation (including ones claimed by the BACKGROUND listener
/// while this tab wasn't even open — evaluation isn't gated on this screen).
class AchievementsTab extends StatefulWidget {
  final HunterData hunter;
  const AchievementsTab({super.key, required this.hunter});

  @override
  State<AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  bool _ready = false;
  List<AchievementStatus> _statuses = [];
  AchievementCategory? _category; // null = All
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAndEvaluate(widget.hunter);
  }

  @override
  void didUpdateWidget(AchievementsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-evaluate whenever the hunter data this tab was built with changes
    // (e.g. the underlying HunterRepository stream emitted a new snapshot
    // while this tab was visible) — never on every rebuild for the SAME
    // data, so this doesn't spam Firestore reads/writes.
    if (oldWidget.hunter != widget.hunter) {
      _loadAndEvaluate(widget.hunter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndEvaluate(HunterData hunter) async {
    await AchievementsService.instance.ensureLoaded();
    final statuses = await AchievementsService.instance.evaluate(hunter);
    if (!mounted) return;
    setState(() {
      _statuses = statuses;
      _ready = true;
    });
    // Celebrate anything newly unlocked by this (or a background) pass.
    AchievementsService.instance.showPendingUnlockDialogs(context);
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
              colors: [HunterTheme.primary.withOpacity(0.16), HunterTheme.cardColor],
            ),
            border: Border.all(color: HunterTheme.primary.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: CircularProgressIndicator(color: HunterTheme.primary, strokeWidth: 2.5),
          ),
        ),
      );
    }

    final all = _statuses;

    // Apply category + search filters.
    final q = _query.trim().toLowerCase();
    final filtered = all.where((s) {
      if (_category != null && s.achievement.category != _category) return false;
      if (q.isEmpty) return true;
      // Hidden+locked achievements keep their secrecy in search.
      final hiddenLocked = s.achievement.hidden && !s.unlocked;
      if (hiddenLocked) return false;
      return s.achievement.name.toLowerCase().contains(q) ||
          s.achievement.description.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        // Unlocked first, then by progress, then by rarity (legendary first).
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        final p = b.progress.compareTo(a.progress);
        if (p != 0) return p;
        return b.achievement.rarity.index.compareTo(a.achievement.rarity.index);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _buildHeader(all),
        const SizedBox(height: 16),
        _buildSearch(),
        const SizedBox(height: 14),
        _buildCategoryChips(all),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _buildEmptyState()
        else
          ...filtered.map(_buildCard),
      ],
    );
  }

  // ── Header: completion ring + rarity breakdown ──────────────────────────
  Widget _buildHeader(List<AchievementStatus> all) {
    final total = all.length;
    final unlocked = all.where((s) => s.unlocked).length;
    final pct = total == 0 ? 0.0 : unlocked / total;
    final earnedXp = all.where((s) => s.unlocked).fold<int>(0, (sum, s) => sum + s.achievement.rewardXp);

    int rarityUnlocked(AchievementRarity r) =>
        all.where((s) => s.unlocked && s.achievement.rarity == r).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HunterTheme.primary.withOpacity(0.12), HunterTheme.gold.withOpacity(0.06), HunterTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HunterTheme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(HunterTheme.isDark ? 0.22 : 0.05), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Completion ring
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
                          valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.primary),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('DONE',
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
                    Text('ACHIEVEMENTS',
                        style: TextStyle(color: HunterTheme.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('$unlocked of $total unlocked',
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.bolt_rounded, color: HunterTheme.gold, size: 15),
                      const SizedBox(width: 4),
                      Text('${_fmt(earnedXp)} XP earned',
                          style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Rarity breakdown
          Row(
            children: [
              for (final r in AchievementRarity.values) ...[
                if (r != AchievementRarity.common) const SizedBox(width: 8),
                Expanded(child: _rarityStat(r, rarityUnlocked(r))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _rarityStat(AchievementRarity r, int count) {
    final c = r.color;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: c, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(r.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────
  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search achievements...',
        hintStyle: TextStyle(color: HunterTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: HunterTheme.textSecondary, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                child: Icon(Icons.close_rounded, color: HunterTheme.textTertiary, size: 18),
              ),
        isDense: true,
        filled: true,
        fillColor: HunterTheme.cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: HunterTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: HunterTheme.primary, width: 1.4),
        ),
      ),
    );
  }

  // ── Category filter chips ────────────────────────────────────────────────
  Widget _buildCategoryChips(List<AchievementStatus> all) {
    final cats = AchievementCategory.values;
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', Icons.grid_view_rounded, _category == null, () => setState(() => _category = null)),
          for (final c in cats)
            _chip(c.label, c.icon, _category == c, () => setState(() => _category = c)),
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
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: HunterTheme.primaryGradient)
                : null,
            color: selected ? null : HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : HunterTheme.border),
            boxShadow: selected
                ? [BoxShadow(color: HunterTheme.primary.withOpacity(0.3 * HunterTheme.glowStrength), blurRadius: 10)]
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

  // ── Achievement card ─────────────────────────────────────────────────────
  Widget _buildCard(AchievementStatus status) {
    final a = status.achievement;
    final unlocked = status.unlocked;
    final rc = a.rarity.color;
    final hiddenLocked = a.hidden && !unlocked;
    final title = hiddenLocked ? '???' : a.name;
    final desc = hiddenLocked ? 'Hidden achievement — keep playing to reveal it.' : a.description;
    final legendaryGlow = unlocked && a.rarity == AchievementRarity.legendary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [rc.withOpacity(0.13), HunterTheme.cardColor])
            : null,
        color: unlocked ? null : HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unlocked ? rc.withOpacity(0.5) : HunterTheme.border,
          width: unlocked ? 1.4 : 1,
        ),
        boxShadow: [
          if (legendaryGlow)
            BoxShadow(color: rc.withOpacity(0.28 * HunterTheme.glowStrength), blurRadius: 20, spreadRadius: 0.5, offset: const Offset(0, 4))
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
                colors: unlocked
                    ? [rc.withOpacity(0.30), rc.withOpacity(0.10)]
                    : [HunterTheme.border, HunterTheme.cardColor],
              ),
              border: Border.all(color: unlocked ? rc.withOpacity(0.6) : HunterTheme.border),
              boxShadow: unlocked
                  ? [BoxShadow(color: rc.withOpacity(0.35 * a.rarity.glow * HunterTheme.glowStrength), blurRadius: 14)]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  hiddenLocked ? Icons.help_rounded : a.icon,
                  color: unlocked ? rc : HunterTheme.textTertiary,
                  size: 26,
                ),
                if (!unlocked)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HunterTheme.cardColor,
                        border: Border.all(color: HunterTheme.border),
                      ),
                      child: Icon(Icons.lock_rounded, size: 10, color: HunterTheme.textTertiary),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unlocked ? HunterTheme.textPrimary : HunterTheme.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, color: rc, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    _pill(a.rarity.label, rc),
                    const SizedBox(width: 6),
                    _rewardPill(a),
                  ],
                ),
                // Progress bar for locked, trackable achievements.
                if (!unlocked && a.target != null && status.progress > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 6, color: HunterTheme.border),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: status.progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FractionallySizedBox(
                            widthFactor: v,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [rc, rc.withOpacity(0.6)])),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text('${(status.progress * 100).round()}% complete',
                      style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
                if (unlocked && status.unlockedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.event_available_rounded, color: HunterTheme.textTertiary, size: 12),
                    const SizedBox(width: 5),
                    Text('Unlocked ${_dateLabel(status.unlockedAt!)}',
                        style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }

  Widget _rewardPill(Achievement a) {
    final hasReward = a.reward != null;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: HunterTheme.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: HunterTheme.gold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasReward ? Icons.card_giftcard_rounded : Icons.bolt_rounded, color: HunterTheme.gold, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                hasReward ? a.reward! : '+${a.rewardXp} XP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: HunterTheme.gold, fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
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
                colors: [HunterTheme.primary.withOpacity(0.14), HunterTheme.cardColor],
              ),
              border: Border.all(color: HunterTheme.primary.withOpacity(0.28), width: 1.4),
            ),
            child: Icon(Icons.search_off_rounded, color: HunterTheme.primary, size: 36),
          ),
          const SizedBox(height: 18),
          Text('No achievements found',
              style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Try a different search or category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '$n';
  }
}
