import 'package:flutter/material.dart';
import 'main.dart';

class AwakeningScreen extends StatelessWidget {
  const AwakeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF050816),
      body: Stack(
        children: [

      Container(
      decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(
        "assets/images/awakening_bg.png",
      ),
      fit: BoxFit.cover,
    ),
    ),
    ),

    Container(
    color: Colors.black54,
    ),

    SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.9, end: 1.15),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.flash_on,
                  color: Colors.cyanAccent,
                  size: 120,
                ),
              ),
              const Text(
                "[ SYSTEM ]",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  letterSpacing: 4,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),
              const SizedBox(height: 20),

              const Text(
                "YOUR AWAKENING",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.cyanAccent,
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.cyanAccent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [

                    SizedBox(height: 10),

                    Text(
                      "Level 1",
                      style: TextStyle(
                        color: Colors.black,
                        letterSpacing: 3,
                        fontSize: 25,
                          fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  border: Border.all(
                    color: Colors.cyanAccent,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "[SYSTEM]\n\nYou have acquired the qualifications to become a Hunter.\n\nWill you accept?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                onPressed: () async {

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.black,
                      content: Text(
                        "[ SYSTEM ] ACTIVATING...",
                        style: TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                  );

                  await Future.delayed(
                    const Duration(seconds: 1),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssessmentScreen(),
                    ),
                  );
                },
                child: const Text(
                  "ACCEPT SYSTEM",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}