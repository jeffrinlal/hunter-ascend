import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/services/ads_service.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/screens/duel/duel_screen.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Shows an incoming duel challenge so the hunter can accept or decline.
class DuelRequestScreen extends StatefulWidget {
  const DuelRequestScreen({super.key});

  @override
  State<DuelRequestScreen> createState() => _DuelRequestScreenState();
}

class _DuelRequestScreenState extends State<DuelRequestScreen> {

  static Color get _bg => HunterTheme.background;
  static Color get _card => HunterTheme.cardColor;
  static Color get _blue => HunterTheme.primary;
  static Color get _blueDim => HunterTheme.border;
  static Color get _border => HunterTheme.border;
  BannerAd? bannerAd;
  bool isBannerReady = false;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    loadBannerAd();
  }

  void loadBannerAd() {
    // Max tier hides banner ads entirely — skip the load so nothing is
    // requested or rendered for those hunters.
    if (!MembershipService.instance.showBannerAds) return;

    bannerAd = AdsService.createBannerAd(
      adUnitId: AppConstants.challengeBannerAdUnitId,
      onAdLoaded: (ad) { if (mounted) setState(() => isBannerReady = true); },
      onAdFailedToLoad: (ad, error) { ad.dispose(); },
    );
    bannerAd!.load();
  }

  @override
  void dispose() {
    bannerAd?.dispose();
    super.dispose();
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
              text: "INCOMING ",
              style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            TextSpan(
              text: "CHALLENGE",
              style: TextStyle(color: _blue, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ]),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('duel_requests')
            .where('toUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: _blue));
          }

          // ── Empty state ──
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _blueDim,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border, width: 1.5),
                    ),
                    child: Icon(Icons.sports_kabaddi, color: _blue, size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "NO PENDING CHALLENGES",
                    style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You have no incoming duel requests",
                    style: TextStyle(color: HunterTheme.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final duel      = snapshot.data!.docs.first;
          final duelData  = duel.data() as Map<String, dynamic>;
          final quests    = duelData['duelQuests'] as List;
          final int days  = duelData['durationDays'] ?? 6;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),

                      // ── Challenge hero banner ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: HunterTheme.danger.withValues(alpha: 0.1), blurRadius: 24),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: HunterTheme.danger.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: Icon(Icons.sports_kabaddi, color: HunterTheme.danger, size: 44),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "⚔️  DUEL REQUEST",
                              style: TextStyle(
                                color: HunterTheme.danger,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${duelData['fromHunterName']} has challenged you to battle.\nAccept to begin the $days-day duel.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _blueDim,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _border),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.timer_outlined, color: _blue, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "$days DAY DUEL",
                                  style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Shared missions header ──
                      Row(children: [
                        Text(
                          "Shared Missions",
                          style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            "${quests.length}",
                            style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      // ── Quest tiles ──
                      ...List.generate(quests.length, (index) {
                        final quest = quests[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border, width: 1.2),
                          ),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: HunterTheme.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.gps_fixed, color: HunterTheme.danger, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                quest['name'],
                                style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _blueDim,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+${quest['xp'] ?? '?'} XP",
                                style: TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]),
                        );
                      }),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Action buttons + banner ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                decoration: BoxDecoration(
                  color: HunterTheme.background,
                  border: Border(top: BorderSide(color: _border, width: 1)),
                ),
                child: Column(
                  children: [
                    Row(children: [

                      // DECLINE
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            if (_isResponding) return;
                            if (!await ConnectivityService.isOnline()) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
                              return;
                            }
                            _isResponding = true;
                            try {
                              await duel.reference.update({'status': 'declined'});
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              debugPrint("declineDuel: $e");
                            } finally {
                              _isResponding = false;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: HunterTheme.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: HunterTheme.danger.withValues(alpha: 0.4), width: 1.2),
                            ),
                            child: Center(
                              child: Text(
                                "DECLINE",
                                style: TextStyle(
                                  color: HunterTheme.danger,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ACCEPT
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            if (_isResponding) return;
                            if (!await ConnectivityService.isOnline()) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
                              return;
                            }
                            _isResponding = true;
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user == null) return;
                              final newDuelRef = await FirebaseFirestore.instance.collection('duels').add({
                                'player1': duelData['fromUid'],
                                'player2': user.uid,
                                'participants':          [duelData['fromUid'], user.uid],
                                'player1Name': duelData['fromHunterName'] ?? '',
                                'player2Name': duelData['toHunterName'] ?? '',
                                'player1Score':          0,
                                'player2Score':          0,
                                'player1CompletedToday': [],
                                'player2CompletedToday': [],
                                'status':                'active',
                                'winner':                '',
                                'cancelRequestedBy':     '',
                                'cancelStatus':          '',
                                'player1ViewedResult':   false,
                                'player2ViewedResult':   false,
                                'durationDays':          duelData['durationDays'] ?? 6,
                                'startDate':             Timestamp.now(),
                                'duelQuests':            duelData['duelQuests'],
                                'createdAt':             Timestamp.now(),
                              });
                              await duel.reference.update({'status': 'accepted'});
                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DuelScreen(duelId: newDuelRef.id),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint("acceptDuel: $e");
                            } finally {
                              _isResponding = false;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _blue,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: _blue.withValues(alpha: 0.3), blurRadius: 12),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "ACCEPT",
                                style: TextStyle(
                                  color: HunterTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    ]),

                    if (isBannerReady) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: bannerAd!.size.width.toDouble(),
                          height: bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: bannerAd!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}