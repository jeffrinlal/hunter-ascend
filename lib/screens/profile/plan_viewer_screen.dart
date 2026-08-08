import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/fitness_plan.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';
import 'package:path_provider/path_provider.dart';

/// In-app PDF viewer for a single unlocked fitness plan.
///
/// flutter_pdfview's [PDFView.filePath] expects a real filesystem path, not
/// a Flutter asset path. This screen therefore:
/// 1. Loads the PDF bytes from the asset bundle via [rootBundle.load].
/// 2. Writes them to a temp [File] in the OS temp directory.
/// 3. Passes that temp file's path to [PDFView].
///
/// If the asset is missing (the user hasn't added the real PDF yet), a
/// friendly placeholder is shown instead of crashing.
class PlanViewerScreen extends StatefulWidget {
  const PlanViewerScreen({super.key, required this.plan});

  /// The plan to display.
  final FitnessPlan plan;

  @override
  State<PlanViewerScreen> createState() => _PlanViewerScreenState();
}

class _PlanViewerScreenState extends State<PlanViewerScreen> {
  /// Path to the temp file containing the extracted PDF, once ready.
  String? _tempFilePath;

  /// Whether the PDF is currently being extracted from the asset bundle.
  bool _isLoading = true;

  /// Whether the PDF asset was not found in the bundle.
  bool _assetMissing = false;

  @override
  void initState() {
    super.initState();
    _extractPdf();
  }

  @override
  void dispose() {
    // Clean up the temp file so we don't accumulate copies in the cache.
    if (_tempFilePath != null) {
      final file = File(_tempFilePath!);
      file.exists().then((exists) {
        if (exists) file.delete();
      });
    }
    super.dispose();
  }

  /// Loads the PDF asset bytes, writes them to a temp file, and stores
  /// the temp file's path in [_tempFilePath].
  Future<void> _extractPdf() async {
    try {
      // 1. Load bytes from the asset bundle.
      final bytes = await rootBundle.load(widget.plan.assetPath);
      if (bytes.lengthInBytes == 0) {
        if (mounted) setState(() => _assetMissing = true);
        return;
      }

      // 2. Get the OS temp directory.
      final tempDir = await getTemporaryDirectory();

      // 3. Write the bytes to a temp file named after the plan id.
      final tempFile = File('${tempDir.path}/${widget.plan.id}.pdf');
      await tempFile.writeAsBytes(
        bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ),
        flush: true,
      );

      // 4. Store the real filesystem path for PDFView.
      if (mounted) {
        setState(() {
          _tempFilePath = tempFile.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PlanViewerScreen: failed to extract PDF — $e');
      // Asset not bundled — most likely the user hasn't added the real PDF.
      if (mounted) {
        setState(() {
          _assetMissing = true;
          _isLoading = false;
        });
      }
    }
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
      appBar: MembershipAppBar(title: widget.plan.title),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_assetMissing) {
      return _buildMissingPlaceholder();
    }

    if (_isLoading || _tempFilePath == null) {
      return Center(
        child: CircularProgressIndicator(color: MembershipTheme.current.accent),
      );
    }

    return _buildPdfView();
  }

  Widget _buildPdfView() {
    return PDFView(
      filePath: _tempFilePath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      nightMode: HunterTheme.isDark,
      onError: (error) {
        debugPrint('PlanViewerScreen: PDF error — $error');
        if (mounted) setState(() => _assetMissing = true);
      },
      onPageError: (page, error) {
        debugPrint('PlanViewerScreen: page $page error — $error');
      },
    );
  }

  Widget _buildMissingPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
              color: HunterTheme.textFaint,
            ),
            const SizedBox(height: 16),
            Text(
              'This plan hasn\'t been added yet',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The PDF file for "${widget.plan.title}" is not bundled in '
              'this build. Please check back after the next app update.',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
