import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_hunter_profile_screen.dart';
import 'dart:convert';

// ── Top 3 Crown Painter ────────────────────────────────────────────────────

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

  String getRankTitle(int level) {
    if (level >= 30) return 'S Rank';
    if (level >= 20) return 'A Rank';
    if (level >= 15) return 'B Rank';
    if (level >= 10) return 'C Rank';
    if (level >= 5)  return 'D Rank';
    return 'E Rank';
  }

  Color _rankColor(int level) {
    if (level >= 30) return const Color(0xFFFF4444);
    if (level >= 20) return const Color(0xFFFF8800);
    if (level >= 15) return const Color(0xFF9B59B6);
    if (level >= 10) return const Color(0xFF3498DB);
    if (level >= 5)  return const Color(0xFF2ECC71);
    return const Color(0xFF64C8FF);
  }

  // Position-specific colors
  Color _positionColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Gold
    if (index == 1) return const Color(0xFFB0C4DE); // Steel silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0C14),
        elevation: 0,

        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white70,
            ),
              onPressed: () {
                setState(() {
                  _searchMode = true;
                });
              },
          ),
        ],

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
          title: _searchMode
              ? TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              setState(() {
                _searchText = value.trim();
              });
            },

            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter Hunter ID...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          )

              : Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                  ),
                ),
                child: const Icon(
                  Icons.military_tech,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'GLOBAL RANKINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .orderBy('level', descending: true)
            .orderBy('xp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF64C8FF)),
                  SizedBox(height: 16),
                  Text('Loading Hunters...', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
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
            color: const Color(0xFF0A0C14),
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
                  color: const Color(0xFF0A0C14),
                );
              }

              final hunter =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;

              return Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111523),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF64C8FF),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      hunter['profilePicture'] != null &&
                          hunter['profilePicture'].toString().isNotEmpty
                          ? CircleAvatar(
                        radius: 30,
                        backgroundImage: MemoryImage(
                          base64Decode(hunter['profilePicture']),
                        ),
                      )
                          : const Icon(
                        Icons.person,
                        color: Color(0xFF64C8FF),
                        size: 60,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        hunter['hunterName'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Level ${hunter['level'] ?? 1}',
                        style: const TextStyle(color: Colors.white70),
                      ),

                      Text(
                        '${hunter['xp'] ?? 0} XP',
                        style: const TextStyle(color: Colors.white70),
                      ),

                      Text(
                        hunter['hunterId'] ?? '',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    ],
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
                  color: const Color(0xFF111523),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.08),
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
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'YOUR HUNTER STATUS',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4, height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD700),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        // Avatar with rank ring
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1D2E),
                            border: Border.all(
                              color: myHunter != null
                                  ? _rankColor(myHunter['level'] ?? 1)
                                  : const Color(0xFF64C8FF),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: myHunter != null
                                    ? _rankColor(myHunter['level'] ?? 1).withOpacity(0.3)
                                    : const Color(0xFF64C8FF).withOpacity(0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person,
                            color: myHunter != null
                                ? _rankColor(myHunter['level'] ?? 1)
                                : const Color(0xFF64C8FF),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                myHunter != null
                                    ? '${getRankTitle(myHunter['level'] ?? 1)}  ·  Level ${myHunter['level']}'
                                    : '',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              myHunter != null ? '${myHunter['xp']} XP' : '',
                              style: const TextStyle(
                                color: Color(0xFF2ECC71),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFFD700).withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                myRank > 0 ? '# $myRank' : 'UNRANKED',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
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

              // ── Divider with label ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'LEADERBOARD',
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.06))),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Leaderboard list ───────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: hunters.length,
                  itemBuilder: (context, index) {
                    final hunter = hunters[index].data() as Map<String, dynamic>;
                    final isMe = hunters[index].id == currentUid;
                    final level = (hunter['level'] ?? 1) as int;
                    final rc = _rankColor(level);
                    final posColor = _positionColor(index);
                    final isTop3 = index < 3;

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
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: isTop3 ? 14 : 11,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF0D1525)
                            : isTop3
                            ? const Color(0xFF0F1420)
                            : const Color(0xFF111523),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMe
                              ? const Color(0xFF64C8FF).withOpacity(0.4)
                              : isTop3
                              ? posColor.withOpacity(0.3)
                              : Colors.white.withOpacity(0.06),
                          width: isTop3 ? 1.5 : 1,
                        ),
                        boxShadow: isTop3
                            ? [
                          BoxShadow(
                            color: posColor.withOpacity(0.08),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // ── Rank badge ──
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: isTop3
                                  ? TopRankBadge(
                                position: index + 1,
                                color: posColor,
                                size: 34,
                              )
                                  : Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isMe
                                      ? const Color(0xFF64C8FF).withOpacity(0.1)
                                      : Colors.white.withOpacity(0.04),
                                  border: Border.all(
                                    color: isMe
                                        ? const Color(0xFF64C8FF).withOpacity(0.3)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isMe
                                          ? const Color(0xFF64C8FF)
                                          : Colors.white38,
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
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rc.withOpacity(0.08),
                              border: Border.all(
                                color: rc.withOpacity(isTop3 ? 0.6 : 0.35),
                                width: isTop3 ? 1.5 : 1,
                              ),
                              boxShadow: isTop3
                                  ? [BoxShadow(color: rc.withOpacity(0.2), blurRadius: 8)]
                                  : null,
                            ),
                            child: hunter['profilePicture'] != null &&
                                hunter['profilePicture'].toString().isNotEmpty
                                ? ClipOval(
                              child: Image.memory(
                                base64Decode(hunter['profilePicture']),
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                              ),
                            )
                                : Icon(
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
                                              ? const Color(0xFF64C8FF)
                                              : isTop3
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.85),
                                          fontSize: isTop3 ? 15 : 14,
                                          fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF64C8FF).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF64C8FF).withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: Color(0xFF64C8FF),
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
                              color: isTop3
                                  ? posColor.withOpacity(0.1)
                                  : const Color(0xFF2ECC71).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTop3
                                    ? posColor.withOpacity(0.3)
                                    : const Color(0xFF2ECC71).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              '${hunter['xp'] ?? 0} XP',
                              style: TextStyle(
                                color: isTop3 ? posColor : const Color(0xFF2ECC71),
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
    );
  }
}