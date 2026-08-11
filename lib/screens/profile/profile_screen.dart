import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/settings/settings_screen.dart';
import 'package:hunter_ascend/services/achievements_service.dart';
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
import 'package:hunter_ascend/screens/profile/shop_screen.dart';
import 'package:hunter_ascend/screens/profile/reports/reports_tab.dart';
import 'package:hunter_ascend/screens/profile/achievements/achievements_tab.dart';
import 'package:hunter_ascend/screens/profile/rewards/rewards_tab.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/equipped_badge_chip.dart';
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

  String _getHunterClass(double bmi) {
    if (bmi < 18.5) return 'AGILE HUNTER';
    if (bmi < 25)   return 'BALANCED HUNTER';
    if (bmi < 30)   return 'TANK HUNTER';
    return 'HEAVY TANK HUNTER';
  }

  // ── Streams from repositories ──────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listens to MembershipService.tierNotifier (in addition to the theme
    // notifiers) so the membership badge, avatar frame/glow, and the
    // "Hunter Membership" banner update immediately when the tier changes
    // (e.g. after watching a rewarded ad, or after MembershipService's
    // Firestore listener catches up) — not just when the HunterData
    // StreamBuilder below happens to rebuild for an unrelated field change.
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipService.instance.tierNotifier,
        SkinService.instance.activeSkinNotifier,
        SkinService.instance.skinAppearanceActiveNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MembershipScaffold(
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

          // Hunter Rank is resolved from LEVEL via the centralized RankService
          // (the stored `xp` is only the in-level remainder). Progress and
          // "XP to next rank" are derived from level + that remainder.
          final rankData     = RankService.instance.rankForLevel(level);
          final rankTitle    = rankData.longTitle; // e.g. "S RANK HUNTER" / "NATIONAL HUNTER"
          final isMaxRank    = RankService.instance.isMaxRank(level);
          final nextRankName = RankService.instance.nextRank(level)?.label ?? 'MAX';
          final rankColor    = rankData.color;
          final xpProgress   = RankService.instance.progressToNextRank(level, xp);
          final xpToNext     = RankService.instance.xpToNextRank(level, xp);

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
                      height: 340,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            rankColor.withOpacity(0.22),
                            rankColor.withOpacity(0.06),
                            HunterTheme.background,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                    // Soft radial halo behind the avatar for premium depth.
                    Positioned(
                      top: -40,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 260,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topCenter,
                              radius: 0.9,
                              colors: [rankColor.withOpacity(0.16), Colors.transparent],
                            ),
                          ),
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
                                    rank: rankTitle,
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
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          MembershipTheme.current.accent.withOpacity(0.18),
                                          MembershipTheme.current.accent.withOpacity(0.06),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                          color: MembershipTheme.current.accent.withOpacity(0.5)),
                                      boxShadow: [
                                        BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 3)),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.ios_share_rounded,
                                            color: MembershipTheme.current.accent, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Share',
                                          style: TextStyle(
                                            color: MembershipTheme.current.accent,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: HunterTheme.cardColor,
                                      border: Border.all(color: HunterTheme.border),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.settings_rounded,
                                      color: HunterTheme.textSecondary,
                                      size: 20,
                                    ),
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
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      MembershipTheme.current.accent.withOpacity(0.14),
                                      HunterTheme.cardColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: MembershipTheme.current.accent.withOpacity(0.45)),
                                  boxShadow: [
                                    BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.12), blurRadius: 16),
                                  ],
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
                                          MembershipTheme.current.accent,
                                          foregroundColor: MembershipTheme.isPro
                                              ? Colors.black
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: _linkingGoogle
                                            ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: MembershipTheme.isPro
                                                ? Colors.black
                                                : Colors.white,
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
                            // Avatar — premium membership frame (Pro gold /
                            // Max rotating purple-violet / Basic rank-tinted).
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                GestureDetector(
                                  onTap: _uploadProfilePicture,
                                  child: _ProfileMembershipAvatar(
                                    membership: MembershipService
                                        .instance.membershipName
                                        .toLowerCase(),
                                    radius: 53,
                                    basicAccent: rankColor,
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
                                  bottom: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: _uploadProfilePicture,
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: MembershipTheme.current.gradient,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: HunterTheme.background,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.4), blurRadius: 8),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.camera_alt_rounded,
                                        color: MembershipTheme.isMax
                                            ? Colors.white
                                            : Colors.black,
                                        size: 15,
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

                                EquippedBadgeChip(badgeId: hunter.equippedBadgeId, size: 18),

                                const SizedBox(width: 6),

                                _membershipChip(
                                  MembershipService.instance.membershipName.toLowerCase(),
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
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: MembershipTheme.current.accent.withOpacity(0.10),
                                    ),
                                    child: Icon(
                                      Icons.copy_rounded,
                                      color: MembershipTheme.current.accent,
                                      size: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    rankColor.withOpacity(0.18),
                                    rankColor.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: rankColor.withOpacity(0.55)),
                                boxShadow: [
                                  BoxShadow(color: rankColor.withOpacity(0.15), blurRadius: 10),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_moon_rounded, color: rankColor, size: 15),
                                  const SizedBox(width: 7),
                                  Text(
                                    rankTitle,
                                    style: TextStyle(
                                      color: rankColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // XP bar — premium rounded gradient track with glow.
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isMaxRank
                                            ? 'MAX RANK REACHED'
                                            : '$xpToNext XP to $nextRankName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: HunterTheme.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$xp XP',
                                      style: TextStyle(
                                        color: MembershipTheme.current.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: HunterTheme.textPrimary.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: xpProgress.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 9,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [rankColor.withOpacity(0.85), rankColor],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(color: rankColor.withOpacity(0.5), blurRadius: 8, spreadRadius: 0.5),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      MembershipTheme.current.accent.withOpacity(0.16),
                                      HunterTheme.gold.withOpacity(0.12),
                                      HunterTheme.cardColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: HunterTheme.gold.withOpacity(0.4),
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: HunterTheme.gold.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: HunterTheme.gold.withOpacity(0.15),
                                        border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
                                      ),
                                      child: Icon(
                                        Icons.workspace_premium,
                                        color: HunterTheme.gold,
                                        size: 24,
                                      ),
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
                                      color: MembershipTheme.current.accent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Level / Missions / Duels / Streak — premium stats bar.
                            // Phase 3: wrapped in SkinAwareSurface (no-op for
                            // Classic/Premium-Theme users — see that widget's
                            // doc comment).
                            SkinAwareSurface(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                                decoration: BoxDecoration(
                                  color: HunterTheme.cardColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: HunterTheme.border),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(child: _statPill('$level', 'LEVEL', Icons.military_tech_rounded, MembershipTheme.current.accent)),
                                    _vDivider(),
                                    Expanded(child: _statPill('$questsDone', 'MISSIONS', Icons.checklist_rounded, HunterTheme.purple)),
                                    _vDivider(),
                                    Expanded(child: _statPill('$duelWins', 'DUELS', Icons.sports_kabaddi_rounded, HunterTheme.gold)),
                                    _vDivider(),
                                    Expanded(child: _statPill('$streak', 'STREAK', Icons.local_fire_department_rounded, Colors.orange)),
                                  ],
                                ),
                              ),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: HunterTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HunterTheme.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor:
                          MembershipTheme.isMax ? Colors.white : Colors.black,
                      unselectedLabelColor: HunterTheme.textSecondary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(12),
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: MembershipTheme.current.gradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.35), blurRadius: 10, spreadRadius: 0.5),
                        ],
                      ),
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'REPORTS'),
                        Tab(text: 'PHYSIQUE'),
                        Tab(text: 'ACHIEVEMENTS'),
                        Tab(text: 'REWARDS'),
                      ],
                    ),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        HunterTheme.gold.withOpacity(0.18),
                                        HunterTheme.gold.withOpacity(0.04),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: HunterTheme.gold.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_fire_department_rounded, color: HunterTheme.gold, size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _getHunterClass(bmi),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: HunterTheme.gold,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                      color: MembershipTheme.current.accent.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.15)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Target', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
                                            GestureDetector(
                                              onTap: () => _showSetTargetWeightDialog(
                                                currentWeight: weight,
                                                fatLoss: hunter.fatLoss,
                                                muscleGain: hunter.muscleGain,
                                              ),
                                              child: Text('Edit', style: TextStyle(color: MembershipTheme.current.accent, fontSize: 11, fontWeight: FontWeight.w600)),
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
                                                ? '\ud83c\udfaf Goal Reached'
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Target', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w600)),
                                      Text('Not Set', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _showSetTargetWeightDialog(
                                      currentWeight: weight,
                                      fatLoss: hunter.fatLoss,
                                      muscleGain: hunter.muscleGain,
                                    ),
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
                                          Icon(Icons.flag_outlined, color: MembershipTheme.current.accent, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Set Target Weight',
                                            style: TextStyle(
                                              color: MembershipTheme.current.accent,
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
                                backgroundColor: MembershipTheme.current.accent,
                                foregroundColor: MembershipTheme.isPro
                                    ? Colors.black
                                    : Colors.white,
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

                          // ── Weight history (moved here from old History tab) ──
                          const SizedBox(height: 24),
                          _buildWeightHistoryContent(),
                        ],
                      ),
                    ),

                    // ── ACHIEVEMENTS ──────────────────────────────────
                    AchievementsTab(hunter: hunter),

                    // ── REWARDS ────────────────────────────────────────
                    RewardsTab(hunter: hunter),
                  ],
                ),
          );
        },
      ),
    );
  }

  // ── Inline Weight History (embedded inside the Physique tab) ────────
  Widget _buildWeightHistoryContent() {
    return StreamBuilder<List<WeightEntry>>(
      stream: WeightRepository.instance.watch(),
      initialData: WeightRepository.instance.getCached(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(snapshot.error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          );
        }

        final entries = snapshot.data;
        if (entries == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _weightHistoryHeader(),
                const SizedBox(height: 20),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MembershipTheme.current.accent.withOpacity(0.10),
                    border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.30), width: 1.4),
                    boxShadow: [
                      BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.14), blurRadius: 22),
                    ],
                  ),
                  child: Icon(Icons.monitor_weight_outlined,
                      color: MembershipTheme.current.accent, size: 38),
                ),
                const SizedBox(height: 20),
                Text('No weight history yet',
                    style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Update your weight in the Physique tab',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: HunterTheme.textSecondary, fontSize: 13, height: 1.4)),
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

        return Column(
            children: [
              _weightHistoryHeader(),
              const SizedBox(height: 14),
              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HunterTheme.gold.withOpacity(0.10),
                      HunterTheme.cardColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HunterTheme.gold.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(color: HunterTheme.gold.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      weightLost >= 0
                          ? "\ud83d\udd25 Total Lost: ${weightLost.toStringAsFixed(1)} kg"
                          : "\ud83d\udcc8 Total Gained: ${weightLost.abs().toStringAsFixed(1)} kg",
                      style: TextStyle(
                        color: weightLost >= 0
                            ? HunterTheme.success
                            : HunterTheme.dangerAlt,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(title,
                        style: TextStyle(
                            color: HunterTheme.gold,
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
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: HunterTheme.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MembershipTheme.current.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.monitor_weight_outlined,
                            color: MembershipTheme.current.accent, size: 20),
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
        );
      },
    );
  }

  // ── Section header for the inline weight history block ──────────────
  Widget _weightHistoryHeader() {
    return Row(
      children: [
        Icon(Icons.history_rounded, color: HunterTheme.gold, size: 18),
        const SizedBox(width: 8),
        Text(
          'WEIGHT HISTORY',
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────

  Widget _statPill(String value, String label, IconData icon, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _vDivider() =>
      Container(height: 40, width: 1, color: HunterTheme.border);

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          MembershipTheme.current.accent.withOpacity(0.06),
          HunterTheme.cardColor,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: MembershipTheme.current.accent.withOpacity(0.18)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6)),
      ],
    ),
    child: child,
  );

  Widget _physiqueInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MembershipTheme.current.accent.withOpacity(0.10),
            border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.25)),
          ),
          child: Icon(icon, color: MembershipTheme.current.accent, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600)),
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
        text: "🔥 I'm a $rank on Hunter Ascend!\n"
            "⚡ Level $level | $streak Day Streak\n"
            "💪 Ascend Beyond Limits!\n\n"
            "📲 Download Hunter Ascend FREE:\n"
            "https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend",
      );

      // Record that the hunter has shared their profile card (backs the
      // "Share Profile" achievement) and immediately re-evaluate/celebrate.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .update({'hasSharedProfile': true});
        } catch (e) {
          debugPrint('shareStatsCard hasSharedProfile write: $e');
        }
        if (mounted) {
          await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
        }
      }
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
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.22),
                const Color(0xFF0C1017),
                const Color(0xFF070A10),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Brand row ──
              Row(
                children: [
                  Icon(Icons.bolt, color: accent, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'HUNTER ASCEND',
                    style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.5),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withOpacity(0.6)),
                    ),
                    child: Text(
                      membershipLabel,
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // ── Hero: avatar + name + rank ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accentSecondary],
                      ),
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 20)],
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFF14161C),
                      backgroundImage: profilePicture != null
                          ? MemoryImage(_decodedProfilePic(profilePicture)!)
                          : null,
                      child: profilePicture == null
                          ? Text(
                              _initials(hunterName),
                              style: TextStyle(color: accent, fontSize: 28, fontWeight: FontWeight.w900),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hunterName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: textPrimary, fontSize: 24, fontWeight: FontWeight.w900, height: 1.05),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withOpacity(0.5)),
                          ),
                          child: Text(
                            rank,
                            style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              // ── Hero stat band ──
              Row(
                children: [
                  _shareStat('LEVEL', '$level', accent, textTertiary),
                  _shareStatDivider(),
                  _shareStat('DAY STREAK', '$streak', accentSecondary, textTertiary),
                  _shareStatDivider(),
                  _shareStat('TOTAL XP', '$xp', textPrimary, textTertiary),
                ],
              ),
              const SizedBox(height: 24),
              // ── XP progress ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$xp / 500 XP', style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${(xpProgress * 100).toInt()}%', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 9, color: Colors.white.withOpacity(0.08)),
                    FractionallySizedBox(
                      widthFactor: xpProgress.clamp(0.0, 1.0),
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [accent, accentSecondary])),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 14),
              // ── Branding footer ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Level Up Your Real Life', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'Download Hunter Ascend',
                          style: TextStyle(color: accentSecondary.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, accentSecondary]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.black, size: 16),
                        SizedBox(width: 4),
                        Text('Google Play', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareStat(String label, String value, Color valueColor, Color labelColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: valueColor, fontSize: 28, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: labelColor, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _shareStatDivider() =>
      Container(width: 1, height: 34, color: Colors.white.withOpacity(0.08));

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

      // Immediately re-evaluate achievements against the just-written data
      // and celebrate anything newly unlocked, so this doesn't depend on the
      // user separately opening the Achievements screen.
      if (mounted) {
        await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
      }
    } catch (e) {
      debugPrint("uploadProfilePicture: $e");
    }
  }

  // ── Set/Edit Target Weight ──────────────────────────────────────────
  //
  // [currentWeight] and the goal flags are passed in from the caller (rather
  // than re-read here) so this dialog can validate the target weight
  // direction against the hunter's selected goal, mirroring the same
  // fatLoss/muscleGain direction check already used during Path Selection
  // (see quest_selection_screen.dart's goal-mismatch dialog). "Maintain"
  // (neither fatLoss nor muscleGain selected) falls back to the app's
  // original validation rule (a valid positive weight).
  //
  // Only `targetWeight` is ever written to Firestore here — XP, level,
  // streak, quests, achievements, membership, and reports are untouched.
  void _showSetTargetWeightDialog({
    required double currentWeight,
    required bool fatLoss,
    required bool muscleGain,
  }) {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
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
                    autofocus: true,
                    style: TextStyle(color: HunterTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Target weight (kg)',
                      hintStyle: TextStyle(color: HunterTheme.textTertiary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: MembershipTheme.current.accent, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: MembershipTheme.current.accent, width: 2),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText != null) setDialogState(() => errorText = null);
                    },
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: TextStyle(color: HunterTheme.danger, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('CANCEL', style: TextStyle(color: HunterTheme.textTertiary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MembershipTheme.current.accent,
                    foregroundColor: MembershipTheme.isPro
                        ? Colors.black
                        : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final target = double.tryParse(controller.text);
                    if (target == null || target <= 20) {
                      setDialogState(() =>
                          errorText = 'Enter a valid target weight (above 20 kg).');
                      return;
                    }

                    // Goal-direction validation.
                    // Fat Loss takes priority if multiple paths are selected,
                    // matching the precedence already used in
                    // quest_selection_screen.dart's goal-mismatch check.
                    if (fatLoss && target >= currentWeight) {
                      setDialogState(() => errorText =
                          'For Fat Loss, target weight must be less than your current weight (${currentWeight.toStringAsFixed(1)} kg).');
                      return;
                    }
                    if (muscleGain && target <= currentWeight) {
                      setDialogState(() => errorText =
                          'For Muscle Gain, target weight must be greater than your current weight (${currentWeight.toStringAsFixed(1)} kg).');
                      return;
                    }
                    // Maintain (neither goal selected): no extra directional
                    // check — the app's existing rule (valid positive weight,
                    // already enforced above) is all that applies.

                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    try {
                      // Only the target weight field is updated — no XP,
                      // level, streak, quest, achievement, membership, or
                      // report data is touched by this write.
                      await FirebaseFirestore.instance
                          .collection('hunters')
                          .doc(user.uid)
                          .update({'targetWeight': target});

                      // Reset weight goal celebration for the new target.
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('milestone_weight_goal_target_celebrated');

                      if (mounted) {
                        Navigator.pop(dialogContext);
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
                BorderSide(color: MembershipTheme.current.accent, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                BorderSide(color: MembershipTheme.current.accent, width: 2),
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
                backgroundColor: MembershipTheme.current.accent,
                foregroundColor: MembershipTheme.isPro
                    ? Colors.black
                    : Colors.white,
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
                    // Immediately re-evaluate/celebrate any achievement this
                    // weight update just satisfied (body_first_update,
                    // body_lose_5/10, body_gain_muscle, body_bmi_improved).
                    await AchievementsService.instance.checkAndCelebrateForCurrentUser(context);
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
          ..color = MembershipTheme.current.accent.withOpacity(0.18));
    canvas.drawPath(dataPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = MembershipTheme.current.accent.withOpacity(0.85)
          ..strokeWidth = 1.5);

    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 6;
      final lx = cx + (maxR + 26) * math.cos(angle);
      final ly = cy + (maxR + 26) * math.sin(angle);
      final displayValue = (values[i] * 100).round();

      _drawText(canvas, _labels[i], lx, ly - 7,
          MembershipTheme.current.accent, 11, FontWeight.bold);
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



// ── Profile membership visual system ─────────────────────────────────────────
//
// Cohesive with the Dashboard benchmark: Pro = gold, Max = purple/violet.
// (The Leaderboard uses a blue/cyan Pro treatment per its own explicit spec;
// the Profile intentionally matches the Dashboard's gold/purple identity so a
// hunter's own screen reads consistently with the rest of the app.)
const Color _kProGoldDeep = Color(0xFFB8900A);
const Color _kProGold = Color(0xFFFFD700);
const Color _kProGoldBright = Color(0xFFFFB300);
const Color _kMaxDeep = Color(0xFF6D28D9);
const Color _kMaxPurple = Color(0xFF8B5CF6);
const Color _kMaxViolet = Color(0xFFC084FC);

/// Resolved premium visual treatment for a membership tier on the profile.
class _ProfileMembershipVisual {
  final bool isPremium;
  final bool isMax;
  final Gradient frameGradient; // avatar ring
  final Gradient chipGradient;  // membership chip fill
  final Color glow;             // ring / chip glow accent
  final Color chipTextColor;    // readable text on the chip fill

  const _ProfileMembershipVisual({
    required this.isPremium,
    required this.isMax,
    required this.frameGradient,
    required this.chipGradient,
    required this.glow,
    required this.chipTextColor,
  });
}

/// Resolves the [_ProfileMembershipVisual] for a membership string using the
/// canonical [MembershipTier.fromString] parser.
_ProfileMembershipVisual _profileMembershipVisual(String membership) {
  final tier = MembershipTier.fromString(membership);
  if (tier == MembershipTier.max) {
    return const _ProfileMembershipVisual(
      isPremium: true,
      isMax: true,
      frameGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kMaxDeep, _kMaxPurple, _kMaxViolet],
      ),
      chipGradient: LinearGradient(colors: [_kMaxDeep, _kMaxPurple]),
      glow: _kMaxViolet,
      chipTextColor: Colors.white,
    );
  }
  if (tier == MembershipTier.pro) {
    return const _ProfileMembershipVisual(
      isPremium: true,
      isMax: false,
      frameGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kProGoldDeep, _kProGold, _kProGoldBright],
      ),
      chipGradient: LinearGradient(colors: [_kProGoldBright, _kProGold]),
      glow: _kProGold,
      chipTextColor: Colors.black,
    );
  }
  // Basic — neutral (frame falls back to the caller's rank accent).
  return const _ProfileMembershipVisual(
    isPremium: false,
    isMax: false,
    frameGradient: LinearGradient(colors: [Colors.transparent, Colors.transparent]),
    chipGradient: LinearGradient(colors: [Colors.transparent, Colors.transparent]),
    glow: Colors.transparent,
    chipTextColor: Colors.white,
  );
}

/// Premium hero avatar with a membership frame + glow.
///
/// Basic hunters get a clean ring tinted with their rank accent. Pro hunters
/// get a static gold gradient frame with a soft gold glow. Max hunters get a
/// purple→violet frame with a slowly rotating sweep-gradient ring for a
/// living "luxury" feel. The animation is a single 6s controller, spun up
/// only for Max, and wrapped in a [RepaintBoundary] so nothing else repaints.
class _ProfileMembershipAvatar extends StatefulWidget {
  final String membership;
  final double radius;
  final double ringWidth;
  final Color basicAccent;
  final ImageProvider? image;
  final Widget? child;

  const _ProfileMembershipAvatar({
    required this.membership,
    required this.radius,
    required this.basicAccent,
    this.ringWidth = 3.5,
    this.image,
    this.child,
  });

  @override
  State<_ProfileMembershipAvatar> createState() => _ProfileMembershipAvatarState();
}

class _ProfileMembershipAvatarState extends State<_ProfileMembershipAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _rot;

  bool get _spins => _profileMembershipVisual(widget.membership).isMax;

  @override
  void initState() {
    super.initState();
    if (_spins) {
      _rot = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    }
  }

  @override
  void dispose() {
    _rot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _profileMembershipVisual(widget.membership);
    final Color glow = v.isPremium ? v.glow : widget.basicAccent;

    final inner = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: HunterTheme.background),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: HunterTheme.surface,
        backgroundImage: widget.image,
        child: widget.image == null ? widget.child : null,
      ),
    );

    Widget frame(Gradient gradient) => Container(
          padding: EdgeInsets.all(widget.ringWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: [
              BoxShadow(color: glow.withOpacity(0.45), blurRadius: 26, spreadRadius: 3),
              if (v.isMax) BoxShadow(color: _kMaxPurple.withOpacity(0.30), blurRadius: 40, spreadRadius: 2),
            ],
          ),
          child: inner,
        );

    if (_rot != null) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _rot!,
          builder: (context, _) => frame(SweepGradient(
            colors: const [_kMaxDeep, _kMaxPurple, _kMaxViolet, _kMaxPurple, _kMaxDeep],
            transform: GradientRotation(_rot!.value * 2 * math.pi),
          )),
        ),
      );
    }

    if (!v.isPremium) {
      // Basic: clean ring tinted with the rank accent.
      return frame(LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [widget.basicAccent, widget.basicAccent.withOpacity(0.55)],
      ));
    }
    return frame(v.frameGradient);
  }
}

/// Premium membership badge chip (Pro / Max). Gradient fill with a readable
/// icon + label. Returns an empty widget for Basic hunters.
Widget _membershipChip(String membership, {double fontSize = 11}) {
  final v = _profileMembershipVisual(membership);
  if (!v.isPremium) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(horizontal: fontSize * 0.85, vertical: fontSize * 0.32),
    decoration: BoxDecoration(
      gradient: v.chipGradient,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: v.glow.withOpacity(0.45), blurRadius: 8)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(v.isMax ? Icons.auto_awesome : Icons.workspace_premium, color: v.chipTextColor, size: fontSize + 3),
        SizedBox(width: fontSize * 0.32),
        Text(
          v.isMax ? 'MAX' : 'PRO',
          style: TextStyle(color: v.chipTextColor, fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ],
    ),
  );
}
