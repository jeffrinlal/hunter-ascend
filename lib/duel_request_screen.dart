import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class DuelRequestScreen extends StatefulWidget {
  const DuelRequestScreen({super.key});

  @override
  State<DuelRequestScreen> createState() =>
      _DuelRequestScreenState();
}

class _DuelRequestScreenState
    extends State<DuelRequestScreen> {
  BannerAd? bannerAd;
  bool isBannerReady = false;
  void loadBannerAd() {

    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5435480116436845/4699186117',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            isBannerReady = true;
          });
        },
      ),
    );

    bannerAd!.load();
  }

  @override
  void initState() {
    super.initState();
    loadBannerAd();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Incoming Challenge"),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('duel_requests')
            .where(
          'toUid',
          isEqualTo:
          FirebaseAuth.instance.currentUser?.uid,
        )
            .where(
          'status',
          isEqualTo: 'pending',
        )
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No pending challenges",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            );
          }

          final duel =
              snapshot.data!.docs.first;

          final duelData =
          duel.data() as Map<String, dynamic>;

          final quests =
          duelData['duelQuests'] as List;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 20),

                const Center(
                  child: Icon(
                    Icons.sports_kabaddi,
                    color: Colors.redAccent,
                    size: 80,
                  ),
                ),

                const SizedBox(height: 20),

                const Center(
                  child: Text(
                    "INCOMING CHALLENGE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "Shared Missions",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                Expanded(
                  child: ListView.builder(
                    itemCount: quests.length,
                    itemBuilder: (context, index) {

                      final quest = quests[index];

                      return Card(
                        color: Colors.grey[900],
                        child: ListTile(
                          leading: const Icon(
                            Icons.gps_fixed,
                            color: Colors.redAccent,
                          ),
                          title: Text(
                            quest['name'],
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {

                          await duel.reference.update({
                            'status': 'declined',
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text(
                          "DECLINE",
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {

                          final user =
                              FirebaseAuth.instance.currentUser;

                          if (user == null) return;

                          await FirebaseFirestore.instance
                              .collection('duels')
                              .add({
                            'participants': [
                              duelData['fromUid'],
                              user.uid,
                            ],

                            'player1': duelData['fromUid'],
                            'player2': user.uid,

                            'player1Score': 0,
                            'player2Score': 0,

                            'player1CompletedToday': [],
                            'player2CompletedToday': [],

                            'status': 'active',

                            'winner': '',

                            'cancelRequestedBy': '',
                            'cancelStatus': '',

                            'player1ViewedResult': false,
                            'player2ViewedResult': false,

                            'durationDays': 6,

                            'startDate': Timestamp.now(),

                            'duelQuests':
                            duelData['duelQuests'],

                            'createdAt': Timestamp.now(),
                          });

                          await duel.reference.update({
                            'status': 'accepted',
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text(
                          "ACCEPT",
                        ),
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 20),

                if (isBannerReady)
                  Center(
                    child: SizedBox(
                      width: bannerAd!.size.width.toDouble(),
                      height: bannerAd!.size.height.toDouble(),
                      child: AdWidget(
                        ad: bannerAd!,
                      ),
                    ),
                  ),

              ],
            ),
          );
        },
      ),
    );
  }
  @override
  void dispose() {
    bannerAd?.dispose();
    super.dispose();
  }
}