import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'global_rankings_screen.dart';
import 'profile_screen.dart';
import 'duel_screen.dart';
import 'settings_screen.dart';
import 'create_duel_screen.dart';
import 'duel_request_screen.dart';
import 'package:health/health.dart';

class DashboardScreen extends StatefulWidget {

  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;


  const DashboardScreen({
    super.key,
    required this.fatLoss,
    required this.discipline,
    required this.muscleGain,
    required this.selfImprovement,
  });
  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();

}

class _DashboardScreenState

    extends State<DashboardScreen> {




  String getStreakTitle(int streak) {
    if (streak >= 100) return "👑 Shadow Monarch";
    if (streak >= 60) return "⚔️ S-Rank Hunter";
    if (streak >= 30) return "🏅 Elite Hunter";
    if (streak >= 14) return "🎯 Dedicated Hunter";
    if (streak >= 7) return "🔥 Consistent Hunter";
    if (streak >= 1) return "🛡️ New Hunter";
    return "";
  }
  int xp = 0;
  int level = 1;
  final Health health = Health();

  int todaySteps = 0;
    // StreamSubscription? duelSubscription;
    // bool duelDialogShowing = false;
  BannerAd? bannerAd;
  bool isBannerReady = false;
  RewardedAd? rewardedAd;
  bool isRewardedAdReady = false;
  RewardedAd? punishmentAd;
  bool isPunishmentAdReady = false;
  int selectedCustomQuestXp = 10;
  final TextEditingController customQuestController =
  TextEditingController();

  String get hunterRank {
    if (level >= 30) return "S RANK";
    if (level >= 20) return "A RANK";
    if (level >= 15) return "B RANK";
    if (level >= 10) return "C RANK";
    if (level >= 5) return "D RANK";
    return "E RANK";
  }

  int strength = 10;
  int agility = 10;
  int intelligence = 10;
  int vitality = 10;

  bool questStarted = false;

  String activeQuest = "";
  int questReward = 0;
  List<Map<String, dynamic>> generatedQuests = [];
  List<String> completedQuests = [];

  void loadBannerAd() {

    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5435480116436845/4995463929',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print("BANNER LOADED");

          setState(() {
            isBannerReady = true;
          });
        },

        onAdFailedToLoad: (ad, error) {
          print("BANNER FAILED: $error");
          ad.dispose();
        },
      ),
    );

    bannerAd!.load();
  }

  void loadRewardedAd() {

    RewardedAd.load(
      adUnitId:
      'ca-app-pub-5435480116436845/4406856317',
      request: const AdRequest(),
      rewardedAdLoadCallback:
      RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          rewardedAd = ad;

          setState(() {
            isRewardedAdReady = true;
          });

          print("REWARDED LOADED");
        },

        onAdFailedToLoad: (error) {

          print(
            "REWARDED FAILED: $error",
          );

          isRewardedAdReady = false;
        },
      ),
    );
  }
  void loadPunishmentAd() {

    RewardedAd.load(
      adUnitId:
      'ca-app-pub-5435480116436845/7002658082',

      request: const AdRequest(),

      rewardedAdLoadCallback:
      RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          punishmentAd = ad;

          setState(() {
            isPunishmentAdReady = true;
          });

          print("PUNISHMENT AD LOADED");
        },

        onAdFailedToLoad: (error) {

          print(
            "PUNISHMENT AD FAILED: $error",
          );

          isPunishmentAdReady = false;
        },
      ),
    );
  }
  void showStreakRecoveryAd() {

    if (!isRewardedAdReady ||
        rewardedAd == null) {
      return;
    }

    rewardedAd!.show(

      onUserEarnedReward:
          (ad, reward) async {

        final user =
            FirebaseAuth.instance.currentUser;

        if (user == null) return;

        final doc =
        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .get();


        final data =
        doc.data() as Map<String, dynamic>;

        final previousStreak =
            data['previousStreak'] ?? 0;

        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .update({


          'streak': previousStreak,
          'previousStreak': 0,

          'lastRecoveryDate':
          Timestamp.now(),



        });

        if (mounted) {

          ScaffoldMessenger.of(context)
              .showSnackBar(

            SnackBar(
              content: Text(
                "🔥 Streak Restored ($previousStreak Days)",
              ),
            ),
          );
        }
      },
    );

    rewardedAd = null;
    isRewardedAdReady = false;

    loadRewardedAd();
  }

  Future<void> loadSteps() async {

    bool granted = await health.requestAuthorization(
      [HealthDataType.STEPS],
      permissions: [
        HealthDataAccess.READ,
      ],
    );

    print("STEP PERMISSION: $granted");


    if (!granted) return;

    final now = DateTime.now();

    final midnight = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final steps =
    await health.getTotalStepsInInterval(
      midnight,
      now,
    );
    print("CURRENT STEPS: $steps");
    final user =
        FirebaseAuth.instance.currentUser;

    if (user != null && (steps ?? 0) >= 10000) {

      final hunterDoc =
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .get();

      final data =
          hunterDoc.data() ?? {};

      final today =
      DateTime.now()
          .toString()
          .substring(0, 10);

      if (data['lastStepRewardDate'] != today) {

        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .update({

          'xp': (data['xp'] ?? 0) + 25,
          'lastStepRewardDate': today,

        });

        ScaffoldMessenger.of(context)
            .showSnackBar(

          const SnackBar(
            content: Text(
              "🏆 Daily Step Goal Complete! +25 XP",
            ),
          ),
        );
      }
    }

    setState(() {
      todaySteps = steps ?? 0;
    });
  }
  Future<void> checkBrokenStreak() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data =
    doc.data() as Map<String, dynamic>;
    final lastRecoveryDate =
    data['lastRecoveryDate'];

    if (lastRecoveryDate != null) {

      final recoveryDate =
      (lastRecoveryDate as Timestamp)
          .toDate();

      final daysSinceRecovery =
          DateTime.now()
              .difference(recoveryDate)
              .inDays;

      if (daysSinceRecovery < 3) {
        return;
      }
    }

    final streak =
        data['streak'] ?? 0;

    final lastQuestDate =
        data['lastQuestDate'] ?? '';

    if (streak == 0 ||
        lastQuestDate.isEmpty) {
      return;
    }

    final parts =
    lastQuestDate.split('-');

    final lastDate = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    final difference =
        DateTime.now()
            .difference(lastDate)
            .inDays;

    if (difference <= 1) {
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          "🔥 STREAK BROKEN",
        ),
        content: Text(
          "Previous Streak: $streak Days\n\nWatch an ad to restore it?",
        ),
        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "ACCEPT LOSS",
            ),
          ),

          ElevatedButton(
            onPressed: () {

              Navigator.pop(context);

              showStreakRecoveryAd();
            },
            child: const Text(
              "WATCH AD",
            ),
          ),

        ],
      ),
    );
  }
  Future<void> checkDisciplinePunishment() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final today =
    DateTime.now()
        .toString()
        .substring(0, 10);

    if (data['lastPunishmentDate'] == today) {
      return;
    }

    final mode =
        data['disciplineMode'] ?? 'casual';


    final lastReset =
    data['lastQuestResetDate'];

    if (lastReset == null ||
        lastReset.toString().isEmpty) {
      return;
    }

    final completed =
        data['yesterdayCompletedCount'] ?? 0;

    final total =
        data['yesterdayTotalQuests'] ?? 0;

    bool punish = false;

    if (mode == 'casual') {
      punish = completed == 0;
    } else {
      punish = completed < total;
    }

    if (!punish) return;


    if (isPunishmentAdReady &&
        punishmentAd != null) {



      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AlertDialog(
              title: const Text(
                "⚠️ DISCIPLINE FAILURE",
              ),
              content: const Text(
                "You failed yesterday's mission.\n\nWatch an ad to repay your debt.",
              ),
              actions: [

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    punishmentAd!.show(
                      onUserEarnedReward:
                          (ad, reward) async {

                        await FirebaseFirestore.instance
                            .collection('hunters')
                            .doc(user.uid)
                            .update({

                          'lastPunishmentDate': today,

                        });

                      },
                    );

                    punishmentAd = null;
                    isPunishmentAdReady = false;

                    loadPunishmentAd();
                  },
                  child: const Text(
                    "WATCH AD",
                  ),
                ),

              ],
            ),
      );
    }

    // XP LOSS CODE HERE
    else {
      int currentXp =
          data['xp'] ?? 0;

      int penalty =
      mode == 'strict'
          ? 100
          : 25;

      currentXp -= penalty;

      if (currentXp < 0) {
        currentXp = 0;
      }

      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .update({

        'xp': currentXp,
        'lastPunishmentDate': today,

      });

      await loadHunterData();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            AlertDialog(
              title: const Text(
                "⚠️ DISCIPLINE FAILURE",
              ),
              content: Text(
                "No ad available.\n\n-$penalty XP",
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("ACCEPT"),
                ),
              ],
            ),
      );
    }
  }
  Future<void> checkDisciplineMode() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final mode = data['disciplineMode'];

    if (mode != null &&
        mode.toString().isNotEmpty) {
      return;
    }

    if (!mounted) return;

    Future.delayed(
      const Duration(milliseconds: 500),
          () {

        showDisciplineModeDialog();

      },
    );
  }


  @override
  void initState() {
    super.initState();

    loadBannerAd();
    loadRewardedAd();
    loadPunishmentAd();
    loadSteps();


    WidgetsBinding.instance
        .addPostFrameCallback((_) {

      checkBrokenStreak();
      checkDisciplinePunishment();


    });



    if (widget.fatLoss) {
      generatedQuests.addAll([
        {
          "name": "Walk 2000 Steps",
          "xp": 20,
          "icon": Icons.directions_walk,
        },
        {
          "name": "Drink 3L Water",
          "xp": 50,
          "icon": Icons.water_drop,
        },
        {
          "name": "Eat 120g Protein",
          "xp": 100,
          "icon": Icons.restaurant,
        },
        {
          "name": "No Junk Food Today",
          "xp": 50,
          "icon": Icons.no_food,
        },
      ]);
    }

    if (widget.discipline) {
      generatedQuests.addAll([
        {
          "name": "No Porn Today",
          "xp": 100,
          "icon": Icons.shield,
        },
        {
          "name": "No Masturbation Today",
          "xp": 100,
          "icon": Icons.self_improvement,
        },
        {
          "name": "Screen Time Under 4 Hours",
          "xp": 75,
          "icon": Icons.phone_android,
        },
      ]);
    }

    if (widget.muscleGain) {
      generatedQuests.addAll([
        {
          "name": "Workout 60 Minutes",
          "xp": 150,
          "icon": Icons.fitness_center,
        },
        {
          "name": "Eat 120g Protein",
          "xp": 100,
          "icon": Icons.restaurant,
        },
        {
          "name": "Sleep 8 Hours",
          "xp": 50,
          "icon": Icons.bed,
        },
      ]);
    }

    if (widget.selfImprovement) {
      generatedQuests.addAll([
        {
          "name": "Read 20 Minutes",
          "xp": 30,
          "icon": Icons.menu_book,
        },
        {
          "name": "Learn Coding 30 Minutes",
          "xp": 75,
          "icon": Icons.code,
        },
        {
          "name": "Meditation 10 Minutes",
          "xp": 25,
          "icon": Icons.self_improvement,
        },
      ]);
    }
    loadHunterData();
  }


  void startQuest(String questName, int reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "QUEST START",
          style: TextStyle(color: Colors.cyan),
        ),
        content: Text(
          "Start $questName ?",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              setState(() {
                questStarted = true;
                activeQuest = questName;
                questReward = reward;
              });
            },
            child: const Text("START"),
          ),
        ],
      ),
    );

  }
  Future<void> updateStreak() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    final data =
    doc.data() as Map<String, dynamic>;

    int streak = data['streak'] ?? 0;

    String lastQuestDate =
        data['lastQuestDate'] ?? '';

    final today = DateTime.now();

    final todayString =
        "${today.year}-${today.month}-${today.day}";

    if (lastQuestDate.isEmpty) {

      streak = 1;

    } else {

      final parts =
      lastQuestDate.split('-');

      final lastDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      final difference =
          today.difference(lastDate).inDays;

      if (difference == 0) {

        return;

      } else if (difference == 1) {

        streak++;

      } else {

        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .update({

          'previousStreak': streak,

        });

        streak = 1;

      }
    }

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .update({

      'streak': streak,
      'lastQuestDate': todayString,

    });
  }

  Future<void> completeQuest() async {
    bool leveledUp = false;

    setState(() {
      xp += questReward;
      questStarted = false;
      completedQuests.add(activeQuest);

      if (xp >= 500) {
        level++;
        xp = xp - 500;
        leveledUp = true;
      }
    });

    await updateHunterOnline();
    await updateStreak();
    await saveCompletedQuest(activeQuest);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
content: StatefulBuilder(
builder: (context, setDialogState) {
return Column(
mainAxisSize: MainAxisSize.min,
children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.amber,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              "QUEST COMPLETE",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "+$questReward XP",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
],
);
},
),
      ),
    );

    Future.delayed(
      const Duration(seconds: 1),
          () {
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
    );
    if (leveledUp) {

showDialog(
context: context,
barrierDismissible: false,
builder: (_) => Scaffold(
backgroundColor: Colors.black,
body: Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [

const Icon(
Icons.bolt,
color: Colors.cyanAccent,
size: 140,
),

const SizedBox(height: 30),

const Text(
"LEVEL UP",
style: TextStyle(
color: Colors.cyanAccent,
fontSize: 40,
fontWeight: FontWeight.bold,
letterSpacing: 4,
),
),

const SizedBox(height: 20),

Text(
"LEVEL $level",
style: const TextStyle(
color: Colors.white,
fontSize: 28,
),
),
],
),
),
),
);

