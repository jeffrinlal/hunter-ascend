import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Read-only list of the hunter's past duels and their outcomes.
class DuelHistoryScreen extends StatefulWidget {
  const DuelHistoryScreen({super.key});

  @override
  State<DuelHistoryScreen> createState() => _DuelHistoryScreenState();
}

class _DuelHistoryScreenState extends State<DuelHistoryScreen> {
  // Hoisted into State so the identical query runs ONCE per screen open.
  // It previously lived inline in the FutureBuilder below, which meant every
  // rebuild built a new Future and re-issued the same 20-document read — and
  // this screen rebuilds on every theme / active-theme / membership-tier
  // notifier tick via the ListenableBuilder in build(). Stabilising the
  // Future's identity is the only change: the collection, filter, ordering
  // and limit are byte-for-byte the same, and the one-read-per-open behaviour
  // (including the existing loading and error states) is unchanged.
  late final Future<QuerySnapshot> _historyFuture = FirebaseFirestore.instance
      .collection('duels')
      .where('participants',
          arrayContains: FirebaseAuth.instance.currentUser?.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .get();

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
    final user = FirebaseAuth.instance.currentUser;

    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: "DUEL ",
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            TextSpan(
              text: "HISTORY",
              style: TextStyle(
                color: MembershipTheme.current.accent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ]),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: HunterTheme.border),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _historyFuture,
        builder: (context, snapshot) {
          // ── Error state ──
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: HunterTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load duel history',
                      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunterTheme.textTertiary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── Loading state ──
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: MembershipTheme.current.accent),
            );
          }

          final myDuels = snapshot.data!.docs;

          // ── Summary counts ──
          int wins = 0, losses = 0, cancelled = 0;
          for (final doc in myDuels) {
            final duel = doc.data() as Map<String, dynamic>;
            if (duel['status'] == 'completed') {
              if (duel['winner'] == user?.uid) wins++;
              else losses++;
            } else {
              cancelled++;
            }
          }

          if (myDuels.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MembershipTheme.current.accent.withOpacity(0.16),
                            HunterTheme.cardColor,
                          ],
                        ),
                        border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.3), width: 1.4),
                        boxShadow: [
                          BoxShadow(color: MembershipTheme.current.accent.withOpacity(0.14 * HunterTheme.glowStrength), blurRadius: 24),
                        ],
                      ),
                      child: Icon(Icons.sports_kabaddi_rounded, color: MembershipTheme.current.accent, size: 42),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "NO DUEL HISTORY",
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Challenge a hunter to begin your rivalry",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Stats row ──
                Row(children: [
                  _buildStatCard("WINS",      "$wins",      HunterTheme.success, Icons.emoji_events),
                  const SizedBox(width: 10),
                  _buildStatCard("LOSSES",    "$losses",    HunterTheme.danger, Icons.sports_kabaddi),
                  const SizedBox(width: 10),
                  _buildStatCard("CANCELLED", "$cancelled", HunterTheme.textTertiary,          Icons.cancel_outlined),
                ]),

                const SizedBox(height: 24),

                // ── Section label ──
                Row(children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: MembershipTheme.current.gradient,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Recent Duels",
                    style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MembershipTheme.current.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      "${myDuels.length}",
                      style: TextStyle(color: MembershipTheme.current.accent, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),

                const SizedBox(height: 14),

                // ── Duel tiles ──
                ...myDuels.map((doc) {
                  final duel = doc.data() as Map<String, dynamic>;

                  String label;
                  Color accentColor;
                  IconData iconData;
                  Color iconBg;

                  if (duel['status'] == 'completed') {
                    if (duel['winner'] == user?.uid) {
                      label      = "VICTORY";
                      accentColor = HunterTheme.success;
                      iconData   = Icons.emoji_events;
                      iconBg     = HunterTheme.success.withOpacity(0.12);
                    } else {
                      label      = "DEFEATED";
                      accentColor = HunterTheme.danger;
                      iconData   = Icons.whatshot;
                      iconBg     = HunterTheme.danger.withOpacity(0.12);
                    }
                  } else {
                    label      = "CANCELLED";
                    accentColor = HunterTheme.textTertiary;
                    iconData   = Icons.cancel_outlined;
                    iconBg     = HunterTheme.textPrimary.withOpacity(0.05);
                  }

                  // Optional: show opponent name if available
                  final bool isPlayer1 = duel['player1'] == user?.uid;
                  final String opponentName = isPlayer1
                      ? (duel['player2Name'] ?? 'Unknown')
                      : (duel['player1Name'] ?? 'Unknown');

                  // Format date
                  String dateStr = "";
                  if (duel['createdAt'] != null) {
                    final ts = (duel['createdAt'] as Timestamp).toDate();
                    dateStr = "${ts.day}/${ts.month}/${ts.year}";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [accentColor.withOpacity(0.10), HunterTheme.cardColor],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: accentColor.withOpacity(
                          duel['status'] == 'completed' ? 0.35 : 0.18,
                        ),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(HunterTheme.isDark ? 0.18 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(children: [
                        // Timeline accent rail
                        Container(
                          width: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [accentColor, accentColor.withOpacity(0.35)],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              bottomLeft: Radius.circular(18),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              // Outcome medallion
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: accentColor.withOpacity(0.25)),
                                ),
                                child: Icon(iconData, color: accentColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              // Info
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  if (opponentName.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      "vs $opponentName",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ]),
                              ),
                              // Date + badge
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                if (dateStr.isNotEmpty)
                                  Text(
                                    dateStr,
                                    style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accentColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    duel['status'] == 'completed' ? "COMPLETED" : "CANCELLED",
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ]),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.12), HunterTheme.cardColor],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10 * HunterTheme.glowStrength),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}