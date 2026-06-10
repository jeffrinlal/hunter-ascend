import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'awakening_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'dashboard_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> signInGuest(
      BuildContext context) async {

    final credential =
    await FirebaseAuth.instance
        .signInAnonymously();

    final user = credential.user;

    if (user != null) {

      final docRef = FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid);

      final doc = await docRef.get();

      if (!doc.exists) {

        await docRef.set({

          'hunterName':
          'Hunter_${user.uid.substring(0, 6)}',

          'level': 1,
          'xp': 0,
          'streak': 0,
          'lastQuestDate': '',

        });

        if (context.mounted) {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const AwakeningScreen(),
            ),
          );
        }

      } else {

        if (context.mounted) {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DashboardScreen(
                    fatLoss: false,
                    discipline: false,
                    muscleGain: false,
                    selfImprovement: false,
                  ),
            ),
          );
        }
      }
    }
    if (context.mounted) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const AwakeningScreen(),
        ),
      );
    }
  }
  Future<void> signInWithGoogle(
      BuildContext context) async {

    final GoogleSignInAccount? googleUser =
    await GoogleSignIn().signIn();

    if (googleUser == null) return;

    final GoogleSignInAuthentication
    googleAuth =
    await googleUser.authentication;

    final credential =
    GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
    await FirebaseAuth.instance
        .signInWithCredential(
        credential);

    final user = userCredential.user;

    if (user != null) {

      final docRef = FirebaseFirestore
          .instance
          .collection('hunters')
          .doc(user.uid);

      final doc = await docRef.get();

      if (!doc.exists) {

        await docRef.set({

          'hunterName':
          'Hunter_${user.uid.substring(0, 6)}',

          'level': 1,
          'xp': 0,
          'streak': 0,
          'lastQuestDate': '',

        });

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const AwakeningScreen(),
            ),
          );
        }

      } else {

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DashboardScreen(
                    fatLoss: false,
                    discipline: false,
                    muscleGain: false,
                    selfImprovement: false,
                  ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Padding(
          padding:
          const EdgeInsets.all(20),

          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.bolt,
                color: Colors.cyanAccent,
                size: 100,
              ),

              const SizedBox(height: 20),

              const Text(
                "HUNTER ASCEND",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              ElevatedButton(
                onPressed: () {
                  signInWithGoogle(context);
                },
                child: const Text(
                  "🔵 CONTINUE WITH GOOGLE",
                ),
              ),



              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () {
                  signInGuest(context);
                },
                child: const Text(
                  "⚡ CONTINUE AS GUEST",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}