Future.delayed(
const Duration(seconds: 2),
() {
if (context.mounted) {
Navigator.pop(context);
}
},
);
}
}
  Future<void> loadHunterData() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    setState(() {

      xp = data['xp'] ?? 0;

      level = data['level'] ?? 1;

      completedQuests =
      List<String>.from(
        data['completedQuests'] ?? [],
      );

    });
    await checkDailyReset();
    await checkDisciplineMode();
  }
  Future<void> checkDailyReset() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final today =
    DateTime.now()
        .toString()
        .substring(0, 10);

    final lastReset =
        data['lastQuestResetDate'] ?? '';

    if (lastReset == today) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .update({

      'yesterdayCompletedCount':
      completedQuests.length,

      'yesterdayTotalQuests':
      generatedQuests.length +
          (await FirebaseFirestore.instance
              .collection('custom_quests')
              .where(
            'uid',
            isEqualTo: user.uid,
          )
              .get())
              .docs
              .length,

      'completedQuests': [],

      'lastQuestResetDate': today,

    });

    setState(() {
      completedQuests.clear();
    });
  }

  Future<void> updateHunterOnline() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .update({
      'level': level,
      'xp': xp,
    });
  }
  Future<void> saveCompletedQuest(
      String questName) async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .update({

      'completedQuests':
      FieldValue.arrayUnion(
        [questName],
      ),

    });
  }

  @override
  void dispose() {

    rewardedAd?.dispose();
    punishmentAd?.dispose();

    super.dispose();
  }
  Future<void> showDisciplineModeDialog() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc =
    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();

    final data = doc.data()!;

    final mode =
        data['disciplineMode'] ?? '';
    final changedAt =
    data['disciplineModeChangedAt']
    as Timestamp?;

