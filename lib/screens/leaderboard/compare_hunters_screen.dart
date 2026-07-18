import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/widgets/membership_badge.dart';
import 'package:hunter_ascend/widgets/premium_avatar.dart';

/// Side-by-side stat comparison of two hunters.
class CompareHuntersScreen extends StatelessWidget {
  final String hunterUid;

  const CompareHuntersScreen({
    super.key,
    required this.hunterUid,
  });

  String _getRank(int level) {
    if (level >= 30) return 'S';
    if (level >= 20) return 'A';
    if (level >= 15) return 'B';
    if (level >= 10) return 'C';
    if (level >= 5)  return 'D';
    return 'E';
  }

  Color _getRankColor(int level) {
    if (level >= 30) return HunterTheme.gold;
    if (level >= 20) return HunterTheme.danger;
    if (level >= 15) return HunterTheme.primary;
    if (level >= 10) return HunterTheme.primary;
    if (level >= 5)  return HunterTheme.success;
    return HunterTheme.textSecondary;
  }

  /// Resolves effective membership from a hunter doc. A premium tier
  /// with an expired expiry is treated as Basic.
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

  DateTime? _parseExpiry(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: HunterTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HunterTheme.primary.withOpacity(0.4)),
              ),
              child: Icon(Icons.compare_arrows,
                  color: HunterTheme.primary, size: 17),
            ),
            const SizedBox(width: 10),
            Text(
              'HUNTER COMPARISON',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          FirebaseFirestore.instance.collection('hunters').doc(currentUid).get(),
          FirebaseFirestore.instance.collection('hunters').doc(hunterUid).get(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: HunterTheme.primary),
            );
          }

          final myData    = snapshot.data![0].data() as Map<String, dynamic>;
          final theirData = snapshot.data![1].data() as Map<String, dynamic>;

          final myWins     = (myData['duelWins']    ?? 0) as int;
          final myLosses   = (myData['duelLosses']  ?? 0) as int;
          final myXp       = (myData['xp']          ?? 0) as int;
          final myLevel    = (myData['level']        ?? 1) as int;
          final myStreak   = (myData['streak']       ?? 0) as int;

          final theirWins   = (theirData['duelWins']   ?? 0) as int;
          final theirLosses = (theirData['duelLosses'] ?? 0) as int;
          final theirXp     = (theirData['xp']         ?? 0) as int;
          final theirLevel  = (theirData['level']      ?? 1) as int;
          final theirStreak = (theirData['streak']     ?? 0) as int;

          final myWinRate    = myWins + myLosses == 0 ? 0
              : ((myWins * 100) / (myWins + myLosses)).round();
          final theirWinRate = theirWins + theirLosses == 0 ? 0
              : ((theirWins * 100) / (theirWins + theirLosses)).round();

          final myRankColor    = _getRankColor(myLevel);
          final theirRankColor = _getRankColor(theirLevel);

          // Verdict
          String verdictText;
          Color verdictColor;
          IconData verdictIcon;
          if (theirXp > myXp) {
            verdictText  = 'This hunter outranks you. Train harder.';
            verdictColor = HunterTheme.danger;
            verdictIcon  = Icons.trending_down;
          } else if (theirXp < myXp) {
            verdictText  = 'You outrank this hunter. Stay sharp.';
            verdictColor = HunterTheme.success;
            verdictIcon  = Icons.trending_up;
          } else {
            verdictText  = 'You are perfectly matched. Duel to decide.';
            verdictColor = HunterTheme.gold;
            verdictIcon  = Icons.balance;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ── Hunter Headers ───────────────────────────────────
                Row(
                  children: [
                    // Me
                    Expanded(
                      child: _hunterHeader(
                        myData['hunterName'] ?? 'You',
                        myLevel,
                        myRankColor,
                        myData['profilePicture'],
                        _effectiveMembership(myData),
                        isMe: true,
                      ),
                    ),

                    // VS badge
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: HunterTheme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: HunterTheme.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: HunterTheme.primary.withOpacity(0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: HunterTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    // Them
                    Expanded(
                      child: _hunterHeader(
                        theirData['hunterName'] ?? 'Hunter',
                        theirLevel,
                        theirRankColor,
                        theirData['profilePicture'],
                        _effectiveMembership(theirData),
                        isMe: false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Divider ──────────────────────────────────────────
                _sectionLabel('STAT COMPARISON'),
                const SizedBox(height: 14),

                // ── Comparison Rows ──────────────────────────────────
                _compareBar(
                  label: 'LEVEL',
                  myVal: myLevel,
                  theirVal: theirLevel,
                  myColor: myRankColor,
                  theirColor: theirRankColor,
                  displayMy: 'LV.$myLevel',
                  displayTheir: 'LV.$theirLevel',
                ),
                _compareBar(
                  label: 'TOTAL XP',
                  myVal: myXp,
                  theirVal: theirXp,
                  myColor: myRankColor,
                  theirColor: theirRankColor,
                  displayMy: '$myXp',
                  displayTheir: '$theirXp',
                ),
                _compareBar(
                  label: 'DUEL WINS',
                  myVal: myWins,
                  theirVal: theirWins,
                  myColor: HunterTheme.success,
                  theirColor: HunterTheme.success,
                  displayMy: '$myWins',
                  displayTheir: '$theirWins',
                ),
                _compareBar(
                  label: 'LOSSES',
                  myVal: myLosses,
                  theirVal: theirLosses,
                  myColor: HunterTheme.danger,
                  theirColor: HunterTheme.danger,
                  displayMy: '$myLosses',
                  displayTheir: '$theirLosses',
                  lowerIsBetter: true,
                ),
                _compareBar(
                  label: 'WIN RATE',
                  myVal: myWinRate,
                  theirVal: theirWinRate,
                  myColor: HunterTheme.gold,
                  theirColor: HunterTheme.gold,
                  displayMy: '$myWinRate%',
                  displayTheir: '$theirWinRate%',
                ),
                _compareBar(
                  label: 'STREAK',
                  myVal: myStreak,
                  theirVal: theirStreak,
                  myColor: Colors.orange,
                  theirColor: Colors.orange,
                  displayMy: '${myStreak}d',
                  displayTheir: '${theirStreak}d',
                ),

                const SizedBox(height: 24),

                // ── Verdict Card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: verdictColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: verdictColor.withOpacity(0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: verdictColor.withOpacity(0.08),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: verdictColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(verdictIcon, color: verdictColor, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          verdictText,
                          style: TextStyle(
                            color: verdictColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Hunter Header ────────────────────────────────────────────────
  Widget _hunterHeader(
      String name,
      int level,
      Color rankColor,
      String? profilePicture,
      String membership,
      {required bool isMe}
      ) {
    final rank = _getRank(level);
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
      PremiumAvatar(
      membership: membership,
      radius: 35,
      image: profilePicture != null && profilePicture.isNotEmpty
          ? MemoryImage(base64Decode(profilePicture))
          : null,
      child: profilePicture == null || profilePicture.isEmpty
          ? Icon(
        Icons.person,
        color: rankColor,
        size: 38,
      )
          : null,
    ),
            Positioned(
              bottom: 0,
              right: isMe ? null : 0,
              left: isMe ? 0 : null,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: HunterTheme.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor, width: 1.5),
                ),
                child: Center(
                  child: Text(rank,
                      style: TextStyle(
                          color: rankColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        Flexible(
        child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
        color: isMe
        ? HunterTheme.primary
            : HunterTheme.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        ),
        ),
        ),

        const SizedBox(width: 6),

        MembershipBadge(
        membership: membership,
        fontSize: 8,
        ),
        ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: rankColor.withOpacity(0.3)),
          ),
          child: Text(
            'LV.$level',
            style: TextStyle(
                color: rankColor,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ── Compare Bar ──────────────────────────────────────────────────
  Widget _compareBar({
    required String label,
    required num myVal,
    required num theirVal,
    required Color myColor,
    required Color theirColor,
    required String displayMy,
    required String displayTheir,
    bool lowerIsBetter = false,
  }) {
    final total = myVal + theirVal;
    final myFraction  = total == 0 ? 0.5 : (myVal / total).toDouble();
    final myWins      = lowerIsBetter ? myVal < theirVal : myVal > theirVal;
    final theirWins   = lowerIsBetter ? theirVal < myVal : theirVal > myVal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunterTheme.border, width: 1),
      ),
      child: Column(
        children: [
          // Label + values
          Row(
            children: [
              // My value
              SizedBox(
                width: 60,
                child: Text(
                  displayMy,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: myWins ? myColor : HunterTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: myWins ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              // Label center
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Their value
              SizedBox(
                width: 60,
                child: Text(
                  displayTheir,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theirWins ? theirColor : HunterTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: theirWins ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(
                  flex: (myFraction * 100).round(),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: myWins
                          ? myColor
                          : myColor.withOpacity(0.35),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: 100 - (myFraction * 100).round(),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: theirWins
                          ? theirColor
                          : theirColor.withOpacity(0.35),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Expanded(child: Container(height: 1,
          color: HunterTheme.textPrimary.withOpacity(0.06))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text,
            style: TextStyle(
                color: HunterTheme.textFaint,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
      ),
      Expanded(child: Container(height: 1,
          color: HunterTheme.textPrimary.withOpacity(0.06))),
    ]);
  }
}