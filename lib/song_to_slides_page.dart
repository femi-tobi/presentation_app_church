// lib/song_to_slides_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dashboard_page.dart'; // SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'preview_page.dart';

/// A full-screen page that converts choir song lyrics into presentation slides.
/// Users can upload a .txt file or paste lyrics, choose 1/2/3 lines per slide,
/// and generate slides that are sent to the PreviewPage for editing.
class SongToSlidesPage extends StatefulWidget {
  const SongToSlidesPage({super.key});

  @override
  State<SongToSlidesPage> createState() => _SongToSlidesPageState();
}

class _SongToSlidesPageState extends State<SongToSlidesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  int _linesPerSlide = 2; // default
  String? _uploadedFileName;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  int get _estimatedSlideCount {
    final text = _lyricsController.text;
    if (text.trim().isEmpty) return 0;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return (lines.length / _linesPerSlide).ceil();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final file = File(path);
        final content = await file.readAsString();

        setState(() {
          _lyricsController.text = content;
          _uploadedFileName = name;
          // Auto-fill title from filename (strip extension)
          if (_titleController.text.trim().isEmpty) {
            _titleController.text =
                name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully loaded "$name"'),
              backgroundColor: SacredColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateSlides() {
    final lyrics = _lyricsController.text.trim();
    if (lyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste or upload song lyrics first.'),
        ),
      );
      return;
    }

    final songTitle = _titleController.text.trim().isEmpty
        ? 'Choir Song'
        : _titleController.text.trim();

    final slides = parseSongToSlides(lyrics, songTitle, _linesPerSlide);

    final presentationId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPage(
          presentationId: presentationId,
          outlineText: lyrics,
          initialSlides: slides,
          selectedTheme: 'Minimal',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final isDarkMode = AppSettings.instance.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SacredColors.background,
        colorScheme: ColorScheme(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          primary: primaryColor,
          onPrimary: SacredColors.onPrimary,
          secondary: SacredColors.secondary,
          onSecondary: SacredColors.onSecondary,
          error: SacredColors.error,
          onError: SacredColors.onError,
          surface: SacredColors.surface,
          onSurface: SacredColors.onSurface,
          outline: SacredColors.outline,
          outlineVariant: SacredColors.outlineVariant,
          onSurfaceVariant: SacredColors.onSurfaceVariant,
        ),
      ),
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Top navigation bar
              _buildTopBar(context, primaryColor),
              // Main content
              Expanded(
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Lyrics input
                          Expanded(
                            flex: 3,
                            child: _buildLyricsPane(context, primaryColor),
                          ),
                          Container(
                              width: 1,
                              color: SacredColors.outlineVariant),
                          // Right: Controls
                          Expanded(
                            flex: 2,
                            child: _buildControlsPane(context, primaryColor),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildLyricsPane(context, primaryColor),
                            Divider(
                                height: 1,
                                color: SacredColors.outlineVariant),
                            _buildControlsPane(context, primaryColor,
                                isMobile: true),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color primaryColor) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
            bottom:
                BorderSide(color: SacredColors.outlineVariant, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: primaryColor),
                tooltip: 'Back to Dashboard',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Icon(Icons.music_note_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Song to Slides',
                style: SacredTypography.headlineMd(context).copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Slide count badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_estimatedSlideCount),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: SacredColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.slideshow_rounded,
                          size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '$_estimatedSlideCount slide${_estimatedSlideCount == 1 ? '' : 's'}',
                        style: SacredTypography.labelLg(context).copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPane(BuildContext context, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Song Lyrics',
            style: SacredTypography.headlineLg(context).copyWith(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste your choir song lyrics below, or upload a text file.',
            style: SacredTypography.bodyMd(context)
                .copyWith(color: SacredColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // Song title field
          TextField(
            controller: _titleController,
            style: SacredTypography.bodyLg(context).copyWith(
              color: SacredColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Song Title (e.g. "Amazing Grace")',
              hintStyle: SacredTypography.bodyLg(context)
                  .copyWith(color: SacredColors.outline),
              prefixIcon: Icon(Icons.title, color: primaryColor),
              filled: true,
              fillColor: SacredColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          // Lyrics text area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SacredColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: SacredColors.outlineVariant.withValues(alpha: 0.5)),
                boxShadow: SacredShadows.sacred,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  controller: _lyricsController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() {}),
                  style: SacredTypography.bodyMd(context).copyWith(
                    color: SacredColors.onSurface,
                    height: 2.0,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Amazing grace, how sweet the sound\nThat saved a wretch like me\nI once was lost, but now am found\nWas blind, but now I see\n\n\'Twas grace that taught my heart to fear\nAnd grace my fears relieved\nHow precious did that grace appear\nThe hour I first believed...',
                    hintStyle: SacredTypography.bodyMd(context).copyWith(
                      color: SacredColors.outline.withValues(alpha: 0.5),
                      height: 2.0,
                    ),
                    hintMaxLines: 15,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(24),
                  ),
                ),
              ),
            ),
          ),
          if (_uploadedFileName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SacredColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 16, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    _uploadedFileName!,
                    style: SacredTypography.labelSm(context)
                        .copyWith(color: primaryColor),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _uploadedFileName = null),
                    child: Icon(Icons.close, size: 14,
                        color: SacredColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsPane(BuildContext context, Color primaryColor,
      {bool isMobile = false}) {
    return Container(
      color: SacredColors.surfaceContainerLow,
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Upload section
          Text(
            'Upload Song',
            style: SacredTypography.headlineMd(context).copyWith(
              fontWeight: FontWeight.bold,
              color: SacredColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Import a .txt file with your song lyrics.',
            style: SacredTypography.labelLg(context)
                .copyWith(color: SacredColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: SacredColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: SacredColors.outlineVariant,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 32, color: primaryColor),
                  const SizedBox(height: 8),
                  Text(
                    'Choose .txt file',
                    style: SacredTypography.labelLg(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: SacredColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'or drag and drop',
                    style: SacredTypography.labelSm(context)
                        .copyWith(color: SacredColors.outline),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Lines per slide selector
          Text(
            'Lines per Slide',
            style: SacredTypography.headlineMd(context).copyWith(
              fontWeight: FontWeight.bold,
              color: SacredColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How many lines of lyrics should appear on each slide?',
            style: SacredTypography.labelLg(context)
                .copyWith(color: SacredColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [1, 2, 3].map((n) {
              final isSelected = _linesPerSlide == n;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: n < 3 ? 12 : 0),
                  child: InkWell(
                    onTap: () => setState(() => _linesPerSlide = n),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor
                            : SacredColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : SacredColors.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? SacredShadows.sacred : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$n',
                            style: SacredTypography.headlineLg(context)
                                .copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : SacredColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n == 1 ? 'line' : 'lines',
                            style:
                                SacredTypography.labelSm(context).copyWith(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : SacredColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Slide preview summary
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey('$_estimatedSlideCount-$_linesPerSlide'),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _estimatedSlideCount == 0
                              ? 'No slides yet'
                              : 'Will create $_estimatedSlideCount slide${_estimatedSlideCount == 1 ? '' : 's'}',
                          style:
                              SacredTypography.labelLg(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_linesPerSlide line${_linesPerSlide == 1 ? '' : 's'} per slide',
                          style: SacredTypography.labelSm(context)
                              .copyWith(color: SacredColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isMobile) const Spacer(),
          if (isMobile) const SizedBox(height: 32),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: _lyricsController.text.trim().isEmpty
                  ? null
                  : _generateSlides,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.slideshow_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Generate Slides',
                    style: SacredTypography.headlineMd(context).copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Each lyric line counts as one row of typed text.',
              style: TextStyle(color: SacredColors.outline, fontSize: 12),
            ),
          ),
          if (isMobile) const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Top-level song-to-slides parser used by both the full page and sidebar pane.
List<SlideData> parseSongToSlides(
    String lyrics, String title, int linesPerSlide) {
  const String sharedBg =
      'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80';

  final List<SlideData> slides = [];

  // 1. Add the Title Slide (large title, no lyrics)
  slides.add(SlideData(
    id: '01',
    title: title,
    subtitle: '',
    imageUrl: sharedBg,
    opacity: 0.80,
    blur: 8.0,
    titleFontSize: 56.0,
    alignment: TextAlign.center,
  ));

  final rawLines = lyrics.split('\n');

  // Helper to identify if a line is a section marker (e.g. Chorus, VS1, Verse 2, Bridge)
  bool isMarker(String line) {
    final clean = line.trim().toUpperCase()
        .replaceAll(RegExp(r'[\[\]\(\):\.\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
        
    if (clean.isEmpty) return false;

    final exactWords = {
      'CHORUS', 'VERSE', 'VS', 'MEDLEY', 'CODA', 'BRIDGE', 'INTRO', 'OUTRO', 'TAG', 'REFRAIN'
    };
    if (exactWords.contains(clean)) {
      return true;
    }

    if (RegExp(r'^(VERSE|CHORUS|BRIDGE|CODA|MEDLEY|INTRO|OUTRO|REFRAIN|TAG|VS|V)\s*\d+$').hasMatch(clean)) {
      return true;
    }

    return false;
  }

  // Pre-process lines into sections (separated by blank lines or markers)
  final List<List<String>> sections = [];
  List<String> currentSection = [];

  bool isFirstNonEmpty = true;
  for (final rawLine in rawLines) {
    final trimmed = rawLine.trim();
    
    // Treat blank lines as section boundaries
    if (trimmed.isEmpty) {
      if (currentSection.isNotEmpty) {
        sections.add(List.from(currentSection));
        currentSection.clear();
      }
      continue;
    }

    // Skip the first non-empty line if it is exactly the song title (case-insensitive)
    if (isFirstNonEmpty) {
      isFirstNonEmpty = false;
      if (trimmed.toLowerCase() == title.toLowerCase()) {
        continue;
      }
    }

    // If it is a marker, end the current section and start a new one (skipping the marker line)
    if (isMarker(trimmed)) {
      if (currentSection.isNotEmpty) {
        sections.add(List.from(currentSection));
        currentSection.clear();
      }
      continue;
    }

    currentSection.add(trimmed);
  }

  if (currentSection.isNotEmpty) {
    sections.add(List.from(currentSection));
  }

  // 2. Generate lyric slides from sections
  for (final section in sections) {
    for (int i = 0; i < section.length; i += linesPerSlide) {
      final end = (i + linesPerSlide).clamp(0, section.length);
      final chunk = section.sublist(i, end);
      final subtitleText = chunk.join('\n');

      slides.add(SlideData(
        id: '${slides.length + 1}'.padLeft(2, '0'),
        title: '', // No title on subsequent slides
        subtitle: subtitleText,
        imageUrl: sharedBg,
        opacity: 0.80,
        blur: 8.0,
        titleFontSize: 36.0,
        subtitleFontSize: 24.0,
        alignment: TextAlign.center,
      ));
    }
  }

  return slides;
}

/// A compact song-to-slides sidebar pane for the Create Presentation page.
/// This is designed to fit within the right sidebar alongside
/// the Church Themes and AI PPTX Generator tabs.
class SongToSlidesSidebarPane extends StatefulWidget {
  final Color primaryColor;

  const SongToSlidesSidebarPane({super.key, required this.primaryColor});

  @override
  State<SongToSlidesSidebarPane> createState() =>
      _SongToSlidesSidebarPaneState();
}

class _SongToSlidesSidebarPaneState extends State<SongToSlidesSidebarPane> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  int _linesPerSlide = 2;

  @override
  void dispose() {
    _titleController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  int get _estimatedSlideCount {
    final text = _lyricsController.text;
    if (text.trim().isEmpty) return 0;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return (lines.length / _linesPerSlide).ceil();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final file = File(path);
        final content = await file.readAsString();

        setState(() {
          _lyricsController.text = content;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text =
                name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded "$name"'),
              backgroundColor: SacredColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateSlides() {
    final lyrics = _lyricsController.text.trim();
    if (lyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste or upload song lyrics.')),
      );
      return;
    }

    final songTitle = _titleController.text.trim().isEmpty
        ? 'Choir Song'
        : _titleController.text.trim();

    final slides =
        parseSongToSlides(lyrics, songTitle, _linesPerSlide);

    final presentationId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPage(
          presentationId: presentationId,
          outlineText: lyrics,
          initialSlides: slides,
          selectedTheme: 'Minimal',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SacredColors.surfaceContainerLow,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Song to Slides',
              style: SacredTypography.headlineMd(context).copyWith(
                fontWeight: FontWeight.bold,
                color: SacredColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Convert choir song lyrics into presentation slides.',
              style: SacredTypography.labelLg(context)
                  .copyWith(color: SacredColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Upload button
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SacredColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SacredColors.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 28, color: widget.primaryColor),
                    const SizedBox(height: 4),
                    Text('Upload .txt file',
                        style: SacredTypography.labelLg(context).copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Song title
            TextField(
              controller: _titleController,
              style: SacredTypography.bodyMd(context)
                  .copyWith(color: SacredColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Song Title',
                hintStyle: SacredTypography.bodyMd(context)
                    .copyWith(color: SacredColors.outline),
                filled: true,
                fillColor: SacredColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: widget.primaryColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Lyrics textarea
            SizedBox(
              height: 160,
              child: TextField(
                controller: _lyricsController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                style: SacredTypography.bodyMd(context).copyWith(
                  color: SacredColors.onSurface,
                  height: 1.8,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste song lyrics here...',
                  hintStyle: SacredTypography.bodyMd(context)
                      .copyWith(color: SacredColors.outline),
                  filled: true,
                  fillColor: SacredColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: widget.primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Lines per slide
            Text(
              'Lines per Slide',
              style: SacredTypography.labelLg(context).copyWith(
                fontWeight: FontWeight.bold,
                color: SacredColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [1, 2, 3].map((n) {
                final isSelected = _linesPerSlide == n;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: n < 3 ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _linesPerSlide = n),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.primaryColor
                              : SacredColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? widget.primaryColor
                                : SacredColors.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$n',
                              style: SacredTypography.headlineMd(context)
                                  .copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : SacredColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              n == 1 ? 'line' : 'lines',
                              style: SacredTypography.labelSm(context)
                                  .copyWith(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : SacredColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Preview summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _estimatedSlideCount == 0
                    ? 'Paste lyrics to see slide count'
                    : 'Will create $_estimatedSlideCount slide${_estimatedSlideCount == 1 ? '' : 's'} ($_linesPerSlide line${_linesPerSlide == 1 ? '' : 's'}/slide)',
                style: SacredTypography.labelLg(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: _lyricsController.text.trim().isEmpty
                    ? null
                    : _generateSlides,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.slideshow_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Generate Slides',
                      style: SacredTypography.headlineMd(context).copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Each lyric line = one row of typed text.',
                style: TextStyle(color: SacredColors.outline, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
