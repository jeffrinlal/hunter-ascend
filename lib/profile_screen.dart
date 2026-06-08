import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'weight_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hunter Profile"),
        backgroundColor: Colors.black,
      ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.person,
              color: Colors.cyanAccent,
              size: 100,
            ),

            const SizedBox(height: 20),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('hunters')
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final data =
                snapshot.data!.data()
                as Map<String, dynamic>;

                return Text(
                  data['hunterName'] ?? "Unknown Hunter",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),


  const SizedBox(height: 30),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
        .collection('hunters')
        .doc(user?.uid)
        .snapshots(),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const CircularProgressIndicator();
      }

      final data =
      snapshot.data!.data()
      as Map<String, dynamic>;
      final height =
      (data['height'] ?? 0).toDouble();

      final weight =
      (data['weight'] ?? 0).toDouble();

      final startingWeight =
      (data['startingWeight'] ?? weight)
          .toDouble();

      double bmi = 0;

      if (height > 0) {
        bmi =
            weight /
                ((height / 100) *
                    (height / 100));
      }

      String hunterClass;

      if (bmi < 18.5) {
        hunterClass = "⚡ Agile Hunter";
      } else if (bmi < 25) {
        hunterClass = "⚔️ Balanced Hunter";
      } else if (bmi < 30) {
        hunterClass = "🛡️ Tank Hunter";
      } else {
        hunterClass = "🔥 Heavy Tank Hunter";
      }

      return Column(
        children: [

          Text(
            "⭐ Level: ${data['level'] ?? 1}",
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "⚡ XP: ${data['xp'] ?? 0}",
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "⚔️ Duel Wins: ${data['duelWins'] ?? 0}",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "💀 Duel Losses: ${data['duelLosses'] ?? 0}",
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            "🏆 Win Rate: ${((data['duelWins'] ?? 0) + (data['duelLosses'] ?? 0)) == 0
                ? 0
                : (((data['duelWins'] ?? 0) * 100) /
                ((data['duelWins'] ?? 0) +
                    (data['duelLosses'] ?? 0)))
                .toStringAsFixed(0)}%",
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),

          ),
          const SizedBox(height: 30),
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.cyanAccent,
              ),
            ),
            child: Column(
              children: [

                const Text(
                  "🔥 HUNTER PHYSIQUE",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "BMI: ${bmi.toStringAsFixed(1)}",
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  hunterClass,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Starting Weight: ${startingWeight.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),

                Text(
                  "Current Weight: ${weight.toStringAsFixed(1)} kg",
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 15),

                ElevatedButton.icon(
                  onPressed: () {
                    showUpdateWeightDialog();
                  },
                  icon: const Icon(Icons.monitor_weight),
                  label: const Text(
                    "UPDATE WEIGHT",
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const WeightHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text(
                    "WEIGHT HISTORY",
                  ),
                ),

              ],
            ),
          ),
                  ],
      );

    },
  ),

          ],
        ),
      ),
        ),
    );

  }
  void showUpdateWeightDialog() {

    final weightController =
    TextEditingController();

    showDialog(
      context: context,
      builder: (_) {

        return AlertDialog(

          title: const Text(
            "Update Current Weight",
          ),

          content: TextField(
            controller: weightController,
            keyboardType:
            TextInputType.number,
            decoration:
            const InputDecoration(
              hintText: "Weight in kg",
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "CANCEL",
              ),
            ),

            ElevatedButton(
              onPressed: () async {

                final weight =
                double.tryParse(
                  weightController.text,
                );

                if (weight == null) {
                  return;
                }

                final user =
                    FirebaseAuth
                        .instance
                        .currentUser;

                if (user == null) {
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('hunters')
                    .doc(user.uid)
                    .update({

                  'weight': weight,

                });

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
                }
              },
              child: const Text(
                "SAVE",
              ),
            ),

          ],
        );
      },
    );
  }
}
