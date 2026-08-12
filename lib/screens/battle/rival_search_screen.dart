import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/services/connectivity_service.dart';
import 'package:hunter_ascend/services/rivalry_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Screen to search for a Hunter by exact name and challenge them to a
/// time-limited Rivalry.
///
/// The search itself (debounce, exact-name query, self-guard, status
/// indicators) is unchanged. What changed is the outcome: selecting a Hunter
/// no longer stores a rival locally — it reveals a duration picker and sends a
/// Rivalry REQUEST that the other Hunter must accept, because the relationship
/// is shared between two users and therefore has to be persisted remotely.
class RivalSearchScreen extends StatefulWidget {
  const RivalSearchScreen({super.key});

  @override
  State<RivalSearchScreen> createState() => _RivalSearchScreenState();
}

class _RivalSearchScreenState extends State<RivalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  bool _isSearching = false;
  bool _searchError = false;
  bool _isSelf = false;
  String? _foundHunterUid;
  Map<String, dynamic>? _foundHunterData;

  /// The Hunter the user has tapped to challenge. Selecting reveals the
  /// duration picker instead of navigating away.
  String? _selectedHunterUid;

  /// Chosen rivalry duration in days. Mirrors the duel screen's duration
  /// setting; the allowed values come from [RivalryService.allowedDurations].
  int _selectedDuration = RivalryService.allowedDurations.first;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

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
        _searchError = false;
        _foundHunterUid = null;
        _foundHunterData = null;
        _selectedHunterUid = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = false;
      _isSelf = false;
      _foundHunterUid = null;
      _foundHunterData = null;
      _selectedHunterUid = null;
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
              // Prevent the user from setting themselves as their own Rival.
              _isSelf = true;
              _foundHunterUid = null;
              _foundHunterData = null;
            } else {
              _isSelf = false;
              _foundHunterUid = doc.id;
              _foundHunterData = doc.data();
            }
          } else {
            _isSelf = false;
            _foundHunterUid = null;
          }
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _searchError = true;
          _isSelf = false;
          _foundHunterUid = null;
          _foundHunterData = null;
        });
      }
    });
  }

  /// Sends the Rivalry request. All Firestore work — the one-active-rivalry
  /// pre-checks on both hunters and the create itself — lives in
  /// [RivalryService]; this method only handles connectivity, re-entry and
  /// presentation.
  Future<void> _sendRivalRequest() async {
    if (_isSending) return;
    final targetUid = _selectedHunterUid;
    if (targetUid == null) return;

    if (!await ConnectivityService.isOnline()) {
      if (!mounted) return;
      _snack('Internet connection required.');
      return;
    }

    setState(() => _isSending = true);

    final result = await RivalryService.instance.sendRequest(
      targetUid: targetUid,
      targetHunterName:
          (_foundHunterData?['hunterName'] as String?) ?? 'Unknown',
      durationDays: _selectedDuration,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (!result.ok) {
      _snack(result.message ?? 'Could not send the rivalry request.');
      return;
    }

    _snack('Rivalry request sent — $_selectedDuration day challenge.');
    Navigator.pop(context);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: HunterTheme.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.person_search_rounded, color: MembershipTheme.current.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Find Rival',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      // Scrollable so the content cannot overflow when the keyboard opens.
      // This screen always has focus in the search field, and
      // MembershipScaffold uses resizeToAvoidBottomInset: true, so the body
      // shrinks by the keyboard height. The Column below is fixed-height with
      // nothing to absorb that shrink, and the tappable result card is its
      // LAST child — so it was being clipped off-screen and could not be
      // tapped to select a rival. Matches CreateDuelScreen, which already
      // wraps the same hunter-search layout in a scroll view.
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'CHALLENGE A RIVAL',
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the exact Hunter Name of the person you want to rival, '
              'then choose how long the Rivalry runs. They must accept before '
              'the timer starts. You can only have one Rival at a time.',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MembershipTheme.current.accent.withValues(alpha: 0.2)),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: HunterTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Enter Hunter Name',
                  hintStyle: TextStyle(color: HunterTheme.textTertiary),
                  prefixIcon: Icon(Icons.search, color: MembershipTheme.current.accent),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Search Status indicator
            if (_isSearching)
              Row(
                children: [
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: MembershipTheme.current.accent),
                  ),
                  const SizedBox(width: 10),
                  Text('Searching Hunters...', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 13)),
                ],
              )
            else if (_searchError)
              Row(
                children: [
                  Icon(Icons.error_outline, color: HunterTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Text('Error searching. Please try again.', style: TextStyle(color: HunterTheme.danger, fontSize: 13)),
                ],
              )
            else if (_isSelf)
              Row(
                children: [
                  Icon(Icons.person, color: HunterTheme.gold, size: 16),
                  const SizedBox(width: 8),
                  Text("That's you! Pick a different Hunter.", style: TextStyle(color: HunterTheme.gold, fontSize: 13)),
                ],
              )
            else if (_searchController.text.trim().length >= 3 && _foundHunterUid == null && !_isSearching)
              Row(
                children: [
                  Icon(Icons.cancel, color: HunterTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Text('Hunter not found.', style: TextStyle(color: HunterTheme.danger, fontSize: 13)),
                ],
              ),

            const SizedBox(height: 24),

            // Result Card
            if (_foundHunterUid != null && _foundHunterData != null)
              _buildResultCard(),

            // Duration picker + send, revealed once a Hunter is selected.
            if (_selectedHunterUid != null) ...[
              const SizedBox(height: 28),
              _buildDurationPicker(),
              const SizedBox(height: 24),
              _buildSendButton(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final accent = MembershipTheme.current.accent;
    final isSelected = _selectedHunterUid == _foundHunterUid;
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: HunterTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: isSelected ? 0.85 : 0.4),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isSelected ? 0.2 : 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedHunterUid = _foundHunterUid),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Simple Avatar placeholder, full PremiumAvatar requires more imports
                  // but this is enough to show the selection.
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HunterTheme.cardColor,
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_foundHunterData!['hunterName'] as String?) ?? 'Unknown',
                          style: TextStyle(
                            color: HunterTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level ${_foundHunterData!['level'] ?? 1}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_ios,
                    color: accent,
                    size: isSelected ? 22 : 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIVALRY DURATION',
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final days in RivalryService.allowedDurations) ...[
              Expanded(child: _durationChip(days)),
              if (days != RivalryService.allowedDurations.last)
                const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'The timer starts only when your Rival accepts. Whoever gains the '
          'most XP during the Rivalry wins.',
          style: TextStyle(
            color: HunterTheme.textTertiary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _durationChip(int days) {
    final accent = MembershipTheme.current.accent;
    final selected = _selectedDuration == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = days),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : HunterTheme.border,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$days',
              style: TextStyle(
                color: selected ? accent : HunterTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DAYS',
              style: TextStyle(
                color: selected ? accent : HunterTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final tokens = MembershipTheme.current;
    return GestureDetector(
      onTap: _isSending ? null : _sendRivalRequest,
      child: Opacity(
        opacity: _isSending ? 0.6 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tokens.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tokens.accent
                    .withValues(alpha: 0.4 * HunterTheme.glowStrength),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSending)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MembershipTheme.isMax ? Colors.white : Colors.black,
                  ),
                )
              else
                Icon(
                  Icons.send_rounded,
                  color: MembershipTheme.isMax ? Colors.white : Colors.black,
                  size: 18,
                ),
              const SizedBox(width: 10),
              Text(
                _isSending ? 'SENDING...' : 'SEND RIVAL REQUEST',
                style: TextStyle(
                  color: MembershipTheme.isMax ? Colors.white : Colors.black,
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
