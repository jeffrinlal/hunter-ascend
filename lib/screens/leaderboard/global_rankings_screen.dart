import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/profile/public_hunter_profile_screen.dart';
import 'package:hunter_ascend/widgets/skeleton_loaders.dart';
import 'package:hunter_ascend/data/models/leaderboard_entry.dart';
import 'package:hunter_ascend/data/repositories/leaderboard_repository.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hunter_ascend/widgets/membership_badge.dart';
import 'package:hunter_ascend/services/membership_service.dart';

import '../../widgets/premium_avatar.dart';
import '../../widgets/premium_card_decorator.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';

// ── Top 3 Crown Painter ────────────────────────────────────────────────────

/// Draws the decorative badge behind a top-3 leaderboard position.
class TopRankPainter extends CustomPainter {
  final int position; // 1, 2, 3
  final Color color;

  TopRankPainter(this.position, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    if (position == 1) {
      // ── Imperial Crown ──
      final crown = Path();
      crown.moveTo(w * 0.05, h * 0.75);
      crown.lineTo(w * 0.05, h * 0.35);
      crown.lineTo(w * 0.28, h * 0.55);
      crown.lineTo(w * 0.5, h * 0.1);
      crown.lineTo(w * 0.72, h * 0.55);
      crown.lineTo(w * 0.95, h * 0.35);
      crown.lineTo(w * 0.95, h * 0.75);
      crown.close();
      canvas.drawPath(crown, fillPaint);
      canvas.drawPath(crown, paint);

      // Jewels on crown tips
      canvas.drawCircle(Offset(w * 0.5, h * 0.1), 3.5,
          Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(w * 0.05, h * 0.35), 2.5,
          Paint()..color = color..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(w * 0.95, h * 0.35), 2.5,
          Paint()..color = color..style = PaintingStyle.fill);

      // Base gems row
      for (int i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(w * (0.25 + i * 0.25), h * 0.62),
          2.0,
          Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.fill,
        );
      }

      // Number
      _drawText(canvas, '1', w / 2, h * 0.88, color, 13, FontWeight.bold);

    } else if (position == 2) {
      // ── War Blade / Sword ──
      final blade = Path();
      blade.moveTo(w * 0.5, h * 0.05);
      blade.lineTo(w * 0.62, h * 0.6);
      blade.lineTo(w * 0.5, h * 0.7);
      blade.lineTo(w * 0.38, h * 0.6);
      blade.close();
      canvas.drawPath(blade, fillPaint);
      canvas.drawPath(blade, paint);

      // Guard / crossguard
      canvas.drawLine(Offset(w * 0.15, h * 0.62), Offset(w * 0.85, h * 0.62), paint);

      // Handle
      canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.5, h * 0.92), paint);
      // Pommel
      canvas.drawCircle(Offset(w * 0.5, h * 0.93), 4,
          Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8);

      _drawText(canvas, '2', w * 0.5, h * 0.88, color, 10, FontWeight.bold);

    } else {
      // ── Shield ──
      final shield = Path();
      shield.moveTo(w * 0.5, h * 0.06);
      shield.lineTo(w * 0.92, h * 0.22);
      shield.lineTo(w * 0.92, h * 0.55);
      shield.quadraticBezierTo(w * 0.92, h * 0.82, w * 0.5, h * 0.96);
      shield.quadraticBezierTo(w * 0.08, h * 0.82, w * 0.08, h * 0.55);
      shield.lineTo(w * 0.08, h * 0.22);
      shield.close();
      canvas.drawPath(shield, fillPaint);
      canvas.drawPath(shield, paint);

      // Shield inner bevel
      final inner = Path();
      inner.moveTo(w * 0.5, h * 0.15);
      inner.lineTo(w * 0.82, h * 0.28);
      inner.lineTo(w * 0.82, h * 0.55);
      inner.quadraticBezierTo(w * 0.82, h * 0.75, w * 0.5, h * 0.87);
      inner.quadraticBezierTo(w * 0.18, h * 0.75, w * 0.18, h * 0.55);
      inner.lineTo(w * 0.18, h * 0.28);
      inner.close();
      canvas.drawPath(inner,
          Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.stroke..strokeWidth = 1);

      _drawText(canvas, '3', w / 2, h * 0.55, color, 18, FontWeight.bold);
    }
  }

  void _drawText(Canvas canvas, String text, double x, double y,
      Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(TopRankPainter old) =>
      old.position != position || old.color != color;
}

