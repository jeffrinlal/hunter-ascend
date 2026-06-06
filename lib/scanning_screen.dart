import 'dart:async';
import 'package:flutter/material.dart';
import 'quest_selection_screen.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen> {

  double progress = 0;

  @override
  void initState() {
    super.initState();

    Timer.periodic(
      const Duration(milliseconds: 100),
          (timer) {

        setState(() {
          progress += 0.025;
        });

        if (progress >= 1) {
          timer.cancel();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const QuestSelectionScreen(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF050816),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Icon(
                Icons.memory,
                size: 120,
                color: Colors.cyanAccent,
              ),

              const SizedBox(height: 30),

              const Text(
                "[ SYSTEM ANALYSIS ]",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 22,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                color: Colors.cyanAccent,
                backgroundColor: Colors.white12,
              ),

              const SizedBox(height: 20),

              Text(
                "${(progress * 100).toInt()}%",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Scanning Hunter Data...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}