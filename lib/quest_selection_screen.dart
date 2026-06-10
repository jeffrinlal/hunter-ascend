
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestSelectionScreen extends StatefulWidget {
const QuestSelectionScreen({super.key});

@override
State<QuestSelectionScreen> createState() =>
_QuestSelectionScreenState();
}

class _QuestSelectionScreenState
extends State<QuestSelectionScreen> {

bool fatLoss = false;
bool discipline = false;
bool muscleGain = false;
bool selfImprovement = false;


@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("Choose Your Path"),
),
body: Padding(
padding: const EdgeInsets.all(20),
child: Column(
children: [

const Text(
"Select all that apply",
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 20),

CheckboxListTile(
title: const Text("Fat Loss"),
value: fatLoss,
onChanged: (value) {
setState(() {
fatLoss = value!;
});
},
),

CheckboxListTile(
title: const Text("Discipline"),
value: discipline,
onChanged: (value) {
setState(() {
discipline = value!;
});
},
),

CheckboxListTile(
title: const Text("Muscle Gain"),
value: muscleGain,
onChanged: (value) {
setState(() {
muscleGain = value!;
});
},
),

CheckboxListTile(
title: const Text("Self Improvement"),
value: selfImprovement,
onChanged: (value) {
setState(() {
selfImprovement = value!;
});
},
),

  const Spacer(),

  Row(
    children: [

      Expanded(
        child: OutlinedButton(
          onPressed: () async {

            final prefs =
            await SharedPreferences.getInstance();

            await prefs.setBool(
              'hasCompletedSetup',
              true,
            );

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  fatLoss: false,
                  discipline: false,
                  muscleGain: false,
                  selfImprovement: false,
                ),
              ),
                  (route) => false,
            );
          },
          child: const Text(
            "SKIP",
          ),
        ),
      ),

      const SizedBox(width: 10),

      Expanded(
        child: ElevatedButton(
          onPressed: () async {

            final prefs =
            await SharedPreferences.getInstance();

            await prefs.setBool(
              'hasCompletedSetup',
              true,
            );

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardScreen(
                  fatLoss: fatLoss,
                  discipline: discipline,
                  muscleGain: muscleGain,
                  selfImprovement: selfImprovement,
                ),
              ),
                  (route) => false,
            );
          },
          child: const Text(
            "GENERATE MY QUESTS",
          ),
        ),
      ),

    ],
  ),
  ],
  ),
  ),
  );
  }
  }

