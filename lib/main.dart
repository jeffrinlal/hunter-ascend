import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:flutter/services.dart';
import 'package:hunter_ascend/screens/auth/awakening_screen.dart';
import 'package:hunter_ascend/screens/auth/scanning_screen.dart';
import 'package:hunter_ascend/screens/dashboard/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hunter_ascend/screens/auth/login_screen.dart';
import 'package:hunter_ascend/services/notification_service.dart';
import 'dart:math' as math;

Future<void> signInAnonymously() async {
    if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
    }
}

Future<void> createHunterProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef =
    FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    try {
    final doc = await docRef.get();

    if (!doc.exists) {
        await docRef.set({
            'hunterName': 'Hunter_${user.uid.substring(0, 6)}',
            'level': 1,
            'xp': 0,
            'streak': 0,
            'lastQuestDate': '',
        });
    }
    } catch (e) {
      debugPrint("createHunterProfile: $e");
    }
}

/// App entry point: initializes Firebase, notifications, ads, and theme prefs
/// before running [HunterAscendApp].
void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
    ));

    bool hasCompletedSetup = false;
    try {
    await Firebase.initializeApp();
    await NotificationService().init();
    await NotificationService().scheduleAllNotifications();

    debugPrint("USER ON STARTUP: ${FirebaseAuth.instance.currentUser?.uid}");

    await createHunterProfile();
    await MobileAds.instance.initialize();

    final prefs = await SharedPreferences.getInstance();
    hasCompletedSetup = prefs.getBool('hasCompletedSetup') ?? false;

    final isDarkMode = prefs.getBool('darkMode') ?? false;
    HunterTheme.isDark = isDarkMode;
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      debugPrint("startup: $e");
    }

    runApp(HunterAscendApp(hasCompletedSetup: hasCompletedSetup));
}

/// Root widget: wires global theme + auth gating into [MaterialApp].
class HunterAscendApp extends StatelessWidget {
    final bool hasCompletedSetup;

    const HunterAscendApp({super.key, required this.hasCompletedSetup});

    @override
    Widget build(BuildContext context) {
        return ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
                HunterTheme.isDark = mode == ThemeMode.dark;
                return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Hunter Ascend',
            theme: HunterTheme.lightTheme,
            darkTheme: HunterTheme.darkTheme,
            themeMode: mode,

            builder: (context, child) {
                return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        padding: MediaQuery.of(context).padding.copyWith(
                            bottom: math.max(
                                MediaQuery.of(context).padding.bottom,
                                MediaQuery.of(context).viewPadding.bottom,
                            ),
                        ),
                    ),
                    child: SafeArea(
                        top: false,
                        bottom: true,
                        child: child!,
                    ),
                );
            },

            home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                    debugPrint("AUTH USER: ${snapshot.data?.uid}");

                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _LoadingScreen();
                    }

                    if (snapshot.hasData) {
                        return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('hunters')
                                .doc(snapshot.data!.uid)
                                .get(),
                            builder: (context, hunterSnapshot) {
                                if (!hunterSnapshot.hasData) {
                                    return const _LoadingScreen();
                                }

                                final data =
                                hunterSnapshot.data!.data() as Map<String, dynamic>?;

                                final onboardingComplete = data?['onboardingComplete'] ??
                                    (data?['height'] != null &&
                                        data?['weight'] != null &&
                                        data?['age'] != null);

                                if (onboardingComplete) {
                                    return MainShell(
                                        fatLoss: false,
                                        discipline: false,
                                        muscleGain: false,
                                        selfImprovement: false,
                                        bioQuests: [],
                                    );
                                }

                                return const AwakeningScreen();
                            },
                        );
                    }

                    return const LoginScreen();
                },
            ),
                );
            },
        );
    }
}

class _LoadingScreen extends StatelessWidget {
    const _LoadingScreen();

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: HunterTheme.background,
            body: Center(
                child: CircularProgressIndicator(
                    color: HunterTheme.primary,
                    strokeWidth: 1.5,
                ),
            ),
        );
    }
}

