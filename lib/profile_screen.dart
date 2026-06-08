import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'duel_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Hunter Profile"),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.person,
              color: Colors.cyanAccent,
              size: 100,
            ),

            const SizedBox(height: 20),

            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('hunters')
                  .doc(user?.uid)
                  .get(),
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

            const Text(
              "Hunter ID",
              style: TextStyle(
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 10),

Padding(
padding: const EdgeInsets.all(12),
child: Column(
children: [

SelectableText(
user?.uid ?? "",
textAlign: TextAlign.center,
style: const TextStyle(
color: Colors.greenAccent,
),
),

const SizedBox(height: 20),

ElevatedButton.icon(
onPressed: () async {
await Clipboard.setData(
ClipboardData(text: user?.uid ?? ""),
);

if (context.mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text("Hunter ID copied!"),
),
);
}
},
icon: const Icon(Icons.copy),
label: const Text("COPY HUNTER ID"),
),
  const SizedBox(height: 30),

  FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance
        .collection('hunters')
        .doc(user?.uid)
        .get(),
    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const CircularProgressIndicator();
      }

      final data =
      snapshot.data!.data()
      as Map<String, dynamic>;

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

          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                  const DuelHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text(
              "VIEW DUEL HISTORY",
            ),
          ),
        ],
      );

    },
  ),

],
),
),
          ],
        ),
      ),
    );
  }
}