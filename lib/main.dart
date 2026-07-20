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
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/hive_init.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/widgets/connectivity_banner.dart';
import 'dart:math' as math;
import 'package:facebook_app_events/facebook_app_events.dart';

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
                'onboardingComplete': false,
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
    ConnectivityService.instance.start();

    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
    );

    bool hasCompletedSetup = false;
    User? initialUser;
    try {
        await Firebase.initializeApp();
        initialUser = FirebaseAuth.instance.currentUser;
        debugPrint("USER ON STARTUP: ${initialUser?.uid}");

        await createHunterProfile();
        await MembershipService.instance.loadMembership();
        await MobileAds.instance.initialize();

        final prefs = await SharedPreferences.getInstance();
        hasCompletedSetup = prefs.getBool('hasCompletedSetup') ?? false;

        // One-time migration: force Dark Mode for all users on this update.
        // After this runs once, users can freely switch themes in Settings.
        final migrated = prefs.getBool('themeMigrationCompleted') ?? false;
        if (!migrated) {
            await prefs.setBool('darkMode', true);
            await prefs.setBool('themeMigrationCompleted', true);
        }

        final isDarkMode = prefs.getBool('darkMode') ?? false;
        HunterTheme.isDark = isDarkMode;
        themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

        // Load and validate the user's selected premium dark theme.
        await ThemeService.instance.initialize();

        // Initialize Hive local cache.
        await HiveInit.initialize();
    } catch (e) {
        debugPrint("startup: $e");
    }

    runApp(HunterAscendApp(hasCompletedSetup: hasCompletedSetup, initialUser: initialUser));

    // Runs after the first frame is already showing — these aren't needed
    // to create the account or render the app, so they no longer block startup.
    _deferredInit();
}

Future<void> _deferredInit() async {
    try {
        await NotificationService().init();
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
            final doc = await FirebaseFirestore.instance.collection('hunters').doc(uid).get();
            final pref = (doc.data()?['notificationTime'] ?? '').toString();
            await NotificationService().scheduleForPreference(pref);
        }
        await FacebookAppEvents().logEvent(name: 'fb_mobile_activate_app');
    } catch (e) {
        debugPrint("deferredInit: $e");
    }
}

/// Root widget: wires global theme + auth gating into [MaterialApp].
class HunterAscendApp extends StatelessWidget {
    final bool hasCompletedSetup;
    final User? initialUser;

    const HunterAscendApp({super.key, required this.hasCompletedSetup, this.initialUser});

    @override
    Widget build(BuildContext context) {
        return ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
                HunterTheme.isDark = mode == ThemeMode.dark;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: HunterTheme.isDark ? Brightness.light : Brightness.dark,
                        systemNavigationBarIconBrightness: HunterTheme.isDark ? Brightness.light : Brightness.dark,
                    ),
                    child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    scaffoldMessengerKey: ThemeService.scaffoldMessengerKey,
                    title: 'Hunter Ascend',
                    theme: HunterTheme.lightTheme,
                    darkTheme: HunterTheme.darkTheme,
                    themeMode: mode,

                    builder: (context, child) {
                        return ConnectivityBanner(
                            child: MediaQuery(
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
                            ),
                        );
                    },

                    home: initialUser != null
                        ? _HunterProfileLoader(uid: initialUser!.uid)
                        : StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, snapshot) {
                            debugPrint("AUTH USER: ${snapshot.data?.uid}");

                            if (snapshot.connectionState == ConnectionState.waiting) {
                                return const _LoadingScreen();
                            }

                            if (snapshot.hasData) {
                                return _HunterProfileLoader(uid: snapshot.data!.uid);
                            }

                            return const LoginScreen();
                        },
                    ),
                    ),
                );
            },
        );
    }
}

/// Loads the hunter profile from Firestore with a working Retry mechanism.
/// Stateful so that [_retry] creates a genuinely new Future (not reusing the
/// FutureBuilder's cached failed snapshot).
class _HunterProfileLoader extends StatefulWidget {
    final String uid;
    const _HunterProfileLoader({required this.uid});

    @override
    State<_HunterProfileLoader> createState() => _HunterProfileLoaderState();
}

class _HunterProfileLoaderState extends State<_HunterProfileLoader> {
    late Future<DocumentSnapshot> _future;

    @override
    void initState() {
        super.initState();
        _future = _loadProfile();
    }

