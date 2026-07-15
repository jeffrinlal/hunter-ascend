import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/screens/duel/duel_history_screen.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hunter_ascend/core/constants/app_constants.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Form to create/send a duel challenge to another hunter.
class CreateDuelScreen extends StatefulWidget {
  final String? hunterName;

  const CreateDuelScreen({
    super.key,
    this.hunterName,
  });

  @override
  State<CreateDuelScreen> createState() => _CreateDuelScreenState();
}

class _CreateDuelScreenState extends State<CreateDuelScreen> {
  final TextEditingController hunterNameController = TextEditingController();
  final TextEditingController questController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> duelQuests = [];

  // ── Duel Settings ────────────────────────────────────────────────────
  int _selectedDuration = 3; // days (1-6)
  String _selectedDifficulty = 'Medium'; // Easy | Medium | Hard

  // ── AI Duel Quest generation ────────────────────────────────────────
  int _aiQuestCount = 4; // 4-6
  bool _isGeneratingAI = false;
  List<Map<String, dynamic>> _aiGeneratedQuests = [];

  // ── Live opponent Hunter lookup ─────────────────────────────────────
  Timer? _hunterLookupTimer;
  // null = nothing shown, true = found, false = not found
  bool? _opponentFound;
  bool _opponentChecking = false;
  bool _opponentCheckError = false;

  // ── Rewarded ad (reuses the same google_mobile_ads RewardedAd flow
  // used elsewhere in the app, e.g. dashboard streak-recovery ad) ────────
  RewardedAd? _duelRewardedAd;
  bool _isDuelRewardedAdReady = false;

  @override
  void initState() {
    super.initState();

    if (widget.hunterName != null) {
      hunterNameController.text = widget.hunterName!;
    }

    hunterNameController.addListener(_onOpponentNameChanged);
    _loadDuelRewardedAd();

    // Trigger initial check if a name was pre-filled.
    if (hunterNameController.text.trim().length >= 3) {
      _onOpponentNameChanged();
    }
  }

  @override
  void dispose() {
    _hunterLookupTimer?.cancel();
    hunterNameController.dispose();
    questController.dispose();
    _duelRewardedAd?.dispose();
    super.dispose();
  }