/// Pre-onboarding welcome/landing screen shown before assessment.
class WelcomeScreen extends StatelessWidget {
    const WelcomeScreen({super.key});

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: HunterTheme.background,
            body: Stack(
                children: [
                    CustomPaint(
                        size: MediaQuery.of(context).size,
                        painter: _GridPainter(),
                    ),
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: HunterTheme.primary.withOpacity(0.07),
                                            border: Border.all(
                                                color: HunterTheme.primary.withOpacity(0.5),
                                                width: 1.5,
                                            ),
                                            boxShadow: [
                                                BoxShadow(
                                                    color: HunterTheme.primary.withOpacity(0.3),
                                                    blurRadius: 28,
                                                    spreadRadius: 4,
                                                ),
                                            ],
                                        ),
                                        child: Icon(
                                            Icons.flash_on,
                                            size: 48,
                                            color: HunterTheme.primary,
                                        ),
                                    ),
                                    const SizedBox(height: 28),
                                    RichText(
                                        text: TextSpan(
                                            children: [
                                                TextSpan(
                                                    text: 'HUNTER ',
                                                    style: TextStyle(
                                                        color: HunterTheme.textPrimary,
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 4,
                                                    ),
                                                ),
                                                TextSpan(
                                                    text: 'ASCEND',
                                                    style: TextStyle(
                                                        color: HunterTheme.primary,
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 4,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Level Up Your Real Life',
                                        style: TextStyle(
                                            color: HunterTheme.textPrimary.withOpacity(0.35),
                                            fontSize: 14,
                                            letterSpacing: 1,
                                        ),
                                    ),
                                    const SizedBox(height: 48),
                                    GestureDetector(
                                        onTap: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => const AssessmentScreen(),
                                                ),
                                            );
                                        },
                                        child: Container(
                                            width: double.infinity,
                                            height: 54,
                                            decoration: BoxDecoration(
                                                color: HunterTheme.primary,
                                                borderRadius: BorderRadius.circular(6),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: HunterTheme.primary.withOpacity(0.4),
                                                        blurRadius: 22,
                                                        spreadRadius: 2,
                                                    ),
                                                ],
                                            ),
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                    Icon(Icons.flash_on,
                                                        color: HunterTheme.background, size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                        'BEGIN HUNTER ASSESSMENT',
                                                        style: TextStyle(
                                                            color: HunterTheme.background,
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 13,
                                                            letterSpacing: 2,
                                                        ),
                                                    ),
                                                ],
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

/// Collects the hunter's initial physical data (name/age/height/weight).
class AssessmentScreen extends StatefulWidget {
    const AssessmentScreen({super.key});

    @override
    State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen>
    with TickerProviderStateMixin {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final heightController = TextEditingController();
    final weightController = TextEditingController();

    late AnimationController _fadeController;
    late AnimationController _pulseController;
    late Animation<double> _fadeAnim;
    late Animation<double> _pulseAnim;

    @override
    void initState() {
        super.initState();

        _fadeController = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 700),
        )..forward();

        _pulseController = AnimationController(
            vsync: this,
            duration: const Duration(seconds: 2),
        )..repeat(reverse: true);

        _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        );