// ── Top Rank Badge Widget ──────────────────────────────────────────────────

/// Top-3 rank badge widget (wraps [TopRankPainter]).
class TopRankBadge extends StatelessWidget {
  final int position;
  final Color color;
  final double size;

  const TopRankBadge({
    super.key,
    required this.position,
    required this.color,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: TopRankPainter(position, color),
    );
  }
}

// ── Global Rankings Screen ─────────────────────────────────────────────────

/// Global leaderboard ranked by level then XP, with search.
class GlobalRankingsScreen extends StatefulWidget {
  const GlobalRankingsScreen({super.key});

  @override
  State<GlobalRankingsScreen> createState() =>
      _GlobalRankingsScreenState();
}

class _GlobalRankingsScreenState extends State<GlobalRankingsScreen>
    with SingleTickerProviderStateMixin {

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // ── Tab controller for Overall / Weekly / Daily ──
  late final TabController _tabController = TabController(length: 3, vsync: this);
  LeaderboardTab _activeTab = LeaderboardTab.overall;

  // ── Leaderboard data (from repository) ──
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;

  // Caches decoded avatar bytes keyed by the Base64 string, so each unique
  // profile picture is decoded only once and the same Uint8List is reused
  // across scrolls/rebuilds (re-decodes only when the Base64 string changes).
  final Map<String, Uint8List> _avatarCache = {};

  Uint8List _decodedAvatar(String base64Data) =>
      _avatarCache[base64Data] ??= base64Decode(base64Data);

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final tabs = [LeaderboardTab.overall, LeaderboardTab.weekly, LeaderboardTab.daily];
    setState(() => _activeTab = tabs[_tabController.index]);
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    // Show cached data instantly.
    final cached = LeaderboardRepository.instance.getCached(_activeTab);
    if (cached != null && cached.isNotEmpty) {
      setState(() { _entries = cached; _loading = false; });
    } else {
      setState(() => _loading = true);
    }
    // Refresh in background (or immediately if stale/empty).
    final fresh = await LeaderboardRepository.instance.fetch(_activeTab);
    if (mounted) {
      setState(() { _entries = fresh; _loading = false; });
    }
  }

  String getRankTitle(int level) {
    if (level >= 30) return 'S Rank';
    if (level >= 20) return 'A Rank';
    if (level >= 15) return 'B Rank';
    if (level >= 10) return 'C Rank';
    if (level >= 5)  return 'D Rank';
    return 'E Rank';
  }

  Color _rankColor(int level) {
    if (level >= 30) return HunterTheme.danger;
    if (level >= 20) return HunterTheme.primary;
    if (level >= 15) return HunterTheme.purple;
    if (level >= 10) return HunterTheme.info;
    if (level >= 5)  return HunterTheme.successAlt;
    return HunterTheme.primary;
  }

  // ── Membership resolution helpers ──────────────────────────────────────
  //
  // The rewarded-ad membership system stores the tier in `membershipType`.
  // Older/legacy documents may still use `membership`. These helpers resolve
  // a hunter's EFFECTIVE membership so every viewer sees the correct premium
  // styling for any player, and expired memberships are treated as Basic.

  DateTime? _parseExpiry(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Resolves the effective membership string for a hunter document,
  /// honoring the new `membershipType` field, the legacy `membership`
  /// field, and expiry. Returns `'basic'` if expired or unset.
  String _effectiveMembership(Map<String, dynamic>? data) {
    if (data == null) return 'basic';
    final raw = (data['membershipType'] ?? data['membership'] ?? 'basic')
        .toString();
    final tier = MembershipTier.fromString(raw);
    if (tier == MembershipTier.basic) return 'basic';
    final expiry = _parseExpiry(data['membershipExpiry']);
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'basic';
    return raw;
  }

  /// Whether the given membership string is a premium (Pro/Max) tier.
  bool _isPremium(String membership) =>
      MembershipTier.fromString(membership) != MembershipTier.basic;

  // Position-specific colors
  Color _positionColor(int index) {
    if (index == 0) return HunterTheme.goldBright; // Gold
    if (index == 1) return HunterTheme.silver; // Steel silver
    if (index == 2) return HunterTheme.bronze; // Bronze
    return HunterTheme.textSecondary;
  }

  /// Resolves effective membership from a LeaderboardEntry.
  String _entryMembership(LeaderboardEntry entry) {
    final raw = entry.membership ?? 'basic';
    final tier = MembershipTier.fromString(raw);
    if (tier == MembershipTier.basic) return 'basic';
    final expiry = _parseExpiry(entry.membershipExpiry);
    if (expiry != null && expiry.isBefore(DateTime.now())) return 'basic';
    return raw;
  }

  /// Returns the appropriate XP label based on active tab.
  String _xpLabel(LeaderboardEntry entry) {
    switch (_activeTab) {
      case LeaderboardTab.weekly: return '${entry.weeklyXp} WXP';
      case LeaderboardTab.daily: return '${entry.dailyXp} DXP';
      case LeaderboardTab.overall: return '${entry.xp} XP';
    }
  }

  // ── Podium item (top 3) using LeaderboardEntry ──────────────────────────
  Widget _buildPodiumItem(
      BuildContext context, List<LeaderboardEntry> entries, int index, String? currentUid) {
    if (index >= entries.length) return const Expanded(child: SizedBox());

    final entry = entries[index];
    final isMe = entry.uid == currentUid;
    final level = entry.level;
    final rc = _rankColor(level);
    final posColor = _positionColor(index);
    final isFirst = index == 0;
    final membership = _entryMembership(entry);
    final double avatarSize = isFirst ? 76 : 60;
    final double pedestalHeight = index == 0 ? 78 : (index == 1 ? 58 : 44);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (entry.uid == currentUid) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => PublicHunterProfileScreen(hunterUid: entry.uid)));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              TopRankBadge(position: index + 1, color: posColor, size: isFirst ? 42 : 32),
              const SizedBox(height: 8),
              // Avatar with a medal-colored glow ring (stronger for #1).
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: posColor.withOpacity(isFirst ? 0.55 : 0.35),
                      blurRadius: isFirst ? 22 : 12,
                      spreadRadius: isFirst ? 2 : 1,
                    ),
                  ],
                ),
                child: PremiumAvatar(
                  membership: membership,
                  radius: avatarSize / 2,
                  image: entry.profilePicture != null && entry.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(entry.profilePicture!)) : null,
                  child: Icon(Icons.person, color: rc, size: isFirst ? 38 : 30),
                ),
              ),
              const SizedBox(height: 8),
              Text(entry.hunterName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: isMe ? HunterTheme.primary : HunterTheme.textPrimary, fontSize: isFirst ? 15 : 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              MembershipBadge(membership: membership, fontSize: 7),
              const SizedBox(height: 3),
              Text('${getRankTitle(level)} \u00b7 Lv.$level', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 10)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: HunterTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: HunterTheme.primary.withOpacity(0.3))),
                child: Text(_xpLabel(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: HunterTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(height: 10),
              Container(
                height: pedestalHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [posColor.withOpacity(0.9), posColor.withOpacity(0.4)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  boxShadow: [BoxShadow(color: posColor.withOpacity(0.3), blurRadius: 14, spreadRadius: 1)],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: Colors.white, fontSize: isFirst ? 28 : 20, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  // Premium search field (behaviour unchanged: filters by name on change).
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) {
        setState(() {
          _searchText = value.trim();
        });
      },
      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search hunters by name...',
        hintStyle: TextStyle(color: HunterTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: HunterTheme.textSecondary, size: 20),
        isDense: true,
        filled: true,
        fillColor: HunterTheme.background.withOpacity(0.35),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // Premium segmented tab bar (TabController wiring unchanged).
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunterTheme.border),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: HunterTheme.primary,
        unselectedLabelColor: HunterTheme.textTertiary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: HunterTheme.primary.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HunterTheme.primary.withOpacity(0.3)),
        ),
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.circular(10),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        tabs: const [
          Tab(text: '\u{1F3C6} Overall'),
          Tab(text: '\u{1F4C5} Weekly'),
          Tab(text: '\u26A1 Daily'),
        ],
      ),
    );
  }

  // Premium empty / no-results state.
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    final accent = HunterTheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.12),
                border: Border.all(color: accent.withOpacity(0.35), width: 1.4),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 18)],
              ),
              child: Icon(icon, color: accent, size: 34),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    // Same ranking computation as the body — used to surface the player's
    // current rank in the hero.
    int myRank = 0;
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].uid == currentUid) { myRank = i + 1; break; }
    }
    final limit = _activeTab == LeaderboardTab.overall ? 30 : 20;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            EntranceFadeSlide(
              child: _LeaderboardHero(
                myRank: myRank,
                limit: limit,
                searchMode: _searchMode,
                onToggleSearch: () {
                  setState(() {
                    if (_searchMode) {
                      _searchMode = false;
                      _searchText = '';
                      _searchController.clear();
                    } else {
                      _searchMode = true;
                    }
                  });
                },
                searchField: _searchMode ? _buildSearchField() : null,
              ),
            ),
            const SizedBox(height: 14),
            _buildTabBar(),
            const SizedBox(height: 10),
            // ── Content ──
            Expanded(
              child: _loading && _entries.isEmpty
                  ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: buildLeaderboardSkeleton())
                  : RefreshIndicator(
                      color: HunterTheme.primary,
                      onRefresh: () async {
                        final fresh = await LeaderboardRepository.instance.fetch(_activeTab, forceRefresh: true);
                        if (mounted) setState(() => _entries = fresh);
                      },
                      child: _buildLeaderboardBody(currentUid),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardBody(String? currentUid) {
    // Apply search filter if in search mode.
    final isSearching = _searchMode && _searchText.isNotEmpty;
    final entries = isSearching
        ? _entries.where((e) => e.hunterName.toLowerCase().contains(_searchText.toLowerCase())).toList()
        : _entries;
    int myRank = 0;
    for (int i = 0; i < _entries.length; i++) { if (_entries[i].uid == currentUid) { myRank = i + 1; break; } }
    final limit = _activeTab == LeaderboardTab.overall ? 30 : 20;

    // Empty search results
    if (isSearching && entries.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No hunters found',
              subtitle: 'Try searching for a different name.',
            ),
          ),
        ],
      );
    }

    // No rankings available at all
    if (!isSearching && entries.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              icon: Icons.emoji_events_rounded,
              title: 'No rankings yet',
              subtitle: 'Be the first to claim the throne — complete missions to earn XP.',
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Your Position (hidden during search)
        if (!isSearching)
          SliverToBoxAdapter(child: EntranceFadeSlide(child: _buildYourPosition(currentUid, myRank, limit))),
        // Podium (hidden during search — filtered results don't have ranked positions)
        if (!isSearching && entries.isNotEmpty)
          SliverToBoxAdapter(
            child: EntranceFadeSlide(
              delay: const Duration(milliseconds: 80),
              child: _buildPodium(context, entries, currentUid),
            ),
          ),
        // Divider
        if (!isSearching) SliverToBoxAdapter(child: _buildListDivider()),
        // List items — during search: show all filtered results; normal: show #4+
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, listIndex) {
                final index = isSearching ? listIndex : listIndex + 3;
                if (index >= entries.length) return null;
                return _buildListItem(context, entries[index], index, currentUid);
              },
              childCount: isSearching ? entries.length : (entries.length > 3 ? entries.length - 3 : 0),
            ),
          ),
        ),
      ],
    );
  }

  // Top-3 podium row (center = #1). Order preserved: 2nd, 1st, 3rd.
  Widget _buildPodium(BuildContext context, List<LeaderboardEntry> entries, String? currentUid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumItem(context, entries, 1, currentUid),
          _buildPodiumItem(context, entries, 0, currentUid),
          _buildPodiumItem(context, entries, 2, currentUid),
        ],
      ),
    );
  }

  Widget _buildListDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('LEADERBOARD', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08))),
      ]),
    );
  }

  Widget _youPill(bool isPremium) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPremium ? Colors.white.withOpacity(0.18) : HunterTheme.primary.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isPremium ? Colors.white.withOpacity(0.5) : HunterTheme.primary.withOpacity(0.4)),
      ),
      child: Text('YOU', style: TextStyle(color: isPremium ? Colors.white : HunterTheme.primary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }

  Widget _xpChip(LeaderboardEntry entry, bool isPremium) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPremium ? Colors.white.withOpacity(0.15) : HunterTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPremium ? Colors.white.withOpacity(0.45) : HunterTheme.primary.withOpacity(0.3)),
      ),
      child: Text(_xpLabel(entry), style: TextStyle(color: isPremium ? Colors.white : HunterTheme.primary, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  // Premium ranking-list card (#4+). All ranking/membership/navigation logic
  // preserved; only the visual presentation changed.
  Widget _buildListItem(BuildContext context, LeaderboardEntry entry, int index, String? currentUid) {
    final isMe = entry.uid == currentUid;
    final level = entry.level;
    final rc = _rankColor(level);
    final membership = _entryMembership(entry);
    final isPremium = _isPremium(membership);
    final nameColor = isPremium ? Colors.white : (isMe ? HunterTheme.primary : HunterTheme.textPrimary);
    final subColor = isPremium ? Colors.white70 : HunterTheme.textSecondary;

    return GestureDetector(
      onTap: () {
        if (entry.uid == currentUid) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => PublicHunterProfileScreen(hunterUid: entry.uid)));
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PremiumCardDecorator(
          membership: membership,
          animated: false,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isPremium ? Colors.transparent : (isMe ? HunterTheme.primary.withOpacity(0.08) : HunterTheme.cardColor),
              borderRadius: BorderRadius.circular(16),
              border: isPremium ? null : Border.all(color: isMe ? HunterTheme.primary.withOpacity(0.5) : HunterTheme.border, width: isMe ? 1.5 : 1),
              boxShadow: isPremium ? null : [BoxShadow(color: (isMe ? HunterTheme.primary : Colors.black).withOpacity(isMe ? 0.10 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isPremium ? Colors.white : (isMe ? HunterTheme.primary : HunterTheme.textTertiary),
                      fontSize: index < 9 ? 15 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PremiumAvatar(
                membership: membership,
                radius: 20,
                image: entry.profilePicture != null && entry.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(entry.profilePicture!)) : null,
                child: Icon(Icons.person, color: rc, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(child: Text(entry.hunterName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: nameColor, fontSize: 14.5, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      MembershipBadge(membership: membership, fontSize: 8),
                      if (isMe) ...[const SizedBox(width: 6), _youPill(isPremium)],
                    ]),
                    const SizedBox(height: 3),
                    Text('${getRankTitle(level)}  \u00b7  Lv.$level', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subColor, fontSize: 11.5, letterSpacing: 0.3, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _xpChip(entry, isPremium),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildYourPosition(String? currentUid, int myRank, int limit) {
    final hunter = HunterRepository.instance.getCached();
    if (hunter == null) return const SizedBox.shrink();
    final myMembership = _effectiveMembership({'membershipType': hunter.membershipType, 'membershipExpiry': hunter.membershipExpiry});
    final myPremium = _isPremium(myMembership);
    final labelColor = myPremium ? Colors.white : HunterTheme.primary;
    final nameColor = myPremium ? Colors.white : HunterTheme.textPrimary;
    final subColor = myPremium ? Colors.white70 : HunterTheme.textSecondary;
    final rankText = myRank > 0 ? '#$myRank' : '$limit+';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: PremiumCardDecorator(
        membership: myMembership,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: myPremium ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [HunterTheme.primary.withOpacity(0.14), HunterTheme.cardColor]),
            color: myPremium ? Colors.transparent : null,
            border: myPremium ? null : Border.all(color: HunterTheme.primary.withOpacity(0.4), width: 1.5),
            boxShadow: myPremium ? null : [BoxShadow(color: HunterTheme.primary.withOpacity(0.12), blurRadius: 20, spreadRadius: 1)],
          ),
          child: Row(children: [
            // Prominent rank badge.
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('RANK', style: TextStyle(color: labelColor.withOpacity(0.85), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 1),
              Text(rankText, style: TextStyle(color: labelColor, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(width: 16),
            PremiumAvatar(
              membership: myMembership,
              radius: 24,
              image: hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(hunter.profilePicture!)) : null,
              child: Icon(Icons.person, color: _rankColor(hunter.level), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('YOUR POSITION', style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(hunter.hunterName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: nameColor, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${getRankTitle(hunter.level)}  \u00b7  Lv.${hunter.level}  \u00b7  ${hunter.xp} XP', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subColor, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}



/// Immersive leaderboard hero.
///
/// Presentation-only. Shows the title, a trophy medallion, the player's
/// current rank (or the search field when searching), and a subtle pulsing
/// glow. The glow uses a single controller and the [AnimatedBuilder.child]
/// pattern so only the decoration repaints per frame (content — including the
/// search field — is not rebuilt by the animation).
class _LeaderboardHero extends StatefulWidget {
  final int myRank;
  final int limit;
  final bool searchMode;
  final VoidCallback onToggleSearch;
  final Widget? searchField;

  const _LeaderboardHero({
    required this.myRank,
    required this.limit,
    required this.searchMode,
    required this.onToggleSearch,
    this.searchField,
  });

  @override
  State<_LeaderboardHero> createState() => _LeaderboardHeroState();
}

class _LeaderboardHeroState extends State<_LeaderboardHero> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.primary;
    final rankText = widget.myRank > 0 ? '#${widget.myRank}' : '${widget.limit}+';

    final topRow = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, accent.withOpacity(0.7)]),
          ),
          child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('GLOBAL RANKINGS', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 3),
              Text('Climb the ranks, Hunter.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onToggleSearch,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HunterTheme.background.withOpacity(0.35),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Icon(widget.searchMode ? Icons.close_rounded : Icons.search_rounded, color: HunterTheme.textSecondary, size: 20),
          ),
        ),
      ],
    );

    final Widget lowerSection = widget.searchField != null
        ? widget.searchField!
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.leaderboard_rounded, color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('YOUR RANK', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    const SizedBox(height: 1),
                    Text(
                      widget.myRank > 0 ? 'Keep climbing' : 'Enter the rankings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [HunterTheme.gold, HunterTheme.goldBright]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: HunterTheme.gold.withOpacity(0.35), blurRadius: 8)],
                ),
                child: Text(rankText, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ]),
          );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        topRow,
        const SizedBox(height: 14),
        lowerSection,
      ],
    );

    return AnimatedBuilder(
      animation: _glow,
      child: content,
      builder: (context, child) {
        final g = _glow.value;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withOpacity(0.20), accent.withOpacity(0.05), HunterTheme.cardColor],
            ),
            border: Border.all(color: accent.withOpacity(0.30 + g * 0.20), width: 1.4),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.10 + g * 0.12), blurRadius: 22, spreadRadius: 1)],
          ),
          child: child,
        );
      },
    );
  }
}
