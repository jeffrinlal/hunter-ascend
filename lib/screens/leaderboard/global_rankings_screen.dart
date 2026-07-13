import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/profile/public_hunter_profile_screen.dart';
import 'package:hunter_ascend/widgets/skeleton_loaders.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hunter_ascend/widgets/membership_badge.dart';

import '../../widgets/premium_avatar.dart';

// ── Global Rankings Screen ─────────────────────────────────────────────────

/// Global leaderboard ranked by level then XP, with search.
class GlobalRankingsScreen extends StatefulWidget {
  const GlobalRankingsScreen({super.key});

  @override
  State<GlobalRankingsScreen> createState() =>
      _GlobalRankingsScreenState();
}

class _GlobalRankingsScreenState extends State<GlobalRankingsScreen> {

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // Caches decoded avatar bytes keyed by the Base64 string, so each unique
  // profile picture is decoded only once and the same Uint8List is reused
  // across scrolls/rebuilds (re-decodes only when the Base64 string changes).
  final Map<String, Uint8List> _avatarCache = {};

  Uint8List _decodedAvatar(String base64Data) =>
      _avatarCache[base64Data] ??= base64Decode(base64Data);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // Position-specific colors
  Color _positionColor(int index) {
    if (index == 0) return HunterTheme.goldBright; // Gold
    if (index == 1) return HunterTheme.silver; // Steel silver
    if (index == 2) return HunterTheme.bronze; // Bronze
    return HunterTheme.textSecondary;
  }

  // ── Top 3 ───────────────────────────────────────────────────────────────

