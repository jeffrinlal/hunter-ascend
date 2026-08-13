import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/screens/battle/step_clash_screen.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/step_clash_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Create a Step Clash: pick goal, duration, search & invite Hunters.
class StepClashCreateScreen extends StatefulWidget {
  const StepClashCreateScreen({super.key});

  @override
  State<StepClashCreateScreen> createState() => _StepClashCreateScreenState();
}

class _StepClashCreateScreenState extends State<StepClashCreateScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  int _selectedGoal = StepClashService.allowedGoals.first;
  int _selectedDuration = StepClashService.allowedDurations.first;

  // Invited hunters (up to 4).
  final List<String> _invitedUids = [];
  final Map<String, String> _invitedNames = {};

  // Search state.
  bool _isSearching = false;
  bool _isSelf = false;
  String? _foundUid;
  Map<String, dynamic>? _foundData;

  bool _isCreating = false;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    final name = _searchController.text.trim();
    if (name.length < 3) {
      setState(() {
        _isSearching = false;
        _foundUid = null;
        _foundData = null;
        _isSelf = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _foundUid = null;
      _foundData = null;
      _isSelf = false;
    });
    _searchTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await FirebaseFirestore.instance
            .collection('hunters')
            .where('hunterName', isEqualTo: name)
            .limit(1)
            .get();
        if (!mounted) return;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        setState(() {
          _isSearching = false;
          if (result.docs.isNotEmpty) {
            final doc = result.docs.first;
            if (doc.id == currentUid) {
              _isSelf = true;
            } else {
              _foundUid = doc.id;
              _foundData = doc.data();
            }
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSearching = false);
      }
    });
  }

  void _addInvitee() {
    if (_foundUid == null || _foundData == null) return;
    if (_invitedUids.contains(_foundUid)) {
      _snack('Already invited.');
      return;
    }
    if (_invitedUids.length >= 4) {
      _snack('Maximum 4 opponents.');
      return;
    }
    setState(() {
      _invitedUids.add(_foundUid!);
      _invitedNames[_foundUid!] =
          (_foundData!['hunterName'] as String?) ?? 'Unknown';
      _searchController.clear();
      _foundUid = null;
      _foundData = null;
    });
  }

  void _removeInvitee(String uid) {
    setState(() {
      _invitedUids.remove(uid);
      _invitedNames.remove(uid);
    });
  }

  Future<void> _create() async {
    if (_isCreating) return;
    if (_invitedUids.isEmpty) {
      _snack('Invite at least one Hunter.');
      return;
    }
    if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      _snack('Internet connection required.');
      return;
    }
    setState(() => _isCreating = true);

    final result = await StepClashService.instance.create(
      inviteeUids: _invitedUids,
      inviteeNames: _invitedNames,
      goalSteps: _selectedGoal,
      durationMinutes: _selectedDuration,
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (!result.ok || result.clash == null) {
      _snack(result.message ?? 'Could not create the Step Clash.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StepClashScreen(battleId: result.clash!.id),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final accent = MembershipTheme.current.accent;
    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👣', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'CREATE STEP CLASH',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Goal picker ──
            _sectionLabel('STEP GOAL'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: StepClashService.allowedGoals
                  .map((g) => _chip(
                        label: '${(g / 1000).toStringAsFixed(0)}K',
                        selected: _selectedGoal == g,
                        onTap: () => setState(() => _selectedGoal = g),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),

            // ── Duration picker ──
            _sectionLabel('DURATION'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: StepClashService.allowedDurations.map((d) {
                final label = d >= 60 ? '${d ~/ 60}h' : '${d}min';
                return _chip(
                  label: label,
                  selected: _selectedDuration == d,
                  onTap: () => setState(() => _selectedDuration = d),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Hunter search ──
            _sectionLabel('INVITE HUNTERS (up to 4)'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _onSearchChanged(),
                style: TextStyle(
                    color: HunterTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Enter Hunter Name',
                  hintStyle: TextStyle(color: HunterTheme.textTertiary),
                  prefixIcon: Icon(Icons.search, color: accent),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isSearching)
              _statusRow(Icons.hourglass_empty_rounded, accent,
                  'Searching...'),
            if (_isSelf)
              _statusRow(Icons.person, HunterTheme.gold,
                  "That's you! Pick a different Hunter."),
            if (!_isSearching &&
                _foundUid == null &&
                _searchController.text.trim().length >= 3 &&
                !_isSelf)
              _statusRow(
                  Icons.cancel, HunterTheme.danger, 'Hunter not found.'),
            if (_foundUid != null && _foundData != null)
              _foundCard(),

            // ── Invited list ──
            if (_invitedUids.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionLabel(
                  'INVITED (${_invitedUids.length}/${4})'),
              const SizedBox(height: 8),
              ..._invitedUids.map(_inviteeChip),
            ],

            const SizedBox(height: 32),

            // ── Create button ──
            _createButton(accent),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: HunterTheme.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = MembershipTheme.current.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color:
              selected ? accent.withValues(alpha: 0.14) : HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : HunterTheme.border,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : HunterTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: color, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _foundCard() {
    final accent = MembershipTheme.current.accent;
    final name = (_foundData!['hunterName'] as String?) ?? 'Unknown';
    final level = _foundData!['level'] ?? 1;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: _addInvitee,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HunterTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HunterTheme.cardColor,
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.person, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: HunterTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text('Level $level',
                        style: TextStyle(color: accent, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.add_circle_rounded, color: accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inviteeChip(String uid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HunterTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.grey, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _invitedNames[uid] ?? uid,
                style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            GestureDetector(
              onTap: () => _removeInvitee(uid),
              child: Icon(Icons.close_rounded,
                  color: HunterTheme.danger, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createButton(Color accent) {
    final fg = MembershipTheme.isMax ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: _isCreating ? null : _create,
      child: Opacity(
        opacity: _isCreating ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: MembershipTheme.current.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                    alpha: 0.35 * HunterTheme.glowStrength),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCreating)
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg))
              else
                Icon(Icons.flash_on_rounded, color: fg, size: 18),
              const SizedBox(width: 10),
              Text(
                _isCreating ? 'CREATING...' : 'START STEP CLASH',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
