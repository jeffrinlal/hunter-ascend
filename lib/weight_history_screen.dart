import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeightHistoryScreen extends StatelessWidget {
  const WeightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text(
          "📈 Weight History",
        ),
        backgroundColor: Colors.black,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('weight_history')
            .where(
          'uid',
          isEqualTo: user!.uid,
        )
            .orderBy(
          'date',
          descending: true,
        )
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No weight history yet",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            );
          }
          final currentWeight =
          (docs.first['weight'] as num).toDouble();

          final startingWeight =
          (docs.last['weight'] as num).toDouble();

          final weightLost =
              startingWeight - currentWeight;

          String title;
          String message;

          if (weightLost >= 20) {
            title = "👑 Legendary Hunter";
            message = "This isn't luck. This is discipline.";
          } else if (weightLost >= 10) {
            title = "⭐ Elite Progress";
            message = "You are becoming the person you promised yourself you'd be.";
          } else if (weightLost >= 5) {
            title = "🏆 Transformation Begins";
            message = "Most hunters quit early. You didn't.";
          } else if (weightLost >= 3) {
            title = "⚔️ Momentum Rising";
            message = "Your consistency is becoming visible.";
          } else if (weightLost > 0) {
            title = "🔥 First Victories";
            message = "You've started the journey. Keep moving forward, Hunter.";
          } else {
            title = "🌱 New Hunter";
            message = "Every Hunter starts somewhere.";
          }

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No weight history yet",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              Container(
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

                    Text(
                      "🔥 Total Weight Lost: ${weightLost.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ...docs.map((doc) {

                final data =
                doc.data()
                as Map<String, dynamic>;

                return Card(
                  color: Colors.black54,
                  child: ListTile(
                    leading: const Icon(
                      Icons.monitor_weight,
                      color: Colors.cyanAccent,
                    ),
                    title: Text(
                      "${data['weight']} kg",
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }).toList(),

            ],
          );
        },
      ),
    );
  }
}