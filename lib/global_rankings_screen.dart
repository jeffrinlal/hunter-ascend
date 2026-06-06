import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalRankingsScreen extends StatelessWidget {
  const GlobalRankingsScreen({super.key});

  String getRankTitle(int level) {
    if (level >= 30) return "S Rank";
    if (level >= 20) return "A Rank";
    if (level >= 15) return "B Rank";
    if (level >= 10) return "C Rank";
    if (level >= 5) return "D Rank";
    return "E Rank";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("🏆 Global Rankings"),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hunters')
            .orderBy('level', descending: true)
            .orderBy('xp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.cyanAccent,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Loading Hunters...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final hunters = snapshot.data!.docs;

          return Column(
              children: [

          Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
          colors: [
          Color(0xFF0F2027),
          Color(0xFF203A43),
          Color(0xFF2C5364),
          ],
          ),
          border: Border.all(
          color: Colors.amber,
          width: 2,
          ),
          ),
          child: Column(
          children: [

          const Text(
          "🏆 YOUR HUNTER STATUS",
          style: TextStyle(
          color: Colors.amber,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          ),
          ),

          const SizedBox(height: 10),

          Text(
          hunters.isNotEmpty
          ? hunters[0]['hunterName']
              : "Unknown Hunter",
          style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          ),
          ),

          const SizedBox(height: 6),

          Text(
          hunters.isNotEmpty
          ? "${getRankTitle(hunters[0]['level'])} • Level ${hunters[0]['level']}"
              : "",
          style: const TextStyle(
          color: Colors.white70,
          ),
          ),

          const SizedBox(height: 6),

          Text(
          hunters.isNotEmpty
          ? "${hunters[0]['xp']} XP"
              : "",
          style: const TextStyle(
          color: Colors.greenAccent,
          fontWeight: FontWeight.bold,
          ),
          ),
          ],
          ),
          ),

          Expanded(
          child: ListView.builder(
          itemCount: hunters.length,
          itemBuilder: (context, index) {
              final hunter =
              hunters[index].data() as Map<String, dynamic>;

              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF141E30),
                      Color(0xFF243B55),
                    ],
                  ),
                  border: Border.all(
                    color: index == 0
                        ? Colors.amber
                        : Colors.cyanAccent,
                  ),
                ),
                child: Row(
                  children: [

                    index == 0
                        ? const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 32,
                    )
                        : Text(
                      "#${index + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 20),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            hunter['hunterName'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            "${getRankTitle(hunter['level'])} • Level ${hunter['level']}",
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      "${hunter['xp']} XP",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
      ),
    ),
   ],
   );
  },
  ),
  );
}
}