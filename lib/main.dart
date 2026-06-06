
import 'package:flutter/material.dart';
import 'awakening_screen.dart';
import 'dashboard_screen.dart';
import 'quest_selection_screen.dart';
import 'scanning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> signInAnonymously() async {
    if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
    }
}
Future<void> createHunterProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid);

    final doc = await docRef.get();

    if (!doc.exists) {
        await docRef.set({
            'hunterName': 'Hunter_${user.uid.substring(0, 6)}',
            'level': 1,
            'xp': 0,
            'streak': 0,
        });
    }
}

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp();
    await signInAnonymously();
    await createHunterProfile();

    await MobileAds.instance.initialize();

    final prefs = await SharedPreferences.getInstance();
    final hasCompletedSetup =
        prefs.getBool('hasCompletedSetup') ?? false;

    runApp(
        HunterAscendApp(
            hasCompletedSetup: hasCompletedSetup,
        ),
    );
}

class HunterAscendApp extends StatelessWidget {

    final bool hasCompletedSetup;

    const HunterAscendApp({
        super.key,
        required this.hasCompletedSetup,
    });

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'Hunter Ascend',
theme: ThemeData.dark(),
    home: hasCompletedSetup
        ? DashboardScreen(
        fatLoss: true,
        discipline: false,
        muscleGain: false,
        selfImprovement: false,
    )
        : const AwakeningScreen(),
);
}
}

class WelcomeScreen extends StatelessWidget {
const WelcomeScreen({super.key});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.black,
body: Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(
Icons.flash_on,
size: 100,
color: Colors.purple,
),
const SizedBox(height: 20),
const Text(
'HUNTER ASCEND',
style: TextStyle(
fontSize: 32,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
const Text(
'Level Up Your Real Life',
style: TextStyle(
color: Colors.grey,
fontSize: 18,
),
),
const SizedBox(height: 40),
ElevatedButton(
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => const AssessmentScreen(),
),
);
},
child: const Text(
'BEGIN HUNTER ASSESSMENT',
),
),
],
),
),
),
);
}
}

class AssessmentScreen extends StatefulWidget {
const AssessmentScreen({super.key});

@override
State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
final nameController = TextEditingController();
final ageController = TextEditingController();
final heightController = TextEditingController();
final weightController = TextEditingController();

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("Hunter Assessment"),
),
body: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
children: [
    const Text(
        "[ SYSTEM ANALYSIS ]",
        style: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 18,
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
        ),
    ),

    const SizedBox(height: 20),
    const SizedBox(height: 20),

    Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border.all(
                color: Colors.cyanAccent,
                width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
            children: [

                TextField(
                    controller: nameController,
                    style: const TextStyle(
                        color: Colors.white,
                    ),
                    decoration: InputDecoration(
                        labelText: "Hunter ID",
                        labelStyle: const TextStyle(
                            color: Colors.cyanAccent,
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                                width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                    ),
                ),

                const SizedBox(height: 20),

                TextField(
                    controller: ageController,
                    style: const TextStyle(
                        color: Colors.white,
                    ),
                    decoration: InputDecoration(
                        labelText: "Age",
                        labelStyle: const TextStyle(
                            color: Colors.cyanAccent,
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                                width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                    ),
                ),

                const SizedBox(height: 20),

                TextField(
                    controller: heightController,
                    style: const TextStyle(
                        color: Colors.white,
                    ),
                    decoration: InputDecoration(
                        labelText: "Height (cm)",
                        labelStyle: const TextStyle(
                            color: Colors.cyanAccent,
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                                width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                    ),
                ),

                const SizedBox(height: 20),

                TextField(
                    controller: weightController,
                    style: const TextStyle(
                        color: Colors.white,
                    ),
                    decoration: InputDecoration(
                        labelText: "Weight (kg)",
                        labelStyle: const TextStyle(
                            color: Colors.cyanAccent,
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.cyanAccent,
                                width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                        ),
                    ),
                ),
            ],
        ),
    ),

    const SizedBox(height: 25),

    SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                elevation: 12,
                shadowColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                ),
            ),
            onPressed: () {

                if (nameController.text.trim().isEmpty ||
                    ageController.text.trim().isEmpty ||
                    heightController.text.trim().isEmpty ||
                    weightController.text.trim().isEmpty) {

                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            backgroundColor: Colors.red,
                            content: Text(
                                "Please complete all Hunter data.",
                            ),
                        ),
                    );

                    return;
                }

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ScanningScreen(),
                    ),
                );
            },
            child: const Text(
                "INITIATE SCAN",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                ),
            ),
        ),
    ),
],
),
),
);
}
}