        _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );
    }

    @override
    void dispose() {
        _fadeController.dispose();
        _pulseController.dispose();
        nameController.dispose();
        ageController.dispose();
        heightController.dispose();
        weightController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;

        return Scaffold(
            backgroundColor: HunterTheme.background,
            body: Stack(
                children: [
                    CustomPaint(
                        size: Size(size.width, size.height),
                        painter: _GridPainter(),
                    ),
                    Positioned(
                        top: -60,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (context, _) => Center(
                                child: Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                            colors: [
                                                HunterTheme.primary
                                                    .withOpacity(0.1 * _pulseAnim.value),
                                                Colors.transparent,
                                            ],
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                    SafeArea(
                        child: FadeTransition(
                            opacity: _fadeAnim,
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 20),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                        const SizedBox(height: 12),
                                        Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                                AnimatedBuilder(
                                                    animation: _pulseAnim,
                                                    builder: (context, _) => _dot(_pulseAnim.value),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                    '[ SYSTEM ANALYSIS ]',
                                                    style: TextStyle(
                                                        color: HunterTheme.primary,
                                                        fontSize: 13,
                                                        letterSpacing: 3,
                                                        fontWeight: FontWeight.w700,
                                                    ),
                                                ),
                                                const SizedBox(width: 10),
                                                AnimatedBuilder(
                                                    animation: _pulseAnim,
                                                    builder: (context, _) => _dot(_pulseAnim.value),
                                                ),
                                            ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                            'HUNTER ASSESSMENT',
                                            style: TextStyle(
                                                color: HunterTheme.textPrimary,
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 3,
                                            ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                            width: 80,
                                            height: 1,
                                            decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                    colors: [
                                                        Colors.transparent,
                                                        HunterTheme.primary,
                                                        Colors.transparent,
                                                    ],
                                                ),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: HunterTheme.primary.withOpacity(0.5),
                                                        blurRadius: 6,
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                            'Enter your hunter data to begin profiling',
                                            style: TextStyle(
                                                color: HunterTheme.textPrimary.withOpacity(0.3),
                                                fontSize: 11,
                                                letterSpacing: 1,
                                            ),
                                        ),
                                        const SizedBox(height: 28),
                                        Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                                color: HunterTheme.cardColor,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: HunterTheme.primary.withOpacity(0.25),
                                                    width: 1,
                                                ),
                                            ),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    _sectionLabel('IDENTITY'),
                                                    const SizedBox(height: 12),
                                                    _HunterTextField(
                                                        controller: nameController,
                                                        label: 'Hunter Name',
                                                        icon: Icons.person_outline,
                                                        keyboardType: TextInputType.text,
                                                    ),
                                                    const SizedBox(height: 14),
                                                    _HunterTextField(
                                                        controller: ageController,
                                                        label: 'Age',
                                                        icon: Icons.calendar_today_outlined,
                                                        keyboardType: TextInputType.number,
                                                    ),
                                                    const SizedBox(height: 22),
                                                    _sectionLabel('PHYSICAL DATA'),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                        children: [
                                                            Expanded(
                                                                child: _HunterTextField(
                                                                    controller: heightController,
                                                                    label: 'Height (cm)',
                                                                    icon: Icons.height,
                                                                    keyboardType: TextInputType.number,
                                                                ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                                child: _HunterTextField(
                                                                    controller: weightController,
                                                                    label: 'Weight (kg)',
                                                                    icon: Icons.monitor_weight_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 28),
                                        GestureDetector(
                                            onTap: () async {
                                                if (nameController.text.trim().isEmpty ||
                                                    ageController.text.trim().isEmpty ||
                                                    heightController.text.trim().isEmpty ||
                                                    weightController.text.trim().isEmpty) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                            backgroundColor: HunterTheme.cardColor,
                                                            shape: RoundedRectangleBorder(
                                                                side: const BorderSide(
                                                                    color: Colors.redAccent, width: 1),
                                                                borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            content: const Text(
                                                                '[ ERROR ] Please complete all Hunter data.',
                                                                style: TextStyle(
                                                                    color: Colors.redAccent,
                                                                    letterSpacing: 0.5,
                                                                    fontWeight: FontWeight.w600,
                                                                ),
                                                            ),
                                                        ),
                                                    );
                                                    return;
                                                }

                                                final user = FirebaseAuth.instance.currentUser;
                                                if (user != null) {
                                                    final hunterName = nameController.text.trim();

                                                    final existing = await FirebaseFirestore.instance
                                                        .collection('hunters')
                                                        .where('hunterName', isEqualTo: hunterName)
                                                        .limit(1)
                                                        .get();

                                                    if (!mounted) return;
                                                    if (existing.docs.isNotEmpty) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                                content: Text('Hunter name already exists'),
                                                            ),
                                                        );
                                                        return;
                                                    }

                                                    await FirebaseFirestore.instance
                                                        .collection('hunters')
                                                        .doc(user.uid)
                                                        .update({
                                                        'hunterName': hunterName,
                                                        'age': int.parse(ageController.text),
                                                        'height': double.parse(heightController.text),
                                                        'weight': double.parse(weightController.text),
                                                        'startingWeight': double.parse(weightController.text),
                                                        'onboardingComplete': true,
                                                    });
                                                }

                                                if (!mounted) return;
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) => const ScanningScreen(),
                                                    ),
                                                );
                                            },
                                            child: Container(
                                                width: double.infinity,
                                                height: 54,
                                                decoration: BoxDecoration(
                                                    color: HunterTheme.primary,
                                                    borderRadius: BorderRadius.circular(6),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: HunterTheme.primary.withOpacity(0.4),
                                                            blurRadius: 22,
                                                            spreadRadius: 2,
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Icon(Icons.radar,
                                                            color: HunterTheme.background, size: 18),
                                                        SizedBox(width: 10),
                                                        Text(
                                                            'INITIATE SCAN',
                                                            style: TextStyle(
                                                                color: HunterTheme.background,
                                                                fontWeight: FontWeight.w800,
                                                                fontSize: 14,
                                                                letterSpacing: 2,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 32),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _dot(double opacity) {
        return Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: HunterTheme.primary.withOpacity(opacity),
                boxShadow: [
                    BoxShadow(
                        color: HunterTheme.primary.withOpacity(0.8),
                        blurRadius: 6,
                    ),
                ],
            ),
        );
    }

    Widget _sectionLabel(String label) {
        return Row(
            children: [
                Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                        color: HunterTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                            BoxShadow(
                                color: HunterTheme.primary.withOpacity(0.6),
                                blurRadius: 6,
                            ),
                        ],
                    ),
                ),
                const SizedBox(width: 8),
                Text(
                    label,
                    style: TextStyle(
                        color: HunterTheme.textPrimary.withOpacity(0.4),
                        fontSize: 10,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                    ),
                ),
            ],
        );
    }
}

