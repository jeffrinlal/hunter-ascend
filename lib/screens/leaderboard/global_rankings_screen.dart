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
              TopRankBadge(position: index + 1, color: posColor, size: isFirst ? 40 : 32),
              const SizedBox(height: 8),
              PremiumAvatar(membership: membership, radius: avatarSize / 2,
                image: entry.profilePicture != null && entry.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(entry.profilePicture!)) : null,
                child: Icon(Icons.person, color: rc, size: isFirst ? 38 : 30)),
              const SizedBox(height: 8),
              Column(children: [
                Text(entry.hunterName, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: isMe ? HunterTheme.primary : HunterTheme.textPrimary, fontSize: isFirst ? 15 : 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                MembershipBadge(membership: membership, fontSize: 7),
              ]),
              const SizedBox(height: 2),
              Text('${getRankTitle(level)} · Lv.$level', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 10)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: HunterTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: HunterTheme.primary.withOpacity(0.3))),
                child: Text(_xpLabel(entry), style: TextStyle(color: HunterTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(height: 10),
              Container(
                height: pedestalHeight, width: double.infinity,
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [posColor.withOpacity(0.85), posColor.withOpacity(0.45)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(10)), boxShadow: [BoxShadow(color: posColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]),
                child: Center(child: Text('${index + 1}', style: TextStyle(color: HunterTheme.textPrimary, fontSize: isFirst ? 26 : 20, fontWeight: FontWeight.w900))),
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

  Widget _rankHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: _searchMode
                ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim();
                });
              },
              style: TextStyle(color: HunterTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter Hunter ID...',
                hintStyle: TextStyle(color: HunterTheme.textSecondary),
                border: InputBorder.none,
              ),
            )
                : Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: HunterTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HunterTheme.primary.withOpacity(0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.military_tech,
                    color: HunterTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'GLOBAL RANKINGS',
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _searchMode ? Icons.close : Icons.search,
              color: HunterTheme.textSecondary,
            ),
            onPressed: () {
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
          ),
        ],
      ),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _rankHeader(),
            // ── Tab Bar ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HunterTheme.border),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: HunterTheme.primary,
                unselectedLabelColor: HunterTheme.textTertiary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: HunterTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerHeight: 0,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                tabs: const [
                  Tab(text: '\u{1F3C6} Overall'),
                  Tab(text: '\u{1F4C5} Weekly'),
                  Tab(text: '\u26A1 Daily'),
                ],
              ),
            ),
            const SizedBox(height: 8),
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
            child: Center(child: Text('No hunters found', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 14))),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Your Position (hidden during search)
        if (!isSearching) SliverToBoxAdapter(child: _buildYourPosition(currentUid, myRank, limit)),
        // Podium (hidden during search — filtered results don't have ranked positions)
        if (!isSearching && entries.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [_buildPodiumItem(context, entries, 1, currentUid), _buildPodiumItem(context, entries, 0, currentUid), _buildPodiumItem(context, entries, 2, currentUid)]))),
        // Divider
        if (!isSearching) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Row(children: [Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08))), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('LEADERBOARD', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold))), Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08)))]))),
        // List items — during search: show all filtered results; normal: show #4+
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, listIndex) {
          final index = isSearching ? listIndex : listIndex + 3;
          if (index >= entries.length) return null;
          final entry = entries[index];
          final isMe = entry.uid == currentUid;
          final level = entry.level;
          final rc = _rankColor(level);
          final membership = _entryMembership(entry);
          final isPremium = _isPremium(membership);
          final nameColor = isPremium ? Colors.white : (isMe ? HunterTheme.primary : HunterTheme.textPrimary);
          final subColor = isPremium ? Colors.white70 : rc.withOpacity(0.7);
          return GestureDetector(onTap: () { if (entry.uid == currentUid) return; Navigator.push(context, MaterialPageRoute(builder: (_) => PublicHunterProfileScreen(hunterUid: entry.uid))); },
            child: Padding(padding: const EdgeInsets.only(bottom: 8), child: PremiumCardDecorator(membership: membership, animated: false, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: isPremium ? Colors.transparent : (isMe ? HunterTheme.surface : HunterTheme.cardColor), borderRadius: BorderRadius.circular(14), border: isPremium ? null : Border.all(color: isMe ? HunterTheme.primary.withOpacity(0.4) : HunterTheme.textPrimary.withOpacity(0.06), width: 1), boxShadow: isPremium ? null : [BoxShadow(color: HunterTheme.primary.withOpacity(0.04), blurRadius: 10)]),
              child: Row(children: [
                SizedBox(width: 40, child: Center(child: Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: isPremium ? Colors.white.withOpacity(0.15) : (isMe ? HunterTheme.primary.withOpacity(0.12) : HunterTheme.textPrimary.withOpacity(0.04)), border: Border.all(color: isPremium ? Colors.white.withOpacity(0.4) : (isMe ? HunterTheme.primary.withOpacity(0.4) : HunterTheme.textPrimary.withOpacity(0.08)))), child: Center(child: Text('${index + 1}', style: TextStyle(color: isPremium ? Colors.white : (isMe ? HunterTheme.primary : HunterTheme.textSecondary), fontSize: index < 9 ? 13 : 11, fontWeight: FontWeight.bold)))))),
                const SizedBox(width: 10),
                PremiumAvatar(membership: membership, radius: 19, image: entry.profilePicture != null && entry.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(entry.profilePicture!)) : null, child: Icon(Icons.person, color: rc, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Flexible(child: Text(entry.hunterName, overflow: TextOverflow.ellipsis, style: TextStyle(color: nameColor, fontSize: 14, fontWeight: FontWeight.w600))), const SizedBox(width: 6), MembershipBadge(membership: membership, fontSize: 8), if (isMe) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isPremium ? Colors.white.withOpacity(0.18) : HunterTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: isPremium ? Colors.white.withOpacity(0.5) : HunterTheme.primary.withOpacity(0.3))), child: Text('YOU', style: TextStyle(color: isPremium ? Colors.white : HunterTheme.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)))]]),
                  const SizedBox(height: 3), Text('${getRankTitle(level)}  ·  Lv.$level', style: TextStyle(color: subColor, fontSize: 11, letterSpacing: 0.3)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isPremium ? Colors.white.withOpacity(0.15) : HunterTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: isPremium ? Colors.white.withOpacity(0.45) : HunterTheme.primary.withOpacity(0.3))), child: Text(_xpLabel(entry), style: TextStyle(color: isPremium ? Colors.white : HunterTheme.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              ]),
            ))),
          );
        }, childCount: isSearching ? entries.length : (entries.length > 3 ? entries.length - 3 : 0)))),
      ],
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
    return Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: PremiumCardDecorator(membership: myMembership, borderRadius: BorderRadius.circular(16), child: Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: myPremium ? Colors.transparent : HunterTheme.cardColor, border: myPremium ? null : Border.all(color: HunterTheme.primary.withOpacity(0.35), width: 1.5), boxShadow: myPremium ? null : [BoxShadow(color: HunterTheme.primary.withOpacity(0.1), blurRadius: 20, spreadRadius: 2)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 4, height: 4, decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle)), const SizedBox(width: 8), Text('YOUR POSITION', style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.5)), const SizedBox(width: 8), Container(width: 4, height: 4, decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle))]),
        const SizedBox(height: 14),
        Row(children: [
          PremiumAvatar(membership: myMembership, radius: 24, image: hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty ? MemoryImage(_decodedAvatar(hunter.profilePicture!)) : null, child: Icon(Icons.person, color: _rankColor(hunter.level), size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(hunter.hunterName, style: TextStyle(color: nameColor, fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${getRankTitle(hunter.level)}  ·  Level ${hunter.level}', style: TextStyle(color: subColor, fontSize: 12))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${hunter.xp} XP', style: TextStyle(color: labelColor, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: myPremium ? Colors.white.withOpacity(0.15) : HunterTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: myPremium ? Colors.white.withOpacity(0.5) : HunterTheme.primary.withOpacity(0.35))), child: Text(myRank > 0 ? '# $myRank' : '$limit+', style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)))]),
        ]),
      ]),
    )));
  }
}
