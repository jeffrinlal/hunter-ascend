import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Reusable screen for displaying legal documents (Privacy Policy, Terms of
/// Service, etc.) in a scrollable, theme-aware layout with selectable text.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => LegalDocumentScreen(
///     title: 'Privacy Policy',
///     content: privacyPolicyText,
///   ),
/// ));
/// ```
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => MembershipScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: HunterTheme.textSecondary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: SelectableText(
            content,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13.5,
              height: 1.7,
            ),
          ),
        ),
      ),
    );
  }
}