bool locked = false;
int remainingDays = 0;

if (changedAt != null) {
      final daysPassed =
          DateTime
              .now()
              .difference(
            changedAt.toDate(),
          )
              .inDays;

      locked = daysPassed < 30;
      if (locked) {
        remainingDays = 30 - daysPassed;
      }
    }




    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(

        title: Text(
          "⚔️ Current Mode: ${mode.toUpperCase()}",
        ),

        content: Text(
          locked
              ? "🔒 Mode Locked\n\n$remainingDays Days Remaining"
              : "You can change your discipline mode.",
        ),

        actions: [

          TextButton(
            onPressed: locked
                ? null
                : () async {

              await FirebaseFirestore.instance
                  .collection('hunters')
                  .doc(user.uid)
                  .update({

                'disciplineMode': 'casual',
                'disciplineModeChangedAt':
                Timestamp.now(),

              });

              Navigator.pop(context);
            },
            child: const Text("CASUAL"),
          ),

          ElevatedButton(
            onPressed: locked
                ? null
                : () async {

              await FirebaseFirestore.instance
                  .collection('hunters')
                  .doc(user.uid)
                  .update({

                'disciplineMode': 'strict',
                'disciplineModeChangedAt':
                Timestamp.now(),

              });

              Navigator.pop(context);
            },
            child: const Text("STRICT"),
          ),

        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hunter Dashboard"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalRankingsScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: StreamBuilder<QuerySnapshot>(
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
                  .snapshots(),
              builder: (context, snapshot) {

                final hasPending =
                    snapshot.hasData &&
                        snapshot.data!.docs.isNotEmpty;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [

                    const Icon(
                      Icons.sports_kabaddi,
                    ),

                    if (hasPending)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ), // ⚔️ Duel
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;

              if (user == null) return;

              final stopwatch = Stopwatch()..start();

              final duelSnapshot = await FirebaseFirestore.instance
                  .collection('duels')
                  .where(
                'participants',
                arrayContains: user.uid,
              )
                  .limit(1)
                  .get();

              print(
                "DUEL QUERY TIME: ${stopwatch.elapsedMilliseconds} ms",
              );
              bool hasActiveDuel = false;
              String? duelId;

              if (duelSnapshot.docs.isNotEmpty) {

                final doc = duelSnapshot.docs.first;

                final data = doc.data();

                bool isPlayer1 =
                    data['player1'] == user.uid;

                bool shouldShowResult =
                    data['status'] == 'completed' &&
                        ((isPlayer1 &&
                            data['player1ViewedResult'] == false) ||
                            (!isPlayer1 &&
                                data['player2ViewedResult'] == false));

                if (data['status'] == 'active' ||
                    shouldShowResult) {

                  hasActiveDuel = true;
                  duelId = doc.id;
                }
              }
              if (hasActiveDuel) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DuelScreen(
                      duelId: duelId!,
                    ),
                  ),
                );
                return;
              }
              final pendingRequest = await FirebaseFirestore.instance
                  .collection('duel_requests')
                  .where(
                'toUid',
                isEqualTo: user.uid,
              )
                  .where(
                'status',
                isEqualTo: 'pending',
              )
                  .limit(1)
                  .get();

              if (pendingRequest.docs.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DuelRequestScreen(),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateDuelScreen(),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),

        ],

      ),


      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.cyanAccent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00111F),
                      Color(0xFF003B5C),
                      Color(0xFF00AEEF),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.cyanAccent,
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.9, end: 1.1),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: const Icon(
                        Icons.bolt,
                        color: Colors.cyanAccent,
                        size: 60,
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      "[ SYSTEM ]",
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 4,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "⚔ $hunterRank HUNTER ⚔",
                      style: TextStyle(color: level < 5
                          ? Colors.grey
                          : level < 10
                          ? Colors.green
                          : level < 15
                          ? Colors.blue
                          : Colors.purple,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "LEVEL $level",


                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('hunters')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {

                        if (!snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return const SizedBox();
                        }
                        final data =
                        snapshot.data!.data()
                        as Map<String, dynamic>;

                        final streak =
                            data['streak'] ?? 0;

                        return Column(
                          children: [

                            const SizedBox(height: 20),

                            Text(
                              "🔥 $streak Day Streak",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              getStreakTitle(streak),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 5),

                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: xp / 500,
                      ),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 10,
                          backgroundColor: Colors.black54,
                          color: Colors.cyanAccent,
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    Text(
                      "$xp / 500 XP",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.greenAccent,
                        ),
                      ),
                      child: Column(
                        children: [

                          const Text(
                            "👣 TODAY'S STEPS",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "$todaySteps",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          LinearProgressIndicator(
                            value: todaySteps / 10000 > 1
                                ? 1
                                : todaySteps / 10000,
                            minHeight: 10,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            "$todaySteps / 10000",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            todaySteps >= 10000
                                ? "🏆 Goal Completed"
                                : "🎯 Goal: 10000 Steps",
                            style: TextStyle(
                              color: todaySteps >= 10000
                                  ? Colors.amber
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          if (todaySteps >= 10000)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                "+25 XP Reward Unlocked",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          const SizedBox(height: 10),


                        ],
                      ),
                    ),



                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (questStarted)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1A1A1A),
                        Color(0xFF003344),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.cyanAccent,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.cyanAccent,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [

                      const Text(
                        "⚡ ACTIVE QUEST ⚡",

                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Status: In Progress",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      Text(
                        activeQuest,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Reward: +$questReward XP",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onPressed: () {

                            showDialog(
                              context: context,
                              builder: (_) {

                                final messages = [

                                  "⚔️ Only you know whether this mission is complete.",

                                  "🔥 Shortcuts create weak Hunters.",

                                  "🏆 Discipline is what separates Hunters from legends.",

                                  "⚡ Every completed quest should represent real effort.",

                                ];

                                messages.shuffle();

                                return AlertDialog(
                                  backgroundColor: Colors.black,

                                  title: const Text(
                                    "Hunter Verification",
                                    style: TextStyle(
                                      color: Colors.amber,
                                    ),
                                  ),

                                  content: Text(
                                    "Are you sure you completed this mission honestly?\n\n"
                                        "Only you know the truth.\n\n"
                                        "${messages.first}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),

                                  actions: [

                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        "CONTINUE QUEST",
                                      ),
                                    ),

                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        completeQuest();
                                      },
                                      child: const Text(
                                        "COMPLETE",
                                      ),
                                    ),

                                  ],
                                );
                              },
                            );
                          },

                          child: const Text(
                            "COMPLETE QUEST",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isBannerReady)
                        Center(
                          child: SizedBox(
                            width: bannerAd!.size.width.toDouble(),
                            height: bannerAd!.size.height.toDouble(),
                            child: AdWidget(ad: bannerAd!),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              Row(
                children: [

                  const Text(
                    "Daily Quests",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('hunters')
                        .doc(
                      FirebaseAuth.instance.currentUser?.uid,
                    )
                        .snapshots(),
                    builder: (context, snapshot) {

                      String mode = "SELECT MODE";

                      if (snapshot.hasData &&
                          snapshot.data!.exists) {

                        final data =
                        snapshot.data!.data()
                        as Map<String, dynamic>;

                        if (data['disciplineMode'] != null) {
                          mode =
                              data['disciplineMode']
                                  .toString()
                                  .toUpperCase();
                        }
                      }

                      return ElevatedButton.icon(
                        onPressed: () {
                          showDisciplineModeDialog();
                        },
                        icon: const Icon(
                          Icons.shield,
                          size: 16,
                        ),
                        label: Text(
                          mode,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: () {

                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text(
                            "Create Custom Quest",
                          ),
                          content: StatefulBuilder(
                            builder: (context, setDialogState) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  TextField(
                                    controller: customQuestController,
                                    decoration: const InputDecoration(
                                      hintText: "Quest Name",
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  const Text("XP Reward"),

                                  const SizedBox(height: 10),

                                  Wrap(
                                    spacing: 8,
                                    children: [

                                      ChoiceChip(
                                        label: const Text("10"),
                                        selected: selectedCustomQuestXp == 10,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedCustomQuestXp = 10;
                                          });
                                        },
                                      ),

                                      ChoiceChip(
                                        label: const Text("20"),
                                        selected: selectedCustomQuestXp == 20,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedCustomQuestXp = 20;
                                          });
                                        },
                                      ),

                                      ChoiceChip(
                                        label: const Text("30"),
                                        selected: selectedCustomQuestXp == 30,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedCustomQuestXp = 30;
                                          });
                                        },
                                      ),

                                      ChoiceChip(
                                        label: const Text("40"),
                                        selected: selectedCustomQuestXp == 40,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedCustomQuestXp = 40;
                                          });
                                        },
                                      ),

                                      ChoiceChip(
                                        label: const Text("50"),
                                        selected: selectedCustomQuestXp == 50,
                                        onSelected: (_) {
                                          setDialogState(() {
                                            selectedCustomQuestXp = 50;
                                          });
                                        },
                                      ),

                                    ],
                                  ),

                                ],
                              );
                            },
                          ),
                          actions: [

                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("CANCEL"),
                            ),

                            ElevatedButton(
                              onPressed: () async {

                                if (customQuestController.text
                                    .trim()
                                    .isEmpty) {
                                  return;
                                }

                                final user =
                                    FirebaseAuth.instance.currentUser;

                                if (user == null) return;

                                await FirebaseFirestore.instance
                                    .collection('custom_quests')
                                    .add({

                                  'uid': user.uid,
                                  'name': customQuestController.text.trim(),
                                  'xp': selectedCustomQuestXp,
                                  'createdAt': Timestamp.now(),

                                });

                                customQuestController.clear();
                                selectedCustomQuestXp = 10;

                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text("ADD QUEST"),
                            ),

                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add,
                      color: Colors.cyanAccent,
                    ),
                  ),

                ],
              ),

              const SizedBox(height: 10),

              if (generatedQuests.isEmpty)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('custom_quests')
                      .where(
                    'uid',
                    isEqualTo:
                    FirebaseAuth.instance.currentUser?.uid,
                  )
                      .snapshots(),
                  builder: (context, snapshot) {

                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }

                    if (snapshot.data!.docs.isNotEmpty) {
                      return const SizedBox();
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent,
                        ),
                      ),
                      child: const Column(
                        children: [

                          Icon(
                            Icons.bolt,
                            color: Colors.cyanAccent,
                            size: 40,
                          ),

                          SizedBox(height: 10),

                          Text(
                            "No quests yet",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 10),

                          Text(
                            "Tap + to create your first custom quest.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),

                        ],
                      ),
                    );
                  },
                ),

              ...generatedQuests.map(
                    (quest) => GestureDetector(
                      onTap: completedQuests.contains(
                        quest["name"],
                      )
                          ? null
                          : () {
                        startQuest(
                          quest["name"],
                          quest["xp"],
                        );
                      },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF141E30),
                          Color(0xFF243B55),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.cyanAccent,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          quest["icon"],
                          color: Colors.cyanAccent,
                        ),
                      ),
                      title: Text(
                        completedQuests.contains(
                          quest["name"],
                        )
                            ? "✓ ${quest["name"]}"
                            : quest["name"],
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: completedQuests.contains(
                        quest["name"],
                      )
                          ? const Text(
                        "COMPLETED",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Text(
                          "+${quest["xp"]} XP",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('custom_quests')
                    .where(
                  'uid',
                  isEqualTo:
                  FirebaseAuth.instance.currentUser?.uid,
                )
                    .snapshots(),
                builder: (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }

                  return Column(
                    children: snapshot.data!.docs.map((doc) {

                      final data =
                      doc.data() as Map<String, dynamic>;

                      return GestureDetector(
                        onTap: completedQuests.contains(
                          data['name'],
                        )
                            ? null
                            : () {
                          startQuest(
                            data['name'],
                            data['xp'],
                          );
                        },
                        child: Container(
                          margin:
                          const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2A0845),
                                Color(0xFF6441A5),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.amber,
                            ),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.edit_note,
                              color: Colors.amber,
                            ),
                            title: Text(
                              completedQuests.contains(
                                data['name'],
                              )
                                  ? "✓ ${data['name']}"
                                  : data['name'],
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                completedQuests.contains(
                                  data['name'],
                                )
                                    ? const Text(
                                  "COMPLETED",
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                                    : Text(
                                  "+${data['xp']} XP",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {

                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete Quest?"),
                                        content: Text(data['name']),
                                        actions: [

                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text("CANCEL"),
                                          ),

                                          ElevatedButton(
                                            onPressed: () async {

                                              await doc.reference.delete();

                                              if (mounted) {
                                                Navigator.pop(context);
                                              }
                                            },
                                            child: const Text("DELETE"),
                                          ),

                                        ],
                                      ),
                                    );

                                  },
                                ),

                              ],
                            ),
                          ),
                        ),
                      );

                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 30),


            ],
          ),
        ),
      ),
    );
  }

  Widget questTile(
      String title,
      String xp,
      IconData icon,
      ) {
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.purple,
        ),
        title: Text(
          completedQuests.contains(title)
              ? "✓ $title"
              : title,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: Text(
          xp,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}