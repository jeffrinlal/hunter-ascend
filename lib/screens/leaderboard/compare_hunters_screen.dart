import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
import 'package:hunter_ascend/widgets/membership_badge.dart';
import 'package:hunter_ascend/widgets/premium_avatar.dart';

/// Side-by-side stat comparison of two hunters.
class CompareHuntersScreen extends StatefulWidget {
  final String hunterUid;

  const CompareHuntersScreen({
    super.key,
    required this.hunterUid,
  });

  @override
  State<CompareHuntersScreen> createState() => _CompareHuntersScreenState();
}

class _CompareHuntersScreenState extends State<CompareHuntersScreen> {
  // Held in state (rather than created inline in build()) so a failed load
  // can be retried without relying on an unrelated rebuild (e.g. a theme
  // change) to re-trigger the Firestore reads.
  late Future<List<DocumentSnapshot<Map<String, dynamic>>>> _compareFuture;

  @override
  void initState() {
    super.initState();
    _compareFuture = _loadComparison();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _loadComparison() {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    return Future.wait([
      FirebaseFirestore.instance.collection('hunters').doc(currentUid).get(),
      FirebaseFirestore.instance.collection('hunters').doc(widget.hunterUid).get(),
    ]);
  }

  void _retry() {
    setState(() {
      _compareFuture = _loadComparison();
    });
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

  // Session-level guard so opening this screen doesn't fire the
  // "hasComparedHunter" write (and achievement re-evaluation) more than once
  // per app session even if the widget rebuilds (e.g. due to the theme
  // ListenableBuilder above) — the underlying Firestore write is itself
  // idempotent (re-writing `true` is harmless), this purely avoids redundant
  // writes/evaluations on every theme-driven rebuild.
  static final Set<String> _recordedForUid = {};

  Future<void> _recordComparisonOnce(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _recordedForUid.contains(uid)) return;
    _recordedForUid.add(uid);
    try {
      await FirebaseFirestore.instance.collection('hunters').doc(uid).update({'hasComparedHunter': true});
    } catch (e) {
      debugPrint('CompareHuntersScreen hasComparedHunter write: $e');
      _recordedForUid.remove(uid); // allow a retry on the next open
      return;
    }
    if (context.mounted) {
      await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fire-and-forget: recording "compared a hunter" and celebrating any
    // newly-unlocked achievement must never block or affect this screen's
    // own rendering.
    unawaited(_recordComparisonOnce(context));
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.cardColor,
                border: Border.all(color: HunterTheme.border),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: HunterTheme.textSecondary, size: 15),
            ),
          ),
        ),
        leadingWidth: 60,
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
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: _compareFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [HunterTheme.danger.withOpacity(0.16), HunterTheme.cardColor],
                        ),
                        border: Border.all(color: HunterTheme.danger.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.error_outline_rounded, color: HunterTheme.danger, size: 34),
                    ),
                    const SizedBox(height: 18),
                    Text('Could not load this comparison',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HunterTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                  const SizedBox(height: 18),
                  Text('Analyzing hunters...',
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final myDoc = snapshot.data![0];
          final theirDoc = snapshot.data![1];

          if (!myDoc.exists || !theirDoc.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [HunterTheme.textTertiary.withOpacity(0.16), HunterTheme.cardColor],
                        ),
                        border: Border.all(color: HunterTheme.textTertiary.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.person_off_outlined, color: HunterTheme.textTertiary, size: 32),
                    ),
                    const SizedBox(height: 18),
                    Text('Hunter profile unavailable',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('This hunter could not be found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
            );
          }

          final myData    = myDoc.data() ?? <String, dynamic>{};
          final theirData = theirDoc.data() ?? <String, dynamic>{};

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

          final myRankColor    = RankService.instance.colorForLevel(myLevel);
          final theirRankColor = RankService.instance.colorForLevel(theirLevel);

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

                // ── Hunter Headers (battle-arena hero) ───────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [HunterTheme.primary.withOpacity(0.09), HunterTheme.cardColor],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: HunterTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(HunterTheme.isDark ? 0.22 : 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [HunterTheme.danger, HunterTheme.dangerAlt],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: HunterTheme.danger.withOpacity(0.4 * HunterTheme.glowStrength),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
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
                  myColor: HunterTheme.gold,
                  theirColor: HunterTheme.gold,
                  displayMy: '${myStreak}d',
                  displayTheir: '${theirStreak}d',
                ),

                const SizedBox(height: 24),

                // ── Verdict Card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [verdictColor.withOpacity(0.14), HunterTheme.cardColor],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: verdictColor.withOpacity(0.35), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: verdictColor.withOpacity(0.12 * HunterTheme.glowStrength),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [verdictColor.withOpacity(0.2), verdictColor.withOpacity(0.08)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: verdictColor.withOpacity(0.3)),
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
    final rank = RankService.instance.letterForLevel(level);
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HunterTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(HunterTheme.isDark ? 0.14 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
            borderRadius: BorderRadius.circular(5),
            child: Row(
              children: [
                Expanded(
                  flex: (myFraction * 100).round(),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: myWins
                            ? [myColor, myColor.withOpacity(0.7)]
                            : [myColor.withOpacity(0.35), myColor.withOpacity(0.22)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        bottomLeft: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: 100 - (myFraction * 100).round(),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theirWins
                            ? [theirColor.withOpacity(0.7), theirColor]
                            : [theirColor.withOpacity(0.22), theirColor.withOpacity(0.35)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(5),
                        bottomRight: Radius.circular(5),
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