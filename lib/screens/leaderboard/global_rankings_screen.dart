import 'dart:math' as math;
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

class _GlobalRankingsScreenState extends State<GlobalRankingsScreen> {

  bool _searchMode = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // Live stream of the current user's hunter document for the status card.
  // Keeps "Your Hunter Status" in real-time sync regardless of whether the
  // user is in the top 50 leaderboard results.
  late final Stream<DocumentSnapshot>? _myHunterStream = _createMyHunterStream();

  Stream<DocumentSnapshot>? _createMyHunterStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('hunters').doc(uid).snapshots();
  }

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

  // ── Podium item (top 3) ────────────────────────────────────────────────
  Widget _buildPodiumItem(
      BuildContext context, List<QueryDocumentSnapshot> hunters, int index, String? currentUid) {
    if (index >= hunters.length) {
      return const Expanded(child: SizedBox());
    }

    final doc = hunters[index];
    final hunter = doc.data() as Map<String, dynamic>;
    final isMe = doc.id == currentUid;
    final level = (hunter['level'] ?? 1) as int;
    final rc = _rankColor(level);
    final posColor = _positionColor(index);
    final isFirst = index == 0;

    final double avatarSize = isFirst ? 76 : 60;
    final double pedestalHeight = index == 0 ? 78 : (index == 1 ? 58 : 44);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (doc.id == currentUid) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicHunterProfileScreen(
                hunterUid: doc.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              TopRankBadge(
                position: index + 1,
                color: posColor,
                size: isFirst ? 40 : 32,
              ),
              const SizedBox(height: 8),
              PremiumAvatar(
                membership: (hunter['membership'] ?? 'basic').toString(),
                radius: avatarSize / 2,
                image: hunter['profilePicture'] != null &&
                    hunter['profilePicture'].toString().isNotEmpty
                    ? MemoryImage(
                  _decodedAvatar(hunter['profilePicture']),
                )
                    : null,
                child: Icon(
                  Icons.person,
                  color: rc,
                  size: isFirst ? 38 : 30,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  Text(
                    hunter['hunterName'] ?? 'Unknown',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isMe ? HunterTheme.primary : HunterTheme.textPrimary,
                      fontSize: isFirst ? 15 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  MembershipBadge(
                    membership: (hunter['membership'] ?? 'basic').toString(),
                    fontSize: 7,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${getRankTitle(level)} · Lv.$level',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: pedestalHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      posColor.withOpacity(0.85),
                      posColor.withOpacity(0.45),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: posColor.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: isFirst ? 26 : 20,
                      fontWeight: FontWeight.w900,
                    ),
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
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
                    .limit(50)
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
                  int myRank = 0;
                  for (int i = 0; i < hunters.length; i++) {
                    if (hunters[i].id == currentUid) {
                      myHunter = hunters[i].data() as Map<String, dynamic>;
                      myRank = i + 1;
                      break;
                    }
                  }

                  // If the current user is not in the top 50, their status
                  // card uses the dedicated _myHunterStream instead.
                  // myRank stays 0 which displays as "50+".

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
                            if (snapshot.data!.docs.first.id == currentUid) return;
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
                      // ── My Hunter Status Card (live stream) ─────────────────
                      if (_myHunterStream != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: _myHunterStream,
                          builder: (context, mySnap) {
                            final myData = mySnap.data?.data() as Map<String, dynamic>?;
                            return Container(
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
                                        membership: (myData?['membership'] ?? 'basic').toString(),
                                        radius: 24,
                                        image: myData != null &&
                                            myData['profilePicture'] != null &&
                                            myData['profilePicture'].toString().isNotEmpty
                                            ? MemoryImage(
                                                _decodedAvatar(myData['profilePicture']),
                                              )
                                            : null,
                                        child: Icon(
                                          Icons.person,
                                          color: myData != null
                                              ? _rankColor(myData['level'] ?? 1)
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
                                              myData?['hunterName'] ?? 'Unknown Hunter',
                                              style: TextStyle(
                                                color: HunterTheme.textPrimary,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              myData != null
                                                  ? '${getRankTitle(myData['level'] ?? 1)}  ·  Level ${myData['level']}'
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
                                            myData != null ? '${myData['xp']} XP' : '',
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
                                              myRank > 0 ? '# $myRank' : '50+',
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
                            );
                          },
                        ),

                      // ── Podium (Top 3) ─────────────────────────────────────
                      if (hunters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildPodiumItem(context, hunters, 1, currentUid), // 2nd - left
                              _buildPodiumItem(context, hunters, 0, currentUid), // 1st - center
                              _buildPodiumItem(context, hunters, 2, currentUid), // 3rd - right
                            ],
                          ),
                        ),

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
                                if (hunters[index].id == currentUid) return;
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
