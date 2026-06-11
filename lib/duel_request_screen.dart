import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DuelRequestScreen extends StatefulWidget {
  const DuelRequestScreen({super.key});

  @override
  State<DuelRequestScreen> createState() => _DuelRequestScreenState();
}

class _DuelRequestScreenState extends State<DuelRequestScreen> {

  static const _bg      = Color(0xFF070B14);
  static const _card    = Color(0xFF0D1120);
  static const _blue    = Color(0xFF4D7CFF);
  static const _blueDim = Color(0xFF1A2A4A);
  static const _border  = Color(0xFF1E2D4A);

  BannerAd? bannerAd;
  bool isBannerReady = false;

  @override
  void initState() {
    super.initState();
    loadBannerAd();
  }

  void loadBannerAd() {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5435480116436845/4699186117',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => isBannerReady = true),
      ),
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: "INCOMING ",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
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
            return const Center(child: CircularProgressIndicator(color: _blue));
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
                    child: const Icon(Icons.sports_kabaddi, color: _blue, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "NO PENDING CHALLENGES",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You have no incoming duel requests",
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final duel     = snapshot.data!.docs.first;
          final duelData = duel.data() as Map<String, dynamic>;
          final quests   = duelData['duelQuests'] as List;

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
                          border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFF4444).withValues(alpha: 0.1), blurRadius: 24),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: const Icon(Icons.sports_kabaddi, color: Color(0xFFFF4444), size: 44),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "⚔️  DUEL REQUEST",
                              style: TextStyle(
                                color: Color(0xFFFF4444),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "A hunter has challenged you to battle.\nAccept to begin the 6-day duel.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
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
                                const Icon(Icons.timer_outlined, color: _blue, size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  "6 DAY DUEL",
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
                        const Text(
                          "Shared Missions",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _blueDim, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            "${quests.length}",
                            style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.bold),
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
                                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.gps_fixed, color: Color(0xFFFF4444), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                quest['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
                                style: const TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.bold),
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
                decoration: const BoxDecoration(
                  color: Color(0xFF080C18),
                  border: Border(top: BorderSide(color: _border, width: 1)),
                ),
                child: Column(
                  children: [
                    Row(children: [

                      // DECLINE
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            await duel.reference.update({'status': 'declined'});
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4444).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: 0.4), width: 1.2),
                            ),
                            child: const Center(
                              child: Text(
                                "DECLINE",
                                style: TextStyle(
                                  color: Color(0xFFFF4444),
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
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;
                            await FirebaseFirestore.instance.collection('duels').add({
                              'participants':            [duelData['fromUid'], user.uid],
                              'player1':                 duelData['fromUid'],
                              'player2':                 user.uid,
                              'player1Score':            0,
                              'player2Score':            0,
                              'player1CompletedToday':   [],
                              'player2CompletedToday':   [],
                              'status':                  'active',
                              'winner':                  '',
                              'cancelRequestedBy':       '',
                              'cancelStatus':            '',
                              'player1ViewedResult':     false,
                              'player2ViewedResult':     false,
                              'durationDays':            6,
                              'startDate':               Timestamp.now(),
                              'duelQuests':              duelData['duelQuests'],
                              'createdAt':               Timestamp.now(),
                            });
                            await duel.reference.update({'status': 'accepted'});
                            if (context.mounted) Navigator.pop(context);
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
                            child: const Center(
                              child: Text(
                                "ACCEPT",
                                style: TextStyle(
                                  color: Colors.white,
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