  Widget _buildElitePodium(
      BuildContext context, List<QueryDocumentSnapshot> hunters, String? currentUid) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HunterTheme.goldBright.withOpacity(HunterTheme.isDark ? 0.10 : 0.07),
            HunterTheme.isDark ? const Color(0xFF0A0E18) : HunterTheme.cardColor,
          ],
          stops: const [0.0, 0.4],
        ),
        border: Border.all(
          color: HunterTheme.goldBright.withOpacity(HunterTheme.isDark ? 0.18 : 0.14),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Atmospheric glow behind #1
          if (hunters.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _positionColor(0).withOpacity(HunterTheme.isDark ? 0.15 : 0.08),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── #1 Champion ──
              if (hunters.isNotEmpty)
                _buildChampion(context, hunters, 0, currentUid),
              const SizedBox(height: 4),
              // ── #2 and #3 ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hunters.length > 1)
                      Expanded(
                        child: _buildRunnerUp(context, hunters, 1, currentUid),
                      ),
                    if (hunters.length > 2)
                      Expanded(
                        child: _buildRunnerUp(context, hunters, 2, currentUid),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ── Separator with integrated rank numerals ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Left line
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _positionColor(1).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Ⅱ', style: TextStyle(
                        color: _positionColor(1).withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                    // Center line segment
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _positionColor(0).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                              _positionColor(0).withOpacity(HunterTheme.isDark ? 0.4 : 0.25),
                              _positionColor(0).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Ⅰ', style: TextStyle(
                        color: _positionColor(0).withOpacity(0.85),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      )),
                    ),
                    // Right center line
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _positionColor(0).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                              _positionColor(2).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('Ⅲ', style: TextStyle(
                        color: _positionColor(2).withOpacity(0.6),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                    ),
                    // Right line
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _positionColor(2).withOpacity(HunterTheme.isDark ? 0.3 : 0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The champion: large avatar, name, badge, subtitle.
  Widget _buildChampion(
      BuildContext context, List<QueryDocumentSnapshot> hunters, int index, String? currentUid) {
    final doc = hunters[index];
    final hunter = doc.data() as Map<String, dynamic>;
    final isMe = doc.id == currentUid;
    final level = (hunter['level'] ?? 1) as int;
    final rc = _rankColor(level);

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => PublicHunterProfileScreen(hunterUid: doc.id)),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HunterTheme.gold, HunterTheme.goldBright, HunterTheme.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: HunterTheme.goldBright.withOpacity(0.45),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: PremiumAvatar(
              membership: (hunter['membership'] ?? 'basic').toString(),
              radius: 53,
              image: hunter['profilePicture'] != null &&
                  hunter['profilePicture'].toString().isNotEmpty
                  ? MemoryImage(_decodedAvatar(hunter['profilePicture']))
                  : null,
              child: Icon(Icons.person, color: rc, size: 52),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hunter['hunterName'] ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isMe ? HunterTheme.primary : (HunterTheme.isDark ? Colors.white : HunterTheme.textPrimary),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          MembershipBadge(
            membership: (hunter['membership'] ?? 'basic').toString(),
            fontSize: 8,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [HunterTheme.goldDeep, HunterTheme.goldBright],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TOP HUNTER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A runner-up (#2 or #3): smaller avatar, name, badge.
  Widget _buildRunnerUp(
      BuildContext context, List<QueryDocumentSnapshot> hunters, int index, String? currentUid) {
    final doc = hunters[index];
    final hunter = doc.data() as Map<String, dynamic>;
    final isMe = doc.id == currentUid;
    final level = (hunter['level'] ?? 1) as int;
    final rc = _rankColor(level);
    final posColor = _positionColor(index);
    final ringColors = index == 1
        ? [Colors.white, HunterTheme.silver]
        : [HunterTheme.goldDark, HunterTheme.bronze];

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => PublicHunterProfileScreen(hunterUid: doc.id)),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: ringColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: posColor.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: PremiumAvatar(
              membership: (hunter['membership'] ?? 'basic').toString(),
              radius: 26,
              image: hunter['profilePicture'] != null &&
                  hunter['profilePicture'].toString().isNotEmpty
                  ? MemoryImage(_decodedAvatar(hunter['profilePicture']))
                  : null,
              child: Icon(Icons.person, color: rc, size: 26),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hunter['hunterName'] ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMe ? HunterTheme.primary : (HunterTheme.isDark ? Colors.white.withOpacity(0.85) : HunterTheme.textPrimary),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          MembershipBadge(
            membership: (hunter['membership'] ?? 'basic').toString(),
            fontSize: 7,
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _rankHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('hunters')
                    .orderBy('level', descending: true)
                    .orderBy('xp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: buildLeaderboardSkeleton(),
                    );
                  }

                  final hunters = snapshot.data!.docs;
                  final currentUid = FirebaseAuth.instance.currentUser?.uid;

                  Map<String, dynamic>? myHunter;
                  for (var doc in hunters) {
                    if (doc.id == currentUid) {
                      myHunter = doc.data() as Map<String, dynamic>;
                      break;
                    }
                  }

                  final myRank = hunters.indexWhere((h) => h.id == currentUid) + 1;

                  return _searchMode
                      ? (_searchText.isEmpty
                      ? Container(
                    color: HunterTheme.background,
                  )
                      : FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('hunters')
                        .where('hunterName', isEqualTo: _searchText)
                        .limit(1)
                        .get(),
                    builder: (context, snapshot) {

                      if (!snapshot.hasData) {
                        return const SizedBox();
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return Container(
                          color: HunterTheme.background,
                        );
                      }

                      final hunter =
                      snapshot.data!.docs.first.data() as Map<String, dynamic>;

                      return Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PublicHunterProfileScreen(
                                  hunterUid: snapshot.data!.docs.first.id,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: HunterTheme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: HunterTheme.primary,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: HunterTheme.primary.withOpacity(0.12),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                hunter['profilePicture'] != null &&
                                    hunter['profilePicture'].toString().isNotEmpty
                                    ? CircleAvatar(
                                  radius: 30,
                                  backgroundImage: MemoryImage(
                                    _decodedAvatar(hunter['profilePicture']),
                                  ),
                                )
                                    : Icon(
                                  Icons.person,
                                  color: HunterTheme.primary,
                                  size: 60,
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  hunter['hunterName'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'Level ${hunter['level'] ?? 1}',
                                  style: TextStyle(color: HunterTheme.textSecondary),
                                ),

                                Text(
                                  '${hunter['xp'] ?? 0} XP',
                                  style: TextStyle(color: HunterTheme.textSecondary),
                                ),

                                Text(
                                  hunter['hunterId'] ?? '',
                                  style: TextStyle(color: HunterTheme.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ))
                      : Column(
                    children: [
                      // ── My Hunter Status Card ──────────────────────────────
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: HunterTheme.cardColor,
                          border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: HunterTheme.primary.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    color: HunterTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'YOUR HUNTER STATUS',
                                  style: TextStyle(
                                    color: HunterTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    color: HunterTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                // Avatar with rank ring + actual profile picture
                                PremiumAvatar(
                                  membership: (myHunter?['membership'] ?? 'basic').toString(),
                                  radius: 24,
                                  image: myHunter != null &&
                                      myHunter['profilePicture'] != null &&
                                      myHunter['profilePicture'].toString().isNotEmpty
                                      ? MemoryImage(
                                    _decodedAvatar(myHunter['profilePicture']),
                                  )
                                      : null,
                                  child: Icon(
                                    Icons.person,
                                    color: myHunter != null
                                        ? _rankColor(myHunter['level'] ?? 1)
                                        : HunterTheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        myHunter?['hunterName'] ?? 'Unknown Hunter',
                                        style: TextStyle(
                                          color: HunterTheme.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        myHunter != null
                                            ? '${getRankTitle(myHunter['level'] ?? 1)}  ·  Level ${myHunter['level']}'
                                            : '',
                                        style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      myHunter != null ? '${myHunter['xp']} XP' : '',
                                      style: TextStyle(
                                        color: HunterTheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: HunterTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: HunterTheme.primary.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        myRank > 0 ? '# $myRank' : 'UNRANKED',
                                        style: TextStyle(
                                          color: HunterTheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Podium (Top 3) ─────────────────────────────────────
                      if (hunters.isNotEmpty)
                        _buildElitePodium(context, hunters, currentUid),

                      // ── Divider with label ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'LEADERBOARD',
                                style: TextStyle(
                                  color: HunterTheme.textTertiary,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(child: Container(height: 1, color: HunterTheme.textPrimary.withOpacity(0.08))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Leaderboard list (rank 4 onwards) ──────────────────
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: hunters.length > 3 ? hunters.length - 3 : 0,
                          itemBuilder: (context, listIndex) {
                            final index = listIndex + 3;
                            final hunter = hunters[index].data() as Map<String, dynamic>;
                            final isMe = hunters[index].id == currentUid;
                            final level = (hunter['level'] ?? 1) as int;
                            final rc = _rankColor(level);

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PublicHunterProfileScreen(
                                      hunterUid: hunters[index].id,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? HunterTheme.surface
                                      : HunterTheme.cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isMe
                                        ? HunterTheme.primary.withOpacity(0.4)
                                        : HunterTheme.textPrimary.withOpacity(0.06),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: HunterTheme.primary.withOpacity(0.04),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // ── Rank badge ──
                                    SizedBox(
                                      width: 40,
                                      child: Center(
                                        child: Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isMe
                                                ? HunterTheme.primary.withOpacity(0.12)
                                                : HunterTheme.textPrimary.withOpacity(0.04),
                                            border: Border.all(
                                              color: isMe
                                                  ? HunterTheme.primary.withOpacity(0.4)
                                                  : HunterTheme.textPrimary.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: isMe
                                                    ? HunterTheme.primary
                                                    : HunterTheme.textSecondary,
                                                fontSize: index < 9 ? 13 : 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // ── Avatar ──
                                    PremiumAvatar(
                                      membership: (hunter['membership'] ?? 'basic').toString(),
                                      radius: 19,
                                      image: hunter['profilePicture'] != null &&
                                          hunter['profilePicture'].toString().isNotEmpty
                                          ? MemoryImage(
                                        _decodedAvatar(hunter['profilePicture']),
                                      )
                                          : null,
                                      child: Icon(
                                        Icons.person,
                                        color: rc,
                                        size: 20,
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // ── Name + rank ──
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  hunter['hunterName'] ?? 'Unknown',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isMe
                                                        ? HunterTheme.primary
                                                        : HunterTheme.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 6),

                                              MembershipBadge(
                                                membership: hunter['membership'] ?? 'basic',
                                                fontSize: 8,
                                              ),

                                              if (isMe) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: HunterTheme.primary.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: HunterTheme.primary.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'YOU',
                                                    style: TextStyle(
                                                      color: HunterTheme.primary,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${getRankTitle(level)}  ·  Lv.$level',
                                            style: TextStyle(
                                              color: rc.withOpacity(0.7),
                                              fontSize: 11,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // ── XP chip ──
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: HunterTheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: HunterTheme.primary.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '${hunter['xp'] ?? 0} XP',
                                        style: TextStyle(
                                          color: HunterTheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}