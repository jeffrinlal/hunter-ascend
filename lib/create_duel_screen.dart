import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateDuelScreen extends StatefulWidget {
const CreateDuelScreen({super.key});

@override
State<CreateDuelScreen> createState() =>
_CreateDuelScreenState();
}

class _CreateDuelScreenState
extends State<CreateDuelScreen> {

final TextEditingController hunterIdController =
TextEditingController();

final TextEditingController questController =
TextEditingController();

List<Map<String, dynamic>> duelQuests = [];

void addQuest() {

  String questName =
  questController.text.trim();

  if (questName.isEmpty) {
    return;
  }

  bool alreadyExists = duelQuests.any(
        (quest) =>
    quest['name']
        .toString()
        .toLowerCase() ==
        questName.toLowerCase(),
  );

  if (alreadyExists) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Quest already added",
        ),
      ),
    );

    return;
  }
  if (duelQuests.length >= 10) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Maximum 10 quests allowed",
        ),
      ),
    );

    return;
  }
  setState(() {
    duelQuests.add({
      'name': questName,
      'xp': 50,
    });
  });

  questController.clear();
}

void deleteQuest(int index) {
setState(() {
duelQuests.removeAt(index);
});
}

@override
Widget build(BuildContext context) {

return Scaffold(
backgroundColor: Colors.black,

appBar: AppBar(
title: const Text(
"⚔️ Create Duel",
),
backgroundColor: Colors.black,
),

  body: Padding(
    padding: const EdgeInsets.all(20),

    child: Column(
      children: [

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1A0000),
                Color(0xFF330000),
                Color(0xFF001133),
              ],
            ),
            border: Border.all(
              color: Colors.redAccent,
              width: 2,
            ),
          ),
          child: const Column(
            children: [

              Icon(
                Icons.sports_kabaddi,
                color: Colors.redAccent,
                size: 60,
              ),

              SizedBox(height: 10),

              Text(
                "DUEL ARENA",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Create a rivalry and challenge another Hunter",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

TextField(
controller: hunterIdController,
style: const TextStyle(
color: Colors.white,
),
decoration: const InputDecoration(
labelText: "Hunter ID",
),
),

const SizedBox(height: 20),

Row(
children: [

Expanded(
child: TextField(
controller: questController,
style: const TextStyle(
color: Colors.white,
),
decoration: const InputDecoration(
hintText: "Quest Name",
),
),
),

IconButton(
onPressed: addQuest,
icon: const Icon(
Icons.add,
color: Colors.cyanAccent,
),
),
],
),

const SizedBox(height: 20),

const Align(
alignment: Alignment.centerLeft,
child: Text(
"Custom Duel Quests",
style: TextStyle(
color: Colors.white,
fontSize: 22,
fontWeight: FontWeight.bold,
),
),
),

const SizedBox(height: 10),

Expanded(
child: ListView.builder(
itemCount: duelQuests.length,
itemBuilder: (context, index) {

final quest = duelQuests[index];

return Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: const LinearGradient(
      colors: [
        Color(0xFF1A0000),
        Color(0xFF001133),
      ],
    ),
    border: Border.all(
      color: Colors.redAccent,
    ),
  ),
  child: Row(
    children: [

      const Icon(
        Icons.gps_fixed,
        color: Colors.redAccent,
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            Text(
              quest['name'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              "Mission Objective",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius:
          BorderRadius.circular(10),
        ),
        child: const Text(
          "+50 XP",
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      IconButton(
        icon: const Icon(
          Icons.delete,
          color: Colors.redAccent,
        ),
        onPressed: () {
          deleteQuest(index);
        },
      ),
    ],
  ),
);
},
),
),

SizedBox(
width: double.infinity,
child: ElevatedButton(
onPressed: () async {

// Firestore logic next step
  if (hunterIdController.text.trim().isEmpty) {
    return;
  }

  if (duelQuests.length < 4) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Minimum 4 quests required",
        ),
      ),
    );

    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  final duelSnapshot = await FirebaseFirestore.instance
      .collection('duels')
      .get();

  bool targetHasActiveDuel = false;
  bool targetHasPendingRequest = false;

  for (var doc in duelSnapshot.docs) {

    final data = doc.data();

    if ((data['player1'] ==
        hunterIdController.text.trim() ||
        data['player2'] ==
            hunterIdController.text.trim()) &&
        data['status'] == 'active') {

      targetHasActiveDuel = true;
      break;
    }
  }
  final pendingSnapshot =
  await FirebaseFirestore.instance
      .collection('duel_requests')
      .where(
    'toUid',
    isEqualTo: hunterIdController.text.trim(),
  )
      .where(
    'status',
    isEqualTo: 'pending',
  )
      .get();

  if (pendingSnapshot.docs.isNotEmpty) {
    targetHasPendingRequest = true;
  }

  if (user == null) return;

  if (targetHasActiveDuel) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Hunter is already in a duel",
        ),
      ),
    );

    return;
  }

  if (targetHasPendingRequest) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Hunter already has a pending challenge",
        ),
      ),
    );

    return;
  }

  await FirebaseFirestore.instance
      .collection('duel_requests')
      .add({

    'fromUid': user.uid,
    'toUid': hunterIdController.text.trim(),

    'status': 'pending',

    'duelQuests': duelQuests,

    'createdAt': Timestamp.now(),
  });

  if (mounted) {
    Navigator.pop(context);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("⚔️ Duel challenge sent!"),
    ),
  );

},
child: const Text(
"CHALLENGE HUNTER",
),
),
),
],
),
),
);
}
}