  void _onOpponentNameChanged() {
    _hunterLookupTimer?.cancel();
    final name = hunterNameController.text.trim();

    if (name.length < 3) {
      setState(() {
        _opponentFound = null;
        _opponentChecking = false;
        _opponentCheckError = false;
      });
      return;
    }

    setState(() {
      _opponentChecking = true;
      _opponentCheckError = false;
    });

    _hunterLookupTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await FirebaseFirestore.instance
            .collection('hunters')
            .where('hunterName', isEqualTo: name)
            .limit(1)
            .get();
        if (!mounted) return;
        setState(() {
          _opponentFound = result.docs.isNotEmpty;
          _opponentChecking = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _opponentFound = null;
          _opponentChecking = false;
          _opponentCheckError = true;
        });
      }
    });
  }

  void addQuest() {
    String questName = questController.text.trim();
    if (questName.isEmpty) return;

    bool alreadyExists = duelQuests.any(
          (quest) =>
      quest['name'].toString().toLowerCase() == questName.toLowerCase(),
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mission already added")),
      );
      return;
    }

    if (duelQuests.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 10 missions allowed")),
      );
      return;
    }

    setState(() {
      duelQuests.add({'name': questName, 'xp': 50});
    });
    questController.clear();
  }

  void deleteQuest(int index) {
    setState(() {
      duelQuests.removeAt(index);
    });
  }

  Future<void> _submitDuel() async {
    if (_isSubmitting) return;
    if (!await ConnectivityService.isOnline()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet connection required.")));
      return;
    }
    _isSubmitting = true;
    try {
      // ── Auth check first ──────────────────────────────────────────
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to challenge")),
        );
        return;
      }

      if (hunterNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a Hunter Name")),
        );
        return;
      }

      if (_opponentFound != true) {
        if (_opponentChecking) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please wait — verifying Hunter Name...")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hunter not found. Check the name and try again.")),
          );
        }
        return;
      }

      if (duelQuests.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Minimum 4 missions required")),
        );
        return;
      }


      final targetResult = await FirebaseFirestore.instance
          .collection('hunters')
          .where(
        'hunterName',
        isEqualTo: hunterNameController.text.trim(),
      )
          .limit(1)
          .get();

      if (!mounted) return;
      if (targetResult.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hunter not found")),
        );
        return;
      }

      final targetHunter = targetResult.docs.first;
      final opponentId = targetHunter.id;
      if (opponentId == user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You cannot challenge yourself")),
        );
        return;
      }

      // ── Optimised active-duel check (two targeted queries) ────────


      final activeDuelAsPlayer1 = await FirebaseFirestore.instance
          .collection('duels')
          .where('player1', isEqualTo: opponentId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      final activeDuelAsPlayer2 = await FirebaseFirestore.instance
          .collection('duels')
          .where('player2', isEqualTo: opponentId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      final targetHasActiveDuel =
          activeDuelAsPlayer1.docs.isNotEmpty ||
              activeDuelAsPlayer2.docs.isNotEmpty;

      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('duel_requests')
          .where('toUid', isEqualTo: opponentId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (!mounted) return;
      if (targetHasActiveDuel) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hunter is already in a duel")),
        );
        return;
      }

      if (pendingSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hunter already has a pending challenge")),
        );
        return;
      }

      final myHunterDoc = await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .get();

      final myHunterName =
          myHunterDoc.data()?['hunterName'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('duel_requests').add({
        'fromUid': user.uid,
        'toUid': opponentId,

        'fromHunterName': myHunterName,
        'toHunterName': targetHunter['hunterName'],

        'status': 'pending',
        'duelQuests': duelQuests,
        'durationDays': _selectedDuration,
        'difficulty': _selectedDifficulty,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚔️ Duel challenge sent!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("submitDuel: $e");
    } finally {
      _isSubmitting = false;
    }
  }


  Future<void> _inviteFriends() async {
    await Share.share(
      "⚔️ I've challenged you!\n\n"
          "Think you can beat me?\n\n"
          "Download Hunter Ascend, complete real-life fitness quests, earn XP, level up, and challenge me in a duel!\n\n"
          "📲 Download now:\n"
          "https://play.google.com/store/apps/details?id=com.hunterascend.hunter_ascend",
      subject: "Join me on Hunter Ascend!",
    );
  }

  // ── AI Duel Quest generation ────────────────────────────────────────

  /// Loads (or reloads) the rewarded ad used to grant an extra AI
  /// regeneration once the daily free regeneration has been used.
  void _loadDuelRewardedAd() {
    // Max tier has no rewarded ads — _showRewardedAdForRegen() grants the
    // regeneration directly for these hunters, so there's nothing to load.
    if (!MembershipService.instance.showRewardedAds) return;

    RewardedAd.load(
      adUnitId: AppConstants.streakRecoveryRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _duelRewardedAd = ad;
          if (mounted) setState(() => _isDuelRewardedAdReady = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint("DUEL REWARDED AD FAILED: $error");
          _isDuelRewardedAdReady = false;
        },
      ),
    );
  }

  void _showRewardedAdForRegen(Future<void> Function() onEarned) {
    if (!MembershipService.instance.showRewardedAds) {
      // Max tier: no rewarded ads — grant the bonus regeneration directly.
      onEarned();
      return;
    }
    if (!_isDuelRewardedAdReady || _duelRewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad not ready yet — try again in a moment.")),
      );
      _loadDuelRewardedAd();
      return;
    }
    _duelRewardedAd!.show(onUserEarnedReward: (ad, reward) {
      onEarned();
    });
    _duelRewardedAd = null;
    _isDuelRewardedAdReady = false;
    _loadDuelRewardedAd();
  }

  Future<Map<String, dynamic>?> _fetchHunterDataByUid(String uid) async {
    final doc =
    await FirebaseFirestore.instance.collection('hunters').doc(uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> _fetchHunterDataByName(String name) async {
    final result = await FirebaseFirestore.instance
        .collection('hunters')
        .where('hunterName', isEqualTo: name)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    return result.docs.first.data();
  }

  String _goalsStringFrom(Map<String, dynamic> data) {
    final List<String> goals = [];
    if (data['fatLoss'] == true) goals.add('Fat Loss');
    if (data['discipline'] == true) goals.add('Discipline');
    if (data['muscleGain'] == true) goals.add('Muscle Gain');
    if (data['selfImprovement'] == true) goals.add('Self Improvement');
    return goals.isEmpty ? 'General Fitness' : goals.join(', ');
  }

  /// Checks whether the current hunter still has today's free AI
  /// regeneration available, by reading `lastFreeRegenerationDate` off the
  /// existing hunter document (no new collection created).
  Future<bool> _isFreeRegenAvailable() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('hunters')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    final today = DateTime.now().toIso8601String().split('T').first;
    return data['lastFreeRegenerationDate'] != today;
  }

  /// Atomically consumes today's free regeneration (if still available) by
  /// stamping `lastFreeRegenerationDate` on the hunter document. Returns
  /// true only if this call was the one that consumed it.
  Future<bool> _tryConsumeFreeRegen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final ref =
    FirebaseFirestore.instance.collection('hunters').doc(user.uid);
    final today = DateTime.now().toIso8601String().split('T').first;
    bool consumed = false;
    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final data = snap.data() ?? {};
      if (data['lastFreeRegenerationDate'] != today) {
        txn.update(ref, {'lastFreeRegenerationDate': today});
        consumed = true;
      }
    });
    return consumed;
  }

  /// Calls the existing Hunter Ascend AI proxy (same Cloudflare Worker used
  /// by AIQuestService) to generate fair, balanced duel quests for both
  /// hunters. Bodyweight only, scaled to difficulty + duration.
  Future<List<Map<String, dynamic>>> _generateDuelQuestsAI({
    required Map<String, dynamic> hunterA,
    required Map<String, dynamic> hunterB,
    required int questCount,
    required String difficulty,
    required int durationDays,
  }) async {
    final String userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    final prompt = """
Generate exactly $questCount fair PvP duel quests for two hunters competing against each other over $durationDays day(s).

Hunter A:
Age: ${hunterA['age'] ?? 'unknown'}
Height: ${hunterA['height'] ?? 'unknown'} cm
Weight: ${hunterA['weight'] ?? 'unknown'} kg
Goal: ${_goalsStringFrom(hunterA)}
Fitness Level: ${hunterA['level'] ?? 1}

Hunter B:
Age: ${hunterB['age'] ?? 'unknown'}
Height: ${hunterB['height'] ?? 'unknown'} cm
Weight: ${hunterB['weight'] ?? 'unknown'} kg
Goal: ${_goalsStringFrom(hunterB)}
Fitness Level: ${hunterB['level'] ?? 1}

Difficulty: $difficulty
Duration: $durationDays day(s)

Rules:
- Bodyweight only, no gym equipment
- Fair and balanced for BOTH hunters regardless of their individual stats
- Safe for both fitness levels
- No dangerous activities, no medical advice, no extreme exercise
- If duration is more than 1 day, scale each target into a cumulative goal across all $durationDays days
- All quest titles MUST be unique
- Match overall intensity to the "$difficulty" difficulty setting

Return ONLY a JSON array, no markdown, no explanation:
[
  {"title": "Push-ups", "xp": 50, "target": "100 push-ups total"}
]
""";

    final response = await http.post(
      Uri.parse('https://hunter-ascend-ai.jefferinlal.workers.dev/mistral'),
      headers: {
        'Content-Type': 'application/json',
        'X-User-Id': userId,
      },
      body: jsonEncode({
        "model": "mistral-small-latest",
        "messages": [
          {"role": "user", "content": prompt}
        ]
      }),
    );

    final data = jsonDecode(response.body);
    String content = data['choices'][0]['message']['content'];
    content = content.replaceAll('```json', '').replaceAll('```', '').trim();

    final parsed = jsonDecode(content);
    if (parsed is List) {
      return parsed.map<Map<String, dynamic>>((q) {
        final rawXp = q['xp'];
        final xp = rawXp is int
            ? rawXp
            : int.tryParse(rawXp?.toString() ?? '') ?? 50;
        return {
          'name': q['title']?.toString() ?? 'Quest',
          'xp': xp,
          'target': q['target']?.toString() ?? '',
        };
      }).toList();
    }
    return [];
  }

  void _showOpponentRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _hunterAlertDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: HunterTheme.dangerAlt,
        title: '⚠ Opponent Required',
        message:
        "Please enter your opponent's Hunter Name before generating AI duel quests.",
        actions: [
          _dialogButton(ctx, 'OK', () => Navigator.pop(ctx), primary: true),
        ],
      ),
    );
  }

  Future<void> _openAiGenerateDialog() async {
    if (hunterNameController.text.trim().isEmpty) {
      _showOpponentRequiredDialog();
      return;
    }
    if (_opponentFound != true) {
      if (_opponentChecking) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please wait — verifying Hunter Name...")),
        );
      } else {
        _showOpponentRequiredDialog();
      }
      return;
    }

    int tempCount = _aiQuestCount;

    final generate = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _hunterAlertDialog(
          icon: Icons.smart_toy_rounded,
          iconColor: HunterTheme.primary,
          title: '🤖 Generate AI Duel Quests',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('QUEST COUNT', style: _dialogLabelStyle()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [4, 5, 6]
                    .map((c) => _selectableChip(
                  label: '$c',
                  selected: tempCount == c,
                  onTap: () => setDialogState(() => tempCount = c),
                ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              _summaryRow(Icons.speed, 'Difficulty', _selectedDifficulty),
              const SizedBox(height: 8),
              _summaryRow(Icons.calendar_today, 'Duration',
                  '$_selectedDuration Day${_selectedDuration > 1 ? 's' : ''}'),
            ],
          ),
          actions: [
            _dialogButton(ctx, 'Cancel', () => Navigator.pop(ctx, false)),
            const SizedBox(width: 10),
            _dialogButton(ctx, 'Generate', () => Navigator.pop(ctx, true),
                primary: true),
          ],
        ),
      ),
    );

    if (generate == true) {
      setState(() => _aiQuestCount = tempCount);
      await _runAiGeneration();
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HunterTheme.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: HunterTheme.primary.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                      color: HunterTheme.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  '🤖 Analyzing Both Hunters...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Creating balanced duel quests...',
                  textAlign: TextAlign.center,
                  style:
                  TextStyle(color: HunterTheme.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runAiGeneration() async {
    if (!await ConnectivityService.isOnline()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Internet connection required.")),
        );
      }
      return;
    }

    setState(() => _isGeneratingAI = true);
    _showLoadingDialog();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final myData = await _fetchHunterDataByUid(user.uid);
      final opponentData =
      await _fetchHunterDataByName(hunterNameController.text.trim());

      if (myData == null || opponentData == null) {
        if (mounted) Navigator.pop(context); // close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hunter not found")),
          );
        }
        return;
      }

      final quests = await _generateDuelQuestsAI(
        hunterA: myData,
        hunterB: opponentData,
        questCount: _aiQuestCount,
        difficulty: _selectedDifficulty,
        durationDays: _selectedDuration,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (quests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate quests. Try again.")),
        );
        return;
      }

      _aiGeneratedQuests = quests;
      final freeAvailable = await _isFreeRegenAvailable();
      if (!mounted) return;
      _showResultDialog(freeAvailable);
    } catch (e) {
      debugPrint("AI duel generation error: $e");
      if (mounted) Navigator.pop(context); // close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate quests. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAI = false);
    }
  }

  Future<void> _handleRegenerate(bool freeAvailable) async {
    if (freeAvailable) {
      final consumed = await _tryConsumeFreeRegen();
      if (consumed) {
        await _runAiGeneration();
        return;
      }
    }
    _showRewardedAdForRegen(() async {
      await _runAiGeneration();
    });
  }

  void _useGeneratedQuests() {
    setState(() {
      for (final q in _aiGeneratedQuests) {
        final target = (q['target'] ?? '').toString();
        final name = target.isNotEmpty ? '${q['name']} — $target' : q['name'].toString();

        final alreadyExists = duelQuests.any(
              (e) => e['name'].toString().toLowerCase() == name.toLowerCase(),
        );

        if (!alreadyExists && duelQuests.length < 10) {
          duelQuests.add({'name': name, 'xp': q['xp'] ?? 50});
        }
      }
      _aiGeneratedQuests = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ AI duel quests added")),
    );
  }

  void _showResultDialog(bool freeRegenAvailable) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HunterTheme.primary.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: HunterTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Duel Quests',
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children:
                    _aiGeneratedQuests.map((q) => _aiQuestCard(q)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _dialogButton(ctx, 'Cancel', () => Navigator.pop(ctx)),
                  const SizedBox(width: 10),
                  _dialogButton(ctx, 'Use These Quests', () {
                    Navigator.pop(ctx);
                    _useGeneratedQuests();
                  }, primary: true),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleRegenerate(freeRegenAvailable);
                  },
                  icon: Icon(Icons.refresh, color: HunterTheme.primary),
                  label: Text(
                    freeRegenAvailable
                        ? '🔄 Regenerate AI Quests  •  ✨ FREE ×1 Today'
                        : '🔄 Regenerate  •  🎥 Watch Rewarded Ad',
                    style: TextStyle(
                      color: HunterTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        backgroundColor: HunterTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.close, color: HunterTheme.dangerAlt, size: 20),
            SizedBox(width: 8),
            Text(
              'Create Duel',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: HunterTheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DuelHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // ── Arena banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    HunterTheme.pinkSurface,
                    HunterTheme.roseSurface,
                    HunterTheme.background,
                  ],
                ),
                border: Border.all(
                  color: HunterTheme.dangerAlt.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: HunterTheme.dangerAlt.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HunterTheme.dangerAlt.withOpacity(0.12),
                      border: Border.all(
                          color: HunterTheme.dangerAlt.withOpacity(0.4)),
                    ),
                    child: Icon(Icons.sports_kabaddi,
                        color: HunterTheme.dangerAlt, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'DUEL ARENA',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a rivalry and challenge another Hunter',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HunterTheme.textPrimary.withOpacity(0.55),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Your Hunter ID ─────────────────────────────
                    // 👇 Invite Friends Button
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _inviteFriends,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  HunterTheme.primary,
                                  HunterTheme.primary.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: HunterTheme.primary.withOpacity(0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.group_add,
                                  color: Colors.white,
                                  size: 28,
                                ),

                                const SizedBox(width: 14),

                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Invite Friends",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Tap here to challenge them to a duel",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    _sectionLabel('YOUR HUNTER NAME'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: HunterTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.fingerprint,
                              color: HunterTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('hunters')
                                  .doc(FirebaseAuth.instance.currentUser!.uid)
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return Text(
                                    'Loading...',
                                    style: TextStyle(color: HunterTheme.textTertiary),
                                  );
                                }

                                final data =
                                snapshot.data!.data() as Map<String, dynamic>?;

                                return SelectableText(
                                  data?['hunterName'] ?? 'Unknown Hunter',
                                  style: TextStyle(
                                    color: HunterTheme.primary,
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                );
                              },
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Opponent Hunter ID ─────────────────────────
                    _sectionLabel('OPPONENT HUNTER NAME'),
                    const SizedBox(height: 8),
                    _darkTextField(
                      controller: hunterNameController,
                      hint: 'Enter Hunter Name',
                      icon: Icons.person_search,
                    ),
                    // ── Live opponent lookup indicator ──
                    if (_opponentChecking)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: HunterTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Checking...',
                            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
                        ]),
                      )
                    else if (_opponentFound == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.check_circle, color: HunterTheme.success, size: 14),
                          const SizedBox(width: 6),
                          Text('Hunter found',
                            style: TextStyle(color: HunterTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      )
                    else if (_opponentFound == false)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.cancel, color: HunterTheme.danger, size: 14),
                          const SizedBox(width: 6),
                          Text('Hunter not found',
                            style: TextStyle(color: HunterTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      )
                    else if (_opponentCheckError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded, color: HunterTheme.gold, size: 14),
                          const SizedBox(width: 6),
                          Text('Unable to verify Hunter',
                            style: TextStyle(color: HunterTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),

                    const SizedBox(height: 20),

                    // ── Duel Settings ───────────────────────────────
                    _sectionLabel('DUEL SETTINGS'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: HunterTheme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event,
                                  size: 16, color: HunterTheme.primary),
                              const SizedBox(width: 8),
                              Text('📅 DUEL DURATION',
                                  style: _dialogLabelStyle()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(6, (i) {
                              final day = i + 1;
                              return _selectableChip(
                                label: day == 1 ? '1 Day' : '$day Days',
                                selected: _selectedDuration == day,
                                onTap: () =>
                                    setState(() => _selectedDuration = day),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.speed,
                                  size: 16, color: HunterTheme.primary),
                              const SizedBox(width: 8),
                              Text('DIFFICULTY', style: _dialogLabelStyle()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Easy', 'Medium', 'Hard']
                                .map((d) => _selectableChip(
                              label: d,
                              selected: _selectedDifficulty == d,
                              onTap: () => setState(
                                      () => _selectedDifficulty = d),
                            ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Add Quest ──────────────────────────────────
                    _sectionLabel('ADD MISSION'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _darkTextField(
                            controller: questController,
                            hint: 'Mission name',
                            icon: Icons.gps_fixed,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: addQuest,
                          child: Container(
                            width: 48,
                            height: 52,
                            decoration: BoxDecoration(
                              color: HunterTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: HunterTheme.primary
                                      .withOpacity(0.4)),
                            ),
                            child: Icon(Icons.add,
                                color: HunterTheme.primary),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── OR divider ───────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: HunterTheme.border, thickness: 1)),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: HunterTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: HunterTheme.border, thickness: 1)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Generate AI Duel Quests ─────────────────────
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isGeneratingAI ? null : _openAiGenerateDialog,
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                HunterTheme.primary,
                                HunterTheme.primary.withOpacity(0.75),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: HunterTheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.smart_toy_rounded,
                                  color: Colors.white, size: 26),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🤖 Generate AI Duel Quests',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Generate balanced quests based on both hunters.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isGeneratingAI)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              else
                                const Icon(Icons.arrow_forward_ios,
                                    color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Quest list header ──────────────────────────
                    Row(
                      children: [
                        _sectionLabel('CUSTOM DUEL MISSIONS'),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: duelQuests.length < 4
                                ? HunterTheme.dangerAlt.withOpacity(0.12)
                                : HunterTheme.successAlt.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: duelQuests.length < 4
                                  ? HunterTheme.dangerAlt.withOpacity(0.4)
                                  : HunterTheme.successAlt.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${duelQuests.length}/10',
                            style: TextStyle(
                              color: duelQuests.length < 4
                                  ? HunterTheme.dangerAlt
                                  : HunterTheme.successAlt,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Minimum quest hint
                    if (duelQuests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: HunterTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: HunterTheme.textPrimary.withOpacity(0.06)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_task,
                                color: HunterTheme.textFaint, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Add at least 4 missions to challenge',
                              style: TextStyle(
                                  color: HunterTheme.textTertiary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    // Quest items
                    ...List.generate(duelQuests.length, (index) {
                      final quest = duelQuests[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: HunterTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: HunterTheme.dangerAlt.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                HunterTheme.dangerAlt.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.gps_fixed,
                                  color: HunterTheme.dangerAlt, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quest['name'],
                                    style: TextStyle(
                                      color: HunterTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mission Objective',
                                    style: TextStyle(
                                      color: HunterTheme.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                HunterTheme.successAlt.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: HunterTheme.successAlt
                                        .withOpacity(0.3)),
                              ),
                              child: Text(
                                '+50 XP',
                                style: TextStyle(
                                  color: HunterTheme.successAlt,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => deleteQuest(index),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                  HunterTheme.dangerAlt.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    color: HunterTheme.dangerAlt, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Challenge button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    // Fix: previously used a white foreground on a plain
                    // card background before 4 missions were added, which
                    // made the label unreadable in Light Mode. Now uses a
                    // themed danger tint + matching text/border so the
                    // button stays clearly visible in both modes.
                    backgroundColor: duelQuests.length >= 4
                        ? HunterTheme.dangerAlt
                        : HunterTheme.dangerAlt.withOpacity(0.12),
                    foregroundColor: duelQuests.length >= 4
                        ? Colors.white
                        : HunterTheme.dangerAlt,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: HunterTheme.dangerAlt
                            .withOpacity(duelQuests.length >= 4 ? 1 : 0.4),
                      ),
                    ),
                    elevation: duelQuests.length >= 4 ? 8 : 0,
                    shadowColor: HunterTheme.dangerAlt.withOpacity(0.4),
                  ),
                  onPressed: _submitDuel,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.close, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'CHALLENGE HUNTER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: HunterTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  TextStyle _dialogLabelStyle() => TextStyle(
    color: HunterTheme.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
  );

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: HunterTheme.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _selectableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? HunterTheme.primary : HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? HunterTheme.primary
                : HunterTheme.primary.withOpacity(0.25),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: HunterTheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : HunterTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _dialogButton(BuildContext ctx, String label, VoidCallback onTap,
      {bool primary = false}) {
    return Expanded(
      child: primary
          ? ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: HunterTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      )
          : OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: HunterTheme.textSecondary,
          side: BorderSide(color: HunterTheme.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _aiQuestCard(Map<String, dynamic> q) {
    final target = (q['target'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HunterTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HunterTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: HunterTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt, color: HunterTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['name']?.toString() ?? 'Quest',
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (target.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    target,
                    style:
                    TextStyle(color: HunterTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HunterTheme.successAlt.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${q['xp'] ?? 50} XP',
              style: TextStyle(
                color: HunterTheme.successAlt,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hunterAlertDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? message,
    Widget? content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: iconColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (message != null)
              Text(
                message,
                style: TextStyle(
                    color: HunterTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            if (content != null) content,
            const SizedBox(height: 20),
            Row(children: actions),
          ],
        ),
      ),
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: HunterTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: HunterTheme.primary, size: 20),
        filled: true,
        fillColor: HunterTheme.cardColor,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          BorderSide(color: HunterTheme.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: HunterTheme.primary, width: 1.5),
        ),
      ),
    );
  }
}