class _HunterTextField extends StatefulWidget {
    final TextEditingController controller;
    final String label;
    final IconData icon;
    final TextInputType keyboardType;

    const _HunterTextField({
        required this.controller,
        required this.label,
        required this.icon,
        required this.keyboardType,
    });

    @override
    State<_HunterTextField> createState() => _HunterTextFieldState();
}

class _HunterTextFieldState extends State<_HunterTextField> {
    bool _focused = false;

    @override
    Widget build(BuildContext context) {
        return Focus(
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: TextField(
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                ),
                cursorColor: HunterTheme.primary,
                decoration: InputDecoration(
                    labelText: widget.label,
                    labelStyle: TextStyle(
                        color: _focused
                            ? HunterTheme.primary
                            : HunterTheme.textPrimary.withOpacity(0.35),
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(
                        widget.icon,
                        color: _focused
                            ? HunterTheme.primary
                            : HunterTheme.textPrimary.withOpacity(0.25),
                        size: 16,
                    ),
                    filled: true,
                    fillColor: _focused
                        ? HunterTheme.primary.withOpacity(0.05)
                        : HunterTheme.background,
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: HunterTheme.primary.withOpacity(0.2),
                            width: 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: HunterTheme.primary,
                            width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                    ),
                ),
            ),
        );
    }
}

class _GridPainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
        final paint = Paint()
            ..color = HunterTheme.primary.withOpacity(0.03)
            ..strokeWidth = 0.5;

        const spacing = 40.0;
        for (double x = 0; x <= size.width; x += spacing) {
            canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = 0; y <= size.height; y += spacing) {
            canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}