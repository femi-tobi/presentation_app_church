import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'pptx_parser.dart';
import 'settings_state.dart';
import 'preview_page.dart';

/// Dedicated service for importing PowerPoint (.pptx) decks into the app.
///
/// This is completely isolated from the choir/song import paths.
/// Call [PptxImportService.importDeck] to trigger the full flow:
/// file picker → parse → register → navigate to editor.
class PptxImportService {
  PptxImportService._(); // non-instantiable

  /// Shows a file picker for .pptx files, parses the selected file into
  /// [SlideData] objects, registers the presentation, and navigates to
  /// [PreviewPage] for editing.
  ///
  /// Shows a loading indicator during parsing and a SnackBar on success/error.
  static Future<void> importDeck(BuildContext context) async {
    // ── 1. File picker ────────────────────────────────────────────────────
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pptx'],
        dialogTitle: 'Select a PowerPoint file',
      );
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Could not open file picker: $e', isError: true);
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // ── 2. Show loading overlay ───────────────────────────────────────────
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PptxLoadingDialog(),
      );
    }

    try {
      // ── 3. Read bytes ─────────────────────────────────────────────────
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('Could not read file bytes.');
      final Uint8List nonNullBytes = bytes;

      final cleanTitle = file.name
          .replaceAll('.pptx', '')
          .replaceAll('.PPTX', '')
          .trim();

      // ── 4. Parse (on main isolate — avoids ChangeNotifier transfer issues) ───
      // Wrapped in Future so the loading dialog has time to render first.
      final parsedSlides = await Future.microtask(
        () => PptxParser.parsePptx(nonNullBytes, cleanTitle),
      );

      // ── 5. Register presentation ──────────────────────────────────────
      final id     = 'imported_${DateTime.now().millisecondsSinceEpoch}';
      final record = PresentationRecord(
        id:           id,
        title:        cleanTitle,
        slideCount:   parsedSlides.length,
        thumbnailUrl: '',
        createdAt:    DateTime.now(),
        slides:       parsedSlides,
        outlineText:  parsedSlides.map((s) => s.subtitle).join('\n\n'),
      );
      AppSettings.instance.addRecentPresentation(record);

      // ── 6. Dismiss loader & navigate ──────────────────────────────────
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      if (context.mounted) {
        _snack(
          context,
          'Imported "${record.title}" — ${parsedSlides.length} slides',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewPage(
              presentationId: record.id,
              initialSlides:  record.slides,
              initialSections: record.sections,
              outlineText:    record.outlineText,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
        _snack(context, 'Error importing PPTX: $e', isError: true);
      }
    }
  }

  // ── Background parse helper (runs via compute) ────────────────────────────

  static List<SlideData> _parseInBackground(_ParseArgs args) {
    return PptxParser.parsePptx(args.bytes, args.title);
  }

  // ── SnackBar helper ───────────────────────────────────────────────────────

  static void _snack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? const Color(0xFFB00020)
            : AppSettings.instance.primaryColor,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }
}

// ── Args record for compute() ─────────────────────────────────────────────────

class _ParseArgs {
  final Uint8List bytes;
  final String title;
  const _ParseArgs({required this.bytes, required this.title});
}

// ── Loading dialog ─────────────────────────────────────────────────────────────

class _PptxLoadingDialog extends StatefulWidget {
  const _PptxLoadingDialog();

  @override
  State<_PptxLoadingDialog> createState() => _PptxLoadingDialogState();
}

class _PptxLoadingDialogState extends State<_PptxLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _step = 0;

  static const _messages = [
    'Reading PowerPoint file…',
    'Extracting slide layouts…',
    'Resolving theme colours…',
    'Parsing shapes & images…',
    'Building slide data…',
    'Almost there…',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _step = (_step + 1) % _messages.length);
          _ctrl.forward(from: 0);
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF7C6FCD)),
            const SizedBox(height: 20),
            const Text(
              'Importing Presentation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _messages[_step],
                key: ValueKey(_step),
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