    Future<DocumentSnapshot> _loadProfile() {
        return FirebaseFirestore.instance
            .collection('hunters')
            .doc(widget.uid)
            .get();
    }

    void _retry() {
        setState(() {
            _future = _loadProfile();
        });
    }

    @override
    Widget build(BuildContext context) {
        return FutureBuilder<DocumentSnapshot>(
            future: _future,
            builder: (context, hunterSnapshot) {
                if (hunterSnapshot.hasError) {
                    return _NoInternetScreen(onRetry: _retry);
                }
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

/// Shown when the app starts with no internet and no cached Firestore data.
class _NoInternetScreen extends StatelessWidget {
    final VoidCallback onRetry;
    const _NoInternetScreen({required this.onRetry});

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            backgroundColor: HunterTheme.background,
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.wifi_off, size: 64, color: HunterTheme.textSecondary),
                            const SizedBox(height: 24),
                            Text(
                                "No Internet Connection",
                                style: TextStyle(
                                    color: HunterTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                                "Hunter Ascend requires an internet connection to play.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: HunterTheme.textSecondary,
                                    fontSize: 14,
                                ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: HunterTheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: onRetry,
                                child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                        ],
                    ),
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
    final targetWeightController = TextEditingController();

    late AnimationController _fadeController;
    late AnimationController _pulseController;
    late Animation<double> _fadeAnim;
    late Animation<double> _pulseAnim;

    // ── Hunter Name availability check ──
    Timer? _nameCheckTimer;
    // null = nothing shown, true = available, false = taken
    bool? _nameAvailable;
    bool _nameChecking = false;
    bool _nameCheckError = false;

    // ── Field validation errors ──
    String? _ageError;
    String? _heightError;
    String? _weightError;
    String? _targetWeightError;

    @override
    void initState() {
        super.initState();

        nameController.addListener(_onNameChanged);
        ageController.addListener(_validateAge);
        heightController.addListener(_validateHeight);
        weightController.addListener(_validateWeight);
        targetWeightController.addListener(_validateTargetWeight);

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
        _nameCheckTimer?.cancel();
        _fadeController.dispose();
        _pulseController.dispose();
        nameController.dispose();
        ageController.dispose();
        heightController.dispose();
        weightController.dispose();
        targetWeightController.dispose();
        super.dispose();
    }

    void _onNameChanged() {
        _nameCheckTimer?.cancel();
        final name = nameController.text.trim();

        if (name.length < 3) {
            setState(() {
                _nameAvailable = null;
                _nameChecking = false;
                _nameCheckError = false;
            });
            return;
        }

        setState(() {
            _nameChecking = true;
            _nameCheckError = false;
        });

        _nameCheckTimer = Timer(const Duration(milliseconds: 400), () async {
            final nameKey = name.toLowerCase();
            try {
                final doc = await FirebaseFirestore.instance
                    .collection('hunterNames')
                    .doc(nameKey)
                    .get();
                if (!mounted) return;
                setState(() {
                    _nameAvailable = !doc.exists;
                    _nameChecking = false;
                });
            } catch (_) {
                if (!mounted) return;
                setState(() {
                    _nameAvailable = null;
                    _nameChecking = false;
                    _nameCheckError = true;
                });
            }
        });
    }

    void _validateAge() {
        final text = ageController.text.trim();
        String? error;
        if (text.isEmpty) {
            error = 'Age is required';
        } else {
            final age = int.tryParse(text);
            if (age == null || age < 13 || age > 100) {
                error = 'Enter a valid age (13\u2013100)';
            }
        }
        if (error != _ageError) setState(() => _ageError = error);
    }

    void _validateHeight() {
        final text = heightController.text.trim();
        String? error;
        if (text.isEmpty) {
            error = 'Height is required';
        } else {
            final h = double.tryParse(text);
            if (h == null || h < 100 || h > 250) {
                error = 'Enter a valid height (100\u2013250 cm)';
            }
        }
        if (error != _heightError) setState(() => _heightError = error);
    }

    void _validateWeight() {
        final text = weightController.text.trim();
        String? error;
        if (text.isEmpty) {
            error = 'Weight is required';
        } else {
            final w = double.tryParse(text);
            if (w == null || w < 20 || w > 300) {
                error = 'Enter a valid weight (20\u2013300 kg)';
            }
        }
        if (error != _weightError) setState(() => _weightError = error);
    }

    void _validateTargetWeight() {
        final text = targetWeightController.text.trim();
        String? error;
        if (text.isEmpty) {
            error = 'Target weight is required';
        } else {
            final w = double.tryParse(text);
            if (w == null || w < 20 || w > 300) {
                error = 'Enter a valid weight (20\u2013300 kg)';
            }
        }
        if (error != _targetWeightError) setState(() => _targetWeightError = error);
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
                                                gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [HunterTheme.primary.withOpacity(0.06), HunterTheme.cardColor],
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: HunterTheme.primary.withOpacity(0.25),
                                                    width: 1,
                                                ),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: HunterTheme.primary.withOpacity(0.08 * HunterTheme.glowStrength),
                                                        blurRadius: 18,
                                                        offset: const Offset(0, 6),
                                                    ),
                                                ],
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
                                                    // ── Live availability indicator ──
                                                    if (_nameChecking)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 8),
                                                            child: Row(
                                                                children: [
                                                                    SizedBox(
                                                                        width: 12,
                                                                        height: 12,
                                                                        child: CircularProgressIndicator(
                                                                            strokeWidth: 1.5,
                                                                            color: HunterTheme.primary,
                                                                        ),
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    Text(
                                                                        'Checking...',
                                                                        style: TextStyle(
                                                                            color: HunterTheme.textTertiary,
                                                                            fontSize: 12,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        )
                                                    else if (_nameAvailable == true)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 8),
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.check_circle,
                                                                        color: HunterTheme.success, size: 14),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                        'Hunter Name available',
                                                                        style: TextStyle(
                                                                            color: HunterTheme.success,
                                                                            fontSize: 12,
                                                                            fontWeight: FontWeight.w600,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        )
                                                    else if (_nameAvailable == false)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 8),
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.cancel,
                                                                        color: HunterTheme.danger, size: 14),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                        'Hunter Name already taken',
                                                                        style: TextStyle(
                                                                            color: HunterTheme.danger,
                                                                            fontSize: 12,
                                                                            fontWeight: FontWeight.w600,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        )
                                                    else if (_nameCheckError)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 8),
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.warning_amber_rounded,
                                                                        color: HunterTheme.gold, size: 14),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                        'Unable to verify Hunter Name',
                                                                        style: TextStyle(
                                                                            color: HunterTheme.gold,
                                                                            fontSize: 12,
                                                                            fontWeight: FontWeight.w600,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        ),
                                                    const SizedBox(height: 14),
                                                    _HunterTextField(
                                                        controller: ageController,
                                                        label: 'Age',
                                                        icon: Icons.calendar_today_outlined,
                                                        keyboardType: TextInputType.number,
                                                    ),
                                                    if (_ageError != null)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 6),
                                                            child: Row(
                                                                children: [
                                                                    Icon(Icons.error_outline,
                                                                        color: HunterTheme.danger, size: 13),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                        _ageError!,
                                                                        style: TextStyle(
                                                                            color: HunterTheme.danger,
                                                                            fontSize: 11,
                                                                            fontWeight: FontWeight.w600,
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
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
                                                    if (_heightError != null || _weightError != null)
                                                        Padding(
                                                            padding: const EdgeInsets.only(top: 6),
                                                            child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                    if (_heightError != null)
                                                                        Padding(
                                                                            padding: const EdgeInsets.only(bottom: 4),
                                                                            child: Row(
                                                                                children: [
                                                                                    Icon(Icons.error_outline,
                                                                                        color: HunterTheme.danger, size: 13),
                                                                                    const SizedBox(width: 6),
                                                                                    Text(
                                                                                        _heightError!,
                                                                                        style: TextStyle(
                                                                                            color: HunterTheme.danger,
                                                                                            fontSize: 11,
                                                                                            fontWeight: FontWeight.w600,
                                                                                        ),
                                                                                    ),
                                                                                ],
                                                                            ),
                                                                        ),
                                                                    if (_weightError != null)
                                                                        Row(
                                                                            children: [
                                                                                Icon(Icons.error_outline,
                                                                                    color: HunterTheme.danger, size: 13),
                                                                                const SizedBox(width: 6),
                                                                                Text(
                                                                                    _weightError!,
                                                                                    style: TextStyle(
                                                                                        color: HunterTheme.danger,
                                                                                        fontSize: 11,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ],
                                                                        ),
                                                                ],
                                                            ),
                                                        ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 14),
                                        _HunterTextField(
                                            controller: targetWeightController,
                                            label: 'Target Weight (kg)',
                                            icon: Icons.flag_outlined,
                                            keyboardType: TextInputType.number,
                                        ),
                                        if (_targetWeightError != null)
                                            Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Row(
                                                    children: [
                                                        Icon(Icons.error_outline,
                                                            color: HunterTheme.danger, size: 13),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                            _targetWeightError!,
                                                            style: TextStyle(
                                                                color: HunterTheme.danger,
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Text(
                                                'Your ideal goal weight. You can change this later.',
                                                style: TextStyle(
                                                    color: HunterTheme.textTertiary,
                                                    fontSize: 10.5,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 28),
                                        GestureDetector(
                                            onTap: () async {
                                                // Run all validators to show errors.
                                                _validateAge();
                                                _validateHeight();
                                                _validateWeight();
                                                _validateTargetWeight();

                                                final nameEmpty = nameController.text.trim().isEmpty;
                                                final hasErrors = nameEmpty ||
                                                    _ageError != null ||
                                                    _heightError != null ||
                                                    _weightError != null ||
                                                    _targetWeightError != null;

                                                if (hasErrors) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                            backgroundColor: HunterTheme.cardColor,
                                                            shape: RoundedRectangleBorder(
                                                                side: BorderSide(
                                                                    color: HunterTheme.danger, width: 1),
                                                                borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            content: Text(
                                                                '[ ERROR ] Please fix the highlighted fields.',
                                                                style: TextStyle(
                                                                    color: HunterTheme.danger,
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

                                                    // Doc IDs can't contain '/', so reject names that would
                                                    // break the reservation lookup instead of silently mangling them.
                                                    if (hunterName.contains('/')) {
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                                content: Text('Hunter name cannot contain "/"'),
                                                            ),
                                                        );
                                                        return;
                                                    }

                                                    // Case-insensitive uniqueness key. Doc ID = the name itself,
                                                    // so only one transaction can ever successfully create it —
                                                    // this closes the race the old query-then-write check had.
                                                    final nameKey = hunterName.toLowerCase();
                                                    final nameRef = FirebaseFirestore.instance
                                                        .collection('hunterNames')
                                                        .doc(nameKey);
                                                    final hunterRef = FirebaseFirestore.instance
                                                        .collection('hunters')
                                                        .doc(user.uid);

                                                    bool nameTaken = false;
                                                    try {
                                                        await FirebaseFirestore.instance.runTransaction((txn) async {
                                                            final nameSnap = await txn.get(nameRef);
                                                            if (nameSnap.exists) {
                                                                nameTaken = true;
                                                                return;
                                                            }
                                                            txn.set(nameRef, {
                                                                'uid': user.uid,
                                                                'hunterName': hunterName,
                                                            });
                                                            txn.update(hunterRef, {
                                                                'hunterName': hunterName,
                                                                'age': int.parse(ageController.text),
                                                                'height': double.parse(heightController.text),
                                                                'weight': double.parse(weightController.text),
                                                                'startingWeight': double.parse(weightController.text),
                                                                'targetWeight': double.parse(targetWeightController.text),
                                                                'onboardingComplete': true,
                                                            });
                                                        });
                                                    } catch (e) {
                                                        debugPrint("hunterName transaction: $e");
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                                content: Text('Something went wrong. Please try again.'),
                                                            ),
                                                        );
                                                        return;
                                                    }

                                                    if (!mounted) return;
                                                    if (nameTaken) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                                content: Text('Hunter name already exists'),
                                                            ),
                                                        );
                                                        return;
                                                    }
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
                                                height: 56,
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: HunterTheme.primaryGradient,
                                                    ),
                                                    borderRadius: BorderRadius.circular(14),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: HunterTheme.primary.withOpacity(0.4 * HunterTheme.glowStrength),
                                                            blurRadius: 22,
                                                            spreadRadius: 2,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                        Icon(Icons.radar,
                                                            color: Colors.black, size: 18),
                                                        SizedBox(width: 10),
                                                        Text(
                                                            'INITIATE SCAN',
                                                            style: TextStyle(
                                                                color: Colors.black,
                                                                fontWeight: FontWeight.w900,
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
                    width: 4,
                    height: 14,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: HunterTheme.primaryGradient,
                        ),
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