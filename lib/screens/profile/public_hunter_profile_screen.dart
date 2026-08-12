import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/leaderboard/compare_hunters_screen.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/equipped_badge_chip.dart';
import 'package:hunter_ascend/widgets/membership_badge.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:hunter_ascend/widgets/premium_avatar.dart';

/// Read-only profile of another hunter (viewed from rankings/duels).
///
/// The former `isRivalMode` flag has been removed. It existed only to render
/// "remove rival" actions that cleared a locally stored `rival_uid`, which was
/// never a valid source of truth for a relationship shared between two users.
/// Rivalries now live in `rivalries/{pairId}` and are presented by their own
/// dedicated screens, so this is once again a pure public-profile viewer.
class PublicHunterProfileScreen extends StatelessWidget {
  final String hunterUid;

  const PublicHunterProfileScreen({
    super.key,
    required this.hunterUid,
  });

  /// Resolves the effective membership string for a hunter document.
  /// A premium tier with an expired expiry is treated as Basic.
  /// Handles both `membershipType` and legacy `membership`.
  String _resolveEffectiveMembership(Map<String, dynamic> data) {
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
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .doc(hunterUid)
            .snapshots(),
        builder: (context, snapshot) {
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
                        colors: [MembershipTheme.current.accent.withOpacity(0.16), HunterTheme.cardColor],
                      ),
                      border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: CircularProgressIndicator(color: MembershipTheme.current.accent, strokeWidth: 2.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Loading hunter...',
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          // Guard: document no longer exists (e.g. rival account deleted).
          if (!snapshot.data!.exists) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_rounded, color: HunterTheme.textTertiary, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Hunter no longer exists',
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This account has been removed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Go Back', style: TextStyle(color: HunterTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final level    = (data['level'] ?? 1) as int;
          final xp       = (data['xp'] ?? 0) as int;
          final wins     = (data['duelWins'] ?? 0) as int;
          final losses   = (data['duelLosses'] ?? 0) as int;
          final name     = data['hunterName'] ?? 'Unknown Hunter';
          final streak   = (data['streak'] ?? 0) as int;
          final rank     = RankService.instance.letterForLevel(level);
          final rankTitle= RankService.instance.longTitleForLevel(level);
          final rankColor= RankService.instance.colorForLevel(level);
          final total    = wins + losses;
          final winRate  = total == 0 ? 0 : ((wins * 100) / total).round();

          // Resolve the effective membership tier using the same logic as
          // MembershipService — a premium tier is only active when expiry
          // is non-null and in the future. Handles both new `membershipType`
          // and legacy `membership` field.
          final effectiveMembership = _resolveEffectiveMembership(data);

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Background glow
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.2,
                          colors: [
                            rankColor.withOpacity(0.12),
                            HunterTheme.background,
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Back button
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: HunterTheme.cardColor,
                                      border: Border.all(color: HunterTheme.border),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Icon(Icons.arrow_back_ios_new_rounded,
                                        color: HunterTheme.textSecondary, size: 15),
                                  ),
                                ),
                                const Spacer(),
                                // Rank pill top right
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: rankColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: rankColor.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    rankTitle,
                                    style: TextStyle(
                                      color: rankColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Avatar + rank badge
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer glow ring
                                Container(
                                  width: 116, height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: rankColor.withOpacity(0.4),
                                        blurRadius: 30,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                    border: Border.all(
                                        color: rankColor, width: 2.5),
                                  ),
                                ),
          PremiumAvatar(
          membership: effectiveMembership,
          radius: 50,
          image: data['profilePicture'] != null
          ? MemoryImage(
          base64Decode(data['profilePicture']),
          )
              : null,
          child: data['profilePicture'] == null
          ? const Icon(
          Icons.person,
          size: 50,
          )
              : null,
          ),
                                // Rank letter badge bottom-right
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      color: HunterTheme.background,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: rankColor, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: rankColor.withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        rank,
                                        style: TextStyle(
                                          color: rankColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Name
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Flexible(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: HunterTheme.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                EquippedBadgeChip(badgeId: data['equippedBadgeId']?.toString(), size: 18),

                                const SizedBox(width: 6),

                                MembershipBadge(
                                  membership: effectiveMembership,
                                  fontSize: 9,
                                ),

                              ],
                            ),

                            const SizedBox(height: 10),
                            Text(
                              "${effectiveMembership.toUpperCase()} HUNTER",
                              style: TextStyle(
                                color: MembershipTheme.current.accent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 11,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Level · Streak row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _infoPill(
                                    Icons.bolt, 'LV.$level', MembershipTheme.current.accent),
                                const SizedBox(width: 10),
                                _infoPill(Icons.local_fire_department,
                                    '$streak DAY STREAK', HunterTheme.gold),
                                const SizedBox(width: 10),
                                _infoPill(Icons.star,
                                    '$xp XP', HunterTheme.success),
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

              // ── Stats Section ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // Section label
                      _sectionLabel('DUEL RECORD'),
                      const SizedBox(height: 12),

                      // Win / Loss / Rate row
                      Row(
                        children: [
                          Expanded(child: _duelStatCard(
                              '$wins', 'WINS', HunterTheme.success)),
                          const SizedBox(width: 10),
                          Expanded(child: _duelStatCard(
                              '$losses', 'LOSSES', HunterTheme.danger)),
                          const SizedBox(width: 10),
                          Expanded(child: _duelStatCard(
                              '$winRate%', 'WIN RATE', HunterTheme.gold)),
                        ],
                      ),

                      const SizedBox(height: 24),
                      _sectionLabel('HUNTER INFO'),
                      const SizedBox(height: 12),

                      // Info tiles
                      _infoRow(Icons.bolt, 'Level', 'LV.$level',
                          MembershipTheme.current.accent),
                      _infoRow(Icons.emoji_events, 'Total XP', '$xp XP',
                          HunterTheme.success),
                      _infoRow(Icons.local_fire_department, 'Streak',
                          '$streak Days', HunterTheme.gold),
                      _infoRow(Icons.sports_kabaddi, 'Total Duels',
                          '$total', MembershipTheme.current.accent),

                      const SizedBox(height: 28),

                      // ── Action Buttons ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MembershipTheme.current.accent,
                            foregroundColor: MembershipTheme.isMax ? Colors.white : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: MembershipTheme.current.accent.withOpacity(0.4),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompareHuntersScreen(
                                  hunterUid: hunterUid,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.compare_arrows_rounded, size: 20),
                          label: const Text(
                            'COMPARE HUNTERS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HunterTheme.danger.withOpacity(0.12),
                            foregroundColor: HunterTheme.danger,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: HunterTheme.danger.withOpacity(0.5), width: 1.5),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateDuelScreen(
                                  hunterName: data['hunterName'],
                                  pushed: true,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.sports_kabaddi_rounded, size: 20),
                          label: const Text(
                            'CHALLENGE HUNTER',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────

  Widget _infoPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(
              color: MembershipTheme.current.accent,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(text,
          style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _duelStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.14), HunterTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10 * HunterTheme.glowStrength),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        Text(value,
            style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}