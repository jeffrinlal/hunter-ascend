import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class DuelScreen extends StatelessWidget {
  final String duelId;

  const DuelScreen({
    super.key,
    required this.duelId,
  });
  Future<void> updateDuelStats(
      Map<String, dynamic> duel,
      String winnerUid,
      ) async {

    String loserUid =
    winnerUid == duel['player1']
        ? duel['player2']
        : duel['player1'];

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(winnerUid)
        .update({
      'duelWins': FieldValue.increment(1),
    });

    await FirebaseFirestore.instance
        .collection('hunters')
        .doc(loserUid)
        .update({
      'duelLosses': FieldValue.increment(1),
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("⚔️ Hunter Rivalry"),
        backgroundColor: Colors.black,
      ),
body: StreamBuilder<DocumentSnapshot>(
stream: FirebaseFirestore.instance
.collection('duels')
.doc(duelId)
.snapshots(),
builder: (context, snapshot) {
if (!snapshot.hasData) {
return const Center(
child: CircularProgressIndicator(),
);
}

final duel =
snapshot.data!.data() as Map<String, dynamic>;
if (duel['status'] == 'cancelled') {

  WidgetsBinding.instance.addPostFrameCallback((_) {

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Duel has been cancelled",
        ),
      ),
    );

  });

  return const SizedBox();
}
final user = FirebaseAuth.instance.currentUser;

bool isPlayer1 =
    duel['player1'] == user?.uid;

List completedToday =
isPlayer1
    ? duel['player1CompletedToday']
    : duel['player2CompletedToday'];
if (duel['status'] == 'completed') {

  final user =
      FirebaseAuth.instance.currentUser;

  bool won =
      duel['winner'] == user?.uid;
  bool isPlayer1 =
      duel['player1'] == user?.uid;

  String viewedField =
  isPlayer1
      ? 'player1ViewedResult'
      : 'player2ViewedResult';

  if (duel[viewedField] == false) {
    FirebaseFirestore.instance
        .collection('duels')
        .doc(duelId)
        .update({
      viewedField: true,
    });
  }



  return Center(
    child: Column(
      mainAxisAlignment:
      MainAxisAlignment.center,
      children: [

        Icon(
          won
              ? Icons.emoji_events
              : Icons.close,
          color: won
              ? Colors.amber
              : Colors.red,
          size: 120,
        ),

        const SizedBox(height: 20),

        Text(
          won
              ? "YOU WON!"
              : "YOU LOST!",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

return Padding(
        padding: const EdgeInsets.all(20),
    child: SingleChildScrollView(
      child: Column(
          children: [
            if (duel['cancelStatus'] == 'pending' &&
                duel['cancelRequestedBy'] != user?.uid)

              Container(
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [

                    const Text(
                      "⚠️ Cancel Request Received",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                      children: [

                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('duels')
                                .doc(duelId)
                                .update({
                              'status': 'cancelled',
                            });
                          },
                          child: const Text("ACCEPT"),
                        ),

                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('duels')
                                .doc(duelId)
                                .update({
                              'cancelRequestedBy': '',
                              'cancelStatus': '',
                            });
                          },
                          child: const Text("DECLINE"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Builder(
              builder: (context) {
                final startDate =
                (duel['startDate'] as Timestamp).toDate();

                final daysPassed =
                    DateTime.now()
                        .difference(startDate)
                        .inDays;

                final currentDay =
                    daysPassed + 1;

                final daysRemaining =
                    duel['durationDays'] - daysPassed;
                if (daysRemaining <= 0 &&
                    duel['status'] == 'active' &&
                    (duel['winner'] ?? '').toString().isEmpty) {

                  String winnerUid = '';

                  if ((duel['player1Score'] ?? 0) >
                      (duel['player2Score'] ?? 0)) {
                    winnerUid = duel['player1'];
                  } else if ((duel['player2Score'] ?? 0) >
                      (duel['player1Score'] ?? 0)) {
                    winnerUid = duel['player2'];
                  }
                  FirebaseFirestore.instance
                      .collection('duels')
                      .doc(duelId)
                      .update({
                    'status': 'completed',
                    'winner': winnerUid,

                    'player1ViewedResult': false,
                    'player2ViewedResult': false,
                  });

                  updateDuelStats(
                    duel,
                    winnerUid,
                  );
                }

                return Column(
                  children: [
                    Text(
                      "DAY $currentDay / ${duel['durationDays']}",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "$daysRemaining DAYS LEFT",
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [

                  const Text(
                    "⚔️ ACTIVE RIVALRY",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "YOU",
                    style: TextStyle(color: Colors.blue),
                  ),
                  Text(
                    "${isPlayer1 ? duel['player1Score'] : duel['player2Score']} XP",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  LinearProgressIndicator(
                    value: ((duel['player1Score'] ?? 0) +
                        (duel['player2Score'] ?? 0))
                        == 0
                        ? 0
                        : (isPlayer1
                        ? duel['player1Score']
                        : duel['player2Score']) /
                        ((duel['player1Score'] ?? 0) +
                            (duel['player2Score'] ?? 0)),
                    minHeight: 12,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "OPPONENT",
                    style: TextStyle(color: Colors.red),
                  ),
                  Text(
                    "${isPlayer1 ? duel['player2Score'] : duel['player1Score']} XP",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  LinearProgressIndicator(
                    value: ((duel['player1Score'] ?? 0) +
                        (duel['player2Score'] ?? 0))
                        == 0
                        ? 0
                        : (isPlayer1
                        ? duel['player2Score']
                        : duel['player1Score']) /
                        ((duel['player1Score'] ?? 0) +
                            (duel['player2Score'] ?? 0)),
                    minHeight: 12,
                    color: Colors.red,
                  ),
                ],
              ),
            ),



            const SizedBox(height: 20),

            if (duel['cancelStatus'] != 'pending')
              ElevatedButton.icon(
              onPressed: () async {

                final startDate =
                (duel['startDate'] as Timestamp).toDate();

                if (DateTime.now()
                    .difference(startDate)
                    .inHours >
                    24) {

                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Cancel available only during first 24 hours",
                      ),
                    ),
                  );

                  return;
                }

                final user =
                    FirebaseAuth.instance.currentUser;

                await FirebaseFirestore.instance
                    .collection('duels')
                    .doc(duelId)
                    .update({
                  'cancelRequestedBy': user?.uid,
                  'cancelStatus': 'pending',
                });

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Cancel request sent",
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.cancel),
              label: const Text(
                "REQUEST CANCEL DUEL",
              ),
            ),
            const SizedBox(height: 15),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Shared Quests",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),


            ...(duel['duelQuests'] as List).map(
                  (quest) => Card(
                color: Colors.grey[900],
                child: ListTile(
                  title: Text(
                    quest['name'],
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    "+${quest['xp']} XP",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: completedToday.contains(
                      quest['name'],
                    )
                        ? null
                        : () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Complete Quest"),
                          content: Text(
                            "Complete ${quest['name']}?",
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
                                final user = FirebaseAuth.instance.currentUser;

                                if (user == null) return;

                                bool isPlayer1 =
                                    duel['player1'] == user.uid;

                                String completedField =
                                isPlayer1
                                    ? 'player1CompletedToday'
                                    : 'player2CompletedToday';

                                await FirebaseFirestore.instance
                                    .collection('duels')
                                    .doc(duelId)
                                    .update({
                                  completedField: FieldValue.arrayUnion([
                                    quest['name']
                                  ]),

                                  isPlayer1
                                      ? 'player1Score'
                                      : 'player2Score':
                                  FieldValue.increment(
                                    quest['xp'],
                                  ),
                                });

                                Navigator.pop(context);

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "${quest['name']} completed!",
                                    ),
                                  ),
                                );
                              },
                              child: const Text("YES"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      completedToday.contains(
                        quest['name'],
                      )
                          ? "✓ COMPLETED"
                          : "COMPLETE",
                    ),
                  ),
                )
              ),
            ),
          ],
        ),
    ),
);
},
),
    );
  }
}