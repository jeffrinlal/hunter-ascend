import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DuelHistoryScreen extends StatelessWidget {
  const DuelHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Duel History"),
        backgroundColor: Colors.black,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('duels')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final user =
              FirebaseAuth.instance.currentUser;

          final myDuels =
          snapshot.data!.docs.where((doc) {

            final duel =
            doc.data() as Map<String, dynamic>;

            return duel['player1'] == user?.uid ||
                duel['player2'] == user?.uid;

          }).toList();

          if (myDuels.isEmpty) {
            return const Center(
              child: Text(
                "No Duel History",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: myDuels.length,
            itemBuilder: (context, index) {

              final duel =
              myDuels[index].data()
              as Map<String, dynamic>;

              String result = "⚪ Cancelled";
              Color color = Colors.grey;

              if (duel['status'] == 'completed') {

                if (duel['winner'] == user?.uid) {

                  result = "🏆 Won";
                  color = Colors.green;

                } else {

                  result = "💀 Lost";
                  color = Colors.red;

                }

              }

              return Card(
                color: Colors.black87,
                child: ListTile(
                  leading: Icon(
                    Icons.sports_kabaddi,
                    color: color,
                  ),
                  title: Text(
                    result,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}