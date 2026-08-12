import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hunter_ascend/screens/profile/public_hunter_profile_screen.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Screen to search for a Hunter by exact name and set them as a Rival.
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
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = false;
      _isSelf = false;
      _foundHunterUid = null;
      _foundHunterData = null;
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

  Future<void> _setRivalAndContinue() async {
    if (_foundHunterUid == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rival_uid', _foundHunterUid!);
    
    if (!mounted) return;
    
    // Replace the search screen with the newly established Rival profile
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PublicHunterProfileScreen(
          hunterUid: _foundHunterUid!,
          isRivalMode: true,
        ),
      ),
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
              'CHOOSE YOUR RIVAL',
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the exact Hunter Name of the person you want to rival. You can only have one Rival at a time.',
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
                border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.2)),
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
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    color: HunterTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: MembershipTheme.current.accent.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _setRivalAndContinue,
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
                                border: Border.all(color: MembershipTheme.current.accent.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.person, color: Colors.grey),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _foundHunterData!['hunterName'] ?? 'Unknown',
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
                                      color: MembershipTheme.current.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: MembershipTheme.current.accent, size: 16),
                          ],
                        ),
                      ),
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
