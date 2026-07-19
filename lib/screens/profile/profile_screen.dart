import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/settings/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hunter_ascend/widgets/skeleton_loaders.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:hunter_ascend/screens/profile/membership_screen.dart';
import 'package:hunter_ascend/screens/profile/reports/reports_tab.dart';
import 'package:hunter_ascend/widgets/membership_badge.dart';
import 'package:hunter_ascend/widgets/premium_avatar.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/data/models/weight_entry.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/data/repositories/weight_repository.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The signed-in hunter's own profile: stats, physique, history, and sharing.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _linkingGoogle = false;

  // ── Cached profile picture bytes ──────────────────────────────────────
  // Avoids re-decoding the Base64 string on every StreamBuilder rebuild
  // (which fires whenever ANY field on the hunter doc changes — XP, streak,
  // quests, etc.). Decoding only occurs when the raw string actually changes
  // (i.e. the user uploaded a new picture).
  String? _cachedProfilePicBase64;
  Uint8List? _cachedProfilePicBytes;

  /// Returns the decoded profile picture bytes, re-decoding only when the
  /// raw Base64 string has changed since the last call.
  Uint8List? _decodedProfilePic(String? base64Data) {
    if (base64Data == null) return null;
    if (base64Data == _cachedProfilePicBase64) return _cachedProfilePicBytes;
    _cachedProfilePicBase64 = base64Data;
    _cachedProfilePicBytes = base64Decode(base64Data);
    return _cachedProfilePicBytes;
  }

  String _getRank(int xp) {
    if (xp < 1500) return 'E';
    if (xp < 5000) return 'D';
    if (xp < 12000) return 'C';
    if (xp < 30000) return 'B';
    if (xp < 80000) return 'A';
    return 'S';
  }

  String _getNextRank(String rank) {
    const ranks = ['E', 'D', 'C', 'B', 'A', 'S'];
    final idx = ranks.indexOf(rank);
    return idx < ranks.length - 1 ? ranks[idx + 1] : 'MAX';
  }

  int _xpForRank(String rank) {
    switch (rank) {
      case 'E': return 1500;
      case 'D': return 5000;
      case 'C': return 12000;
      case 'B': return 30000;
      case 'A': return 80000;
      default:  return 80000;
    }
  }

  int _xpStartForRank(String rank) {
    switch (rank) {
      case 'E': return 0;
      case 'D': return 1500;
      case 'C': return 5000;
      case 'B': return 12000;
      case 'A': return 30000;
      default:  return 80000;
    }
  }

  String _getHunterClass(double bmi) {
    if (bmi < 18.5) return 'AGILE HUNTER';
    if (bmi < 25)   return 'BALANCED HUNTER';
    if (bmi < 30)   return 'TANK HUNTER';
    return 'HEAVY TANK HUNTER';
  }

  Color _getRankColor(String rank) {
    switch (rank) {
      case 'S': return HunterTheme.danger;
      case 'A': return HunterTheme.primary;
      case 'B': return HunterTheme.purple;
      case 'C': return HunterTheme.info;
      case 'D': return HunterTheme.successAlt;
      default:  return HunterTheme.primary;
    }
  }

  // ── Streams from repositories ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: StreamBuilder<HunterData?>(
        stream: HunterRepository.instance.watch(),
        initialData: HunterRepository.instance.getCached(),
        builder: (context, snapshot) {
          final hunter = snapshot.data;
          if (hunter == null) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: buildProfileSkeleton(),
              ),
            );
          }

          final hunterName     = hunter.hunterName;
          final xp             = hunter.xp;
          final level          = hunter.level;
          final duelWins       = hunter.duelWins;
          final duelLosses     = hunter.duelLosses;
          final questsDone     = hunter.questsDone;
          final streak         = hunter.streak;

          final height         = hunter.height;
          final weight         = hunter.weight;
          final startingWeight = hunter.startingWeight > 0 ? hunter.startingWeight : weight;
          final targetWeight   = hunter.targetWeight;

          double bmi = 0;
          if (height > 0) bmi = weight / math.pow(height / 100, 2);

          final rank        = _getRank(xp);
          final nextRank    = _getNextRank(rank);
          final rankColor   = _getRankColor(rank);
          final xpStart     = _xpStartForRank(rank);
          final xpEnd       = _xpForRank(rank);
          final xpProgress  = rank == 'S'
              ? 1.0
              : (xp - xpStart) / math.max(1, xpEnd - xpStart);
          final xpToNext    = rank == 'S' ? 0 : math.max(0, xpEnd - xp);

          // Derived stats
          final str  = math.min(100, duelWins * 3 + level * 2);
          final agi  = bmi > 0 && bmi < 25
              ? math.min(100, (100 - bmi * 2).round())
              : 50;
          final vit  = weight > 0 ? 65 : 40;

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    Container(
                      height: 320,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            rankColor.withOpacity(0.15),
                            HunterTheme.background,
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // Back button row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Share pill button (left top corner)
                                GestureDetector(
                                  onTap: () => _shareStatsCard(
                                    context: context,
                                    hunterName: hunterName,
                                    rank: rank,
                                    level: level,
                                    xp: xp,
                                    xpProgress: xpProgress,
                                    streak: streak,
                                    str: str,
                                    vit: vit,
                                    agi: agi,
                                    profilePicture: hunter.profilePicture,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: HunterTheme.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: HunterTheme.primary),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.share,
                                            color: HunterTheme.primary, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Share',
                                          style: TextStyle(
                                            color: HunterTheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.settings,
                                    color: HunterTheme.textSecondary,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            // Guest account linking banner
                            if (FirebaseAuth
                                .instance.currentUser?.isAnonymous ==
                                true) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: HunterTheme.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: HunterTheme.primary),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "⚠️ You're a Guest!",
                                      style: TextStyle(
                                        color: HunterTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Link Google to save your progress",
                                      style: TextStyle(
                                        color: HunterTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _linkingGoogle
                                            ? null
                                            : _linkGoogleAccount,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                          HunterTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: _linkingGoogle
                                            ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                            : const Icon(Icons.link, size: 18),
                                        label: Text(_linkingGoogle
                                            ? "Linking..."
                                            : "Link Google Account"),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Avatar
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: rankColor.withOpacity(0.5),
                                        blurRadius: 30,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                    border: Border.all(
                                        color: rankColor, width: 2.5),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _uploadProfilePicture,
                                  child: PremiumAvatar(
                                    membership: MembershipService
                                        .instance.membershipName
                                        .toLowerCase(),
                                    radius: 53,
                                    image: _decodedProfilePic(hunter.profilePicture) != null
                                        ? MemoryImage(_cachedProfilePicBytes!)
                                        : null,
                                    child: hunter.profilePicture == null
                                        ? Icon(Icons.person,
                                        size: 60,
                                        color: rankColor.withOpacity(0.9))
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _uploadProfilePicture,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: HunterTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: HunterTheme.background,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.black,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // ── Name — pencil icon REMOVED ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    hunterName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: HunterTheme.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                MembershipBadge(
                                  membership: MembershipService.instance.membershipName.toLowerCase(),
                                ),

                                const SizedBox(width: 8),

                                GestureDetector(
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: hunterName),
                                    );

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Hunter name copied!'),
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    Icons.copy,
                                    color: HunterTheme.primary,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: rankColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: rankColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                '$rank RANK HUNTER',
                                style: TextStyle(
                                  color: rankColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // XP bar
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      rank == 'S'
                                          ? 'MAX RANK'
                                          : '$xpToNext XP to Rank $nextRank',
                                      style: TextStyle(
                                        color: HunterTheme.textPrimary.withOpacity(0.65),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '$xp XP',
                                      style: TextStyle(
                                        color: HunterTheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: xpProgress.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                    HunterTheme.textPrimary.withOpacity(0.1),
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(rankColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MembershipScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      HunterTheme.primary.withOpacity(0.15),
                                      HunterTheme.gold.withOpacity(0.12),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: HunterTheme.primary.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.workspace_premium,
                                      color: HunterTheme.gold,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Hunter Membership",
                                            style: TextStyle(
                                              color: HunterTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Unlock PRO & MAX rewards",
                                            style: TextStyle(
                                              color: HunterTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: HunterTheme.primary,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

// Level / Quests / Duels row

                            // Level / Quests / Duels row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _statPill('$level', 'LEVEL'),
                                _vDivider(),
                                _statPill('$questsDone', 'MISSIONS'),
                                _vDivider(),
                                _statPill('$duelWins', 'DUELS WON'),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab bar ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: HunterTheme.textPrimary.withOpacity(0.08)),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: HunterTheme.primary,
                    unselectedLabelColor: HunterTheme.textTertiary,
                    indicatorColor: HunterTheme.primary,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                    isScrollable: false,
                    tabs: const [
                      Tab(text: 'REPORTS'),
                      Tab(text: 'PHYSIQUE'),
                      Tab(text: 'HISTORY'),
                    ],
                  ),
                ),
              ),
            ],

            // ── Tab content ─────────────────────────────────────────
            body: TabBarView(
                  controller: _tabController,
                  children: [

                    // ── REPORTS (premium: Pro/Max) ────────────────────
                    ReportsTab(
                      uid: user?.uid ?? '',
                      hunterData: hunter.toFirestore(),
                    ),

                    // ── PHYSIQUE ──────────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _card(
                            child: Column(
                              children: [
                                Text(
                                  '🔥 ${_getHunterClass(bmi)}',
                                  style: TextStyle(
                                    color: HunterTheme.gold,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                                  children: [
                                    _physiqueInfo('BMI',
                                        bmi.toStringAsFixed(1),
                                        Icons.monitor_heart_outlined),
                                    _physiqueInfo('START',
                                        '${startingWeight.toStringAsFixed(1)} kg',
                                        Icons.flag_outlined),
                                    _physiqueInfo('CURRENT',
                                        '${weight.toStringAsFixed(1)} kg',
                                        Icons.monitor_weight_outlined),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: HunterTheme.textPrimary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        weight <= startingWeight
                                            ? Icons.trending_down
                                            : Icons.trending_up,
                                        color: weight <= startingWeight
                                            ? HunterTheme.successAlt
                                            : HunterTheme.dangerAlt,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(weight - startingWeight).abs().toStringAsFixed(1)} kg ${weight <= startingWeight ? "lost" : "gained"} since start',
                                        style: TextStyle(
                                          color: weight <= startingWeight
                                              ? HunterTheme.successAlt
                                              : HunterTheme.dangerAlt,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ── Target Weight Progress ──
                                if (targetWeight != null && targetWeight! > 0) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: HunterTheme.primary.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: HunterTheme.primary.withOpacity(0.15)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Target', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
                                            GestureDetector(
                                              onTap: () => _showSetTargetWeightDialog(),
                                              child: Text('Edit', style: TextStyle(color: HunterTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${targetWeight!.toStringAsFixed(1)} kg',
                                          style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        () {
                                          final remaining = (weight - targetWeight!).abs();
                                          final bool isFatLoss = targetWeight! < startingWeight;
                                          final bool goalReached = isFatLoss ? weight <= targetWeight! : weight >= targetWeight!;
                                          return Text(
                                            goalReached
                                                ? 'Goal reached!'
                                                : '${remaining.toStringAsFixed(1)} kg to goal',
                                            style: TextStyle(
                                              color: goalReached ? HunterTheme.success : HunterTheme.textSecondary,
                                              fontSize: 12,
                                              fontWeight: goalReached ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          );
                                        }(),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 14),
                                  GestureDetector(
                                    onTap: () => _showSetTargetWeightDialog(),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: HunterTheme.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: HunterTheme.border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.flag_outlined, color: HunterTheme.primary, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Set Target Weight',
                                            style: TextStyle(
                                              color: HunterTheme.primary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HunterTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: showUpdateWeightDialog,
                              icon: const Icon(Icons.monitor_weight),
                              label: const Text(
                                'UPDATE WEIGHT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── HISTORY — weight history inline, no separate page ──
                    _buildWeightHistoryTab(user),
                  ],
                ),
          );
        },
      ),
    );
  }

  // ── Inline Weight History Tab ──────────────────────────────────────
  Widget _buildWeightHistoryTab(User? user) {
    return StreamBuilder<List<WeightEntry>>(
      stream: WeightRepository.instance.watch(),
      initialData: WeightRepository.instance.getCached(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _centeredScrollSafe(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final entries = snapshot.data;
        if (entries == null) {
          return _centeredScrollSafe(
            child: CircularProgressIndicator(color: HunterTheme.primary),
          );
        }

        if (entries.isEmpty) {
          return _centeredScrollSafe(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monitor_weight_outlined,
                    color: HunterTheme.textFaint, size: 64),
                const SizedBox(height: 16),
                Text('No weight history yet',
                    style: TextStyle(
                        color: HunterTheme.textTertiary, fontSize: 16)),
                const SizedBox(height: 8),
                Text('Update your weight in the Physique tab',
                    style: TextStyle(
                        color: HunterTheme.textFaint, fontSize: 13)),
              ],
            ),
          );
        }

        final currentWeight  = entries.first.weight;
        final startingWeight = entries.last.weight;
        final weightLost     = startingWeight - currentWeight;

        String title;
        String message;
        if (weightLost >= 20) {
          title   = "\ud83d\udc51 Legendary Hunter";
          message = "This isn't luck. This is discipline.";
        } else if (weightLost >= 10) {
          title   = "\u2b50 Elite Progress";
          message = "You are becoming the person you promised yourself you'd be.";
        } else if (weightLost >= 5) {
          title   = "\ud83c\udfc6 Transformation Begins";
          message = "Most hunters quit early. You didn't.";
        } else if (weightLost >= 3) {
          title   = "\u2694\ufe0f Momentum Rising";
          message = "Your consistency is becoming visible.";
        } else if (weightLost > 0) {
          title   = "\ud83d\udd25 First Victories";
          message = "You've started the journey. Keep moving forward, Hunter.";
        } else {
          title   = "\ud83c\udf31 New Hunter";
          message = "Every Hunter starts somewhere.";
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HunterTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HunterTheme.primary.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      weightLost >= 0
                          ? "\ud83d\udd25 Total Lost: ${weightLost.toStringAsFixed(1)} kg"
                          : "\ud83d\udcc8 Total Gained: ${weightLost.abs().toStringAsFixed(1)} kg",
                      style: TextStyle(
                        color: weightLost >= 0
                            ? Colors.greenAccent
                            : HunterTheme.dangerAlt,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: HunterTheme.textSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Entry list
              ...entries.map((entry) {
                final date = entry.dateTime;
                final dateStr =
                    "${date.day.toString().padLeft(2, '0')}/"
                    "${date.month.toString().padLeft(2, '0')}/"
                    "${date.year}";

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: HunterTheme.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunterTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.monitor_weight_outlined,
                            color: HunterTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(dateStr,
                            style: TextStyle(
                                color: HunterTheme.textSecondary, fontSize: 13)),
                      ),
                      Text(
                        '${entry.weight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────

  /// Wraps a small, centered widget so it can never cause a RenderFlex
  /// overflow inside the bounded [TabBarView]/[SliverFillRemaining] area.
  ///
  /// On tall viewports the child stays vertically centered; on short viewports
  /// (small devices, split-screen) the content scrolls instead of overflowing.
  Widget _centeredScrollSafe({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  Widget _statPill(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 36, width: 1, color: Color(0x1FFF6B2B));

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: HunterTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: HunterTheme.primary.withOpacity(0.2)),
    ),
    child: child,
  );

  Widget _physiqueInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: HunterTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                letterSpacing: 1.5)),
      ],
    );
  }
  // ── Link Google account to anonymous guest ──────────────────────────
  // Links the signed-in Google credential to the existing anonymous account,
  // preserving the same uid (and therefore ALL existing Firestore data).
  Future<void> _linkGoogleAccount() async {
    setState(() => _linkingGoogle = true);
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId:
        '300244677091-a867dd5tr6dfnjtngiikjp3grfdvnsrn.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _linkingGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.currentUser!
          .linkWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Update the existing hunter document with the Google email + uid.
        // merge:true keeps all existing data (XP, level, streak, missions).
        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .set({
          'email': user.email,
          'uid': user.uid,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() => _linkingGoogle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google account linked successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _linkingGoogle = false);
        String message = 'Could not link account. Please try again.';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'credential-already-in-use':
              message = 'This Google account is already linked to another Hunter.';
              break;
            case 'provider-already-linked':
              message = 'This Google account is already linked.';
              break;
            case 'network-request-failed':
              message = 'Network error. Please try again.';
              break;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // ── Share stats card as image ──────────────────────────────────────
  Future<void> _shareStatsCard({
    required BuildContext context,
    required String hunterName,
    required String rank,
    required int level,
    required int xp,
    required double xpProgress,
    required int streak,
    required int str,
    required int vit,
    required int agi,
    String? profilePicture,
  }) async {
    try {
      final controller = ScreenshotController();
      final bytes = await controller.captureFromWidget(
        _buildShareCard(
          hunterName: hunterName,
          rank: rank,
          level: level,
          xp: xp,
          xpProgress: xpProgress,
          streak: streak,
          str: str,
          vit: vit,
          agi: agi,
          membership: MembershipService.instance.membershipName.toLowerCase(),
          profilePicture: profilePicture,
        ),
        context: context,
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
      );

      final dir = await Directory.systemTemp.createTemp('hunter_share');
      final file = File('${dir.path}/hunter_ascend_stats.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "🔥 I'm a $rank Rank Hunter on Hunter Ascend!\n"
            "⚡ Level $level | $streak Day Streak\n"
            "💪 Ascend Beyond Limits!\n\n"
            "📲 Download Hunter Ascend FREE:\n"
            "https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share stats: $e')),
        );
      }
    }
  }

  // Card captured as an image (not shown as a screen) — premium Hunter ID card.
  //
  // Helper: extracts up to 2 initials from the hunter name for the avatar fallback.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildShareCard({
    required String hunterName,
    required String rank,
    required int level,
    required int xp,
    required double xpProgress,
    required int streak,
    required int str,
    required int vit,
    required int agi,
    required String membership,
    String? profilePicture,
  }) {
    // Membership-aware accent colours (fixed dark palette for social consistency).
    final bool isMax = membership == 'max';
    final bool isPro = membership == 'pro';
    final Color accent = isMax
        ? const Color(0xFFB98CFF)
        : (isPro ? const Color(0xFFFFD54A) : const Color(0xFFFF7A3D));
    final Color accentSecondary = isMax
        ? const Color(0xFFFFD54A)
        : (isPro ? const Color(0xFFFFB300) : const Color(0xFFFF9E5C));
    const textPrimary = Color(0xFFF5F6F8);
    const textSecondary = Color(0xFFC2C8D2);
    const textTertiary = Color(0xFF808895);

    String membershipLabel = 'HUNTER';
    if (isPro) membershipLabel = 'PRO HUNTER';
    if (isMax) membershipLabel = 'MAX HUNTER';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0C1017), Color(0xFF070A10)],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.06),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.45), width: 1.5),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.20), blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Branding
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: accent, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'HUNTER ASCEND',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent.withOpacity(0),
                      accent.withOpacity(0.4),
                      accent.withOpacity(0),
                    ]),
                  ),
                ),
                const SizedBox(height: 22),
                // Avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.7), width: 2.5),
                    boxShadow: [
                      BoxShadow(color: accent.withOpacity(0.35), blurRadius: 18),
                      if (isMax)
                        BoxShadow(color: accentSecondary.withOpacity(0.25), blurRadius: 24),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF14161C),
                    backgroundImage: profilePicture != null
                        ? MemoryImage(_decodedProfilePic(profilePicture)!)
                        : null,
                    child: profilePicture == null
                        ? Text(
                            _initials(hunterName),
                            style: TextStyle(
                              color: accent,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                // Hunter Name (large)
                Text(
                  hunterName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                // Membership label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withOpacity(0.6)),
                  ),
                  child: Text(
                    membershipLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                // Level (main focus)
                const Text(
                  'LEVEL',
                  style: TextStyle(
                    color: textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$level',
                  style: TextStyle(
                    color: accent,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                // XP progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$xp / 500 XP',
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(xpProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpProgress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                const SizedBox(height: 22),
                // Streak (visually prominent — key social proof)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text('\u{1F525}', style: TextStyle(fontSize: 24)),
                      const SizedBox(height: 6),
                      Text(
                        '$streak',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DAY STREAK',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent.withOpacity(0),
                      accent.withOpacity(0.35),
                      accent.withOpacity(0),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                // Footer
                const Text(
                  'Hunter Ascend',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level Up Your Real Life',
                  style: TextStyle(
                    color: accentSecondary.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _uploadProfilePicture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (picked == null) return;

      final file = File(picked.path);

      // Compress to max 15KB
      final compressed = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 200,
        minHeight: 200,
        quality: 30,
        format: CompressFormat.jpeg,
      );

      if (compressed == null) return;

      // Convert to base64
      final base64Image = base64Encode(compressed);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({'profilePicture': base64Image});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile picture updated!')),
        );
      }
    } catch (e) {
      debugPrint("uploadProfilePicture: $e");
    }
  }

  void _showSetTargetWeightDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: HunterTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Set Target Weight', style: TextStyle(color: HunterTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your goal weight in kg.',
                style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: HunterTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Target weight (kg)',
                  hintStyle: TextStyle(color: HunterTheme.textTertiary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: HunterTheme.primary, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: HunterTheme.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: HunterTheme.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HunterTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final target = double.tryParse(controller.text);
                if (target == null || target <= 20) return;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('hunters')
                      .doc(user.uid)
                      .update({'targetWeight': target});

                  // Reset weight goal celebration for the new target.
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('milestone_weight_goal_target_celebrated');

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                } catch (e) {
                  debugPrint("setTargetWeight: $e");
                }
              },
              child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void showUpdateWeightDialog() {
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: HunterTheme.cardColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Update Current Weight',
              style: TextStyle(color: HunterTheme.textPrimary)),
          content: TextField(
            controller: weightController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: HunterTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Weight in kg',
              hintStyle: TextStyle(color: HunterTheme.textTertiary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: HunterTheme.primary, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: HunterTheme.primary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL',
                  style: TextStyle(color: HunterTheme.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HunterTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final weight =
                double.tryParse(weightController.text);
                if (weight == null) return;

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('hunters')
                      .doc(user.uid)
                      .update({'weight': weight});

                  await FirebaseFirestore.instance
                      .collection('weight_history')
                      .add({
                    'uid': user.uid,
                    'weight': weight,
                    'date': Timestamp.now(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    // Check for weight goal milestone.
                    MilestoneService.checkWeightGoal(context, weight);
                  }
                } catch (e) {
                  debugPrint("updateWeight: $e");
                }
              },
              child: const Text('SAVE',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// ── Hex Radar Chart ────────────────────────────────────────────────────

/// Draws the hexagonal radar chart of a hunter's six core stats.
class HexRadarPainter extends CustomPainter {
  final List<double> values;

  const HexRadarPainter({required this.values});

  static const _labels = ['STR', 'INT', 'VIT', 'AGI', 'LUK', 'END'];

  @override
  void paint(Canvas canvas, Size size) {
    final cx   = size.width / 2;
    final cy   = size.height / 2;
    final maxR = size.height * 0.38;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = HunterTheme.textPrimary.withOpacity(0.08)
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 5; ring++) {
      canvas.drawPath(_hexPath(cx, cy, maxR * ring / 5), gridPaint);
    }

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxR * math.cos(angle), cy + maxR * math.sin(angle)),
        gridPaint,
      );
    }

    final dataPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final r = maxR * values[i].clamp(0.0, 1.0);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) dataPath.moveTo(x, y);
      else dataPath.lineTo(x, y);
    }
    dataPath.close();

    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = HunterTheme.primary.withOpacity(0.18));
    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = HunterTheme.primary.withOpacity(0.85)
          ..strokeWidth = 1.5);

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final lx = cx + (maxR + 26) * math.cos(angle);
      final ly = cy + (maxR + 26) * math.sin(angle);
      final displayValue = (values[i] * 100).round();

      _drawText(canvas, _labels[i], lx, ly - 7,
          HunterTheme.primary, 11, FontWeight.bold);
      _drawText(canvas, '$displayValue', lx, ly + 8,
          HunterTheme.textSecondary, 11, FontWeight.normal);
    }
  }

  Path _hexPath(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  void _drawText(Canvas canvas, String text, double x, double y,
      Color color, double fontSize, FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant HexRadarPainter old) =>
      old.values != values;
}