import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_page.dart'; // import to reuse SacredColors / Typography
import 'export_page.dart';
import 'settings_state.dart';
import 'fullscreen_presenter_page.dart';


/// Safely decode a base64 data-URL (e.g. "data:image/png;base64,....") to bytes.
/// Falls back to manual base64 splitting if [Uri] fails to parse the data.
Uint8List _decodeDataUrl(String dataUrl) {
  try {
    final uriData = Uri.parse(dataUrl).data;
    if (uriData != null) return uriData.contentAsBytes();
  } catch (_) {}
  // Fallback: manually strip the prefix
  final commaIndex = dataUrl.indexOf(',');
  if (commaIndex != -1) {
    return base64Decode(dataUrl.substring(commaIndex + 1));
  }
  return Uint8List(0);
}


class PreviewPage extends StatefulWidget {
  final String presentationId;
  final String outlineText;
  final String selectedTheme;
  final List<SlideData>? initialSlides;

  const PreviewPage({
    super.key,
    required this.presentationId,
    this.outlineText = '',
    this.selectedTheme = 'Minimal',
    this.initialSlides,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late List<SlideData> _slides;
  int _activeSlideIndex = 0;
  int _mobileSelectedTab = 1; // 0: Slides Outline, 1: Live Canvas, 2: Properties
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();

    // Parse the user's outline into slides, or fall back to defaults
    if (widget.initialSlides != null && widget.initialSlides!.isNotEmpty) {
      _slides = List.from(widget.initialSlides!.map((s) => SlideData(
        id: s.id,
        title: s.title,
        subtitle: s.subtitle,
        imageUrl: s.imageUrl,
        opacity: s.opacity,
        blur: s.blur,
        isBold: s.isBold,
        isItalic: s.isItalic,
        alignment: s.alignment,
        transition: s.transition,
        titleFontSize: s.titleFontSize,
        subtitleFontSize: s.subtitleFontSize,
        logoUrl: s.logoUrl,
        logoX: s.logoX,
        logoY: s.logoY,
        logoSize: s.logoSize,
      )));
    } else if (widget.outlineText.isNotEmpty) {
      _slides = _parseSlidesFromOutline(widget.outlineText);
    } else {
      _slides = _defaultSlides();
    }

    _titleController = TextEditingController(text: _slides[0].title);
    _subtitleController = TextEditingController(text: _slides[0].subtitle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppSettings.instance.updateActiveSlides(_slides);
      AppSettings.instance.activeSlideIndex = 0;

      // Save this presentation to the recent list so the dashboard reflects it
      _saveToRecentList();
    });
  }

  void _saveToRecentList() {
    final firstTitle = _slides.isNotEmpty ? _slides.first.title : 'Presentation';
    final thumbUrl = _slides.isNotEmpty ? _slides.first.imageUrl : '';
    AppSettings.instance.addRecentPresentation(PresentationRecord(
      id: widget.presentationId,
      title: firstTitle,
      slideCount: _slides.length,
      thumbnailUrl: thumbUrl,
      createdAt: DateTime.now(),
      slides: _slides,
      outlineText: widget.outlineText,
    ));
  }

  /// Parses a service outline into slides.
  /// Each [Section Header] becomes a slide title.
  /// Lines below it (until the next header) become the subtitle.
  static List<SlideData> _parseSlidesFromOutline(String outline) {
    // All slides share the SAME background image — pick one serene photo
    const String sharedBg =
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80';

    final rawLines = outline.split('\n');
    final lines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (lines.isEmpty) return _defaultSlides();

    // Check if it's hierarchical:
    final isHierarchical = lines.any((l) =>
        RegExp(r'^\*?\d+\.').hasMatch(l) ||
        RegExp(r'^[a-zA-Z]\.').hasMatch(l) ||
        RegExp(r'^[iIvVxX]+\.').hasMatch(l));

    if (!isHierarchical) {
      // Fallback to simple bracket-based parser
      return _parseBracketOutline(outline);
    }

    final List<SlideData> slides = [];

    // Helper to get text alignment based on contents
    TextAlign getAlignment(String subtitleText) {
      if (subtitleText.isEmpty) return TextAlign.center;
      if (subtitleText.contains('\n') || subtitleText.length > 60) return TextAlign.left;
      return TextAlign.center;
    }

    // Rule 1: First line is the main topic (Title Slide)
    final String mainTopic = lines[0];
    slides.add(SlideData(
      id: '${slides.length + 1}'.padLeft(2, '0'),
      title: mainTopic,
      subtitle: '',
      imageUrl: sharedBg,
      opacity: 0.80,
      blur: 8.0,
      titleFontSize: 56.0,
      alignment: TextAlign.center, // Main Title Slide: always centered
    ));

    // Find where the main points summary starts (e.g. "1. ...", "2. ...", "3. ...")
    int firstMainPointIndex = -1;
    for (int i = 1; i < lines.length; i++) {
      if (RegExp(r'^1\.').hasMatch(lines[i])) {
        firstMainPointIndex = i;
        break;
      }
    }

    // Rule 2: Introduction text on another slide with the topic, but smaller
    if (firstMainPointIndex > 1) {
      final introLines = lines.sublist(1, firstMainPointIndex)
          .where((l) => !l.toLowerCase().startsWith('into details'))
          .toList();
      if (introLines.isNotEmpty) {
        final introText = introLines.join('\n');
        slides.add(SlideData(
          id: '${slides.length + 1}'.padLeft(2, '0'),
          title: mainTopic,
          subtitle: introText,
          imageUrl: sharedBg,
          opacity: 0.80,
          blur: 8.0,
          titleFontSize: 36.0,
          subtitleFontSize: 24.0,
          alignment: getAlignment(introText),
        ));
      }
    }

    // Rule 3: Main points (e.g., 1 to 3) each on a slide
    int nextSectionIndex = firstMainPointIndex;
    if (firstMainPointIndex != -1) {
      for (int i = firstMainPointIndex; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'^\d+\.').hasMatch(line)) {
          slides.add(SlideData(
            id: '${slides.length + 1}'.padLeft(2, '0'),
            title: line,
            subtitle: '',
            imageUrl: sharedBg,
            opacity: 0.80,
            blur: 8.0,
            titleFontSize: 44.0,
            alignment: TextAlign.center, // Title-only slide: always centered
          ));
          nextSectionIndex = i + 1;
        } else {
          nextSectionIndex = i;
          break;
        }
      }
    }

    // Group the detailed lines by Main Point
    final List<MainPointGroup> mainPointGroups = [];
    MainPointGroup? currentGroup;

    for (int i = nextSectionIndex; i < lines.length; i++) {
      final line = lines[i];
      if (line.toLowerCase().startsWith('into details')) continue;

      final isNewMainPoint = RegExp(r'^\*?\d+\.').hasMatch(line) && line.contains(RegExp(r'[a-zA-Z]'));
      if (isNewMainPoint) {
        if (currentGroup != null) {
          mainPointGroups.add(currentGroup);
        }
        currentGroup = MainPointGroup(
          title: line.replaceAll('*', '').trim(),
          lines: [],
        );
        if (currentGroup.title.endsWith('.')) {
          currentGroup.title = currentGroup.title.substring(0, currentGroup.title.length - 1);
        }
      } else {
        if (currentGroup != null) {
          currentGroup.lines.add(line);
        }
      }
    }
    if (currentGroup != null) {
      mainPointGroups.add(currentGroup);
    }

    // Parse each Main Point Group into slides
    for (final mpg in mainPointGroups) {
      final List<SubPointBlock> blocks = [];
      SubPointBlock? activeBlock;
      final List<String> mainPointIntroLines = [];

      for (final line in mpg.lines) {
        final isLetter = RegExp(r'^[a-zA-Z]\.').hasMatch(line);
        final isRoman = RegExp(r'^[iIvVxX]+\.').hasMatch(line);

        if (isLetter) {
          if (activeBlock != null) {
            blocks.add(activeBlock);
          }
          activeBlock = SubPointBlock(header: line);
        } else if (isRoman) {
          if (activeBlock != null) {
            activeBlock.romanLines.add(line);
          } else {
            activeBlock = SubPointBlock(header: line);
          }
        } else {
          if (activeBlock != null) {
            if (activeBlock.romanLines.isNotEmpty) {
              final lastIdx = activeBlock.romanLines.length - 1;
              activeBlock.romanLines[lastIdx] = '${activeBlock.romanLines[lastIdx]}\n$line';
            } else {
              activeBlock.bodyLines.add(line);
            }
          } else {
            mainPointIntroLines.add(line);
          }
        }
      }
      if (activeBlock != null) {
        blocks.add(activeBlock);
      }

      // Generate slide for main point introduction (e.g. scriptures under main point title)
      if (mainPointIntroLines.isNotEmpty) {
        final introText = mainPointIntroLines.join('\n');
        slides.add(SlideData(
          id: '${slides.length + 1}'.padLeft(2, '0'),
          title: mpg.title,
          subtitle: introText,
          imageUrl: sharedBg,
          opacity: 0.80,
          blur: 8.0,
          titleFontSize: 36.0,
          subtitleFontSize: 20.0,
          alignment: getAlignment(introText),
        ));
      }

      // Generate slides for each subpoint block
      for (final block in blocks) {
        if (block.romanLines.length > 3) {
          // If roman lines (i., ii., iii., etc.) is more than 3, keep them all on the same slide
          final List<String> combinedLines = [];
          if (block.header.isNotEmpty) combinedLines.add(block.header);
          combinedLines.addAll(block.bodyLines);
          combinedLines.addAll(block.romanLines);

          final subText = combinedLines.join('\n');
          slides.add(SlideData(
            id: '${slides.length + 1}'.padLeft(2, '0'),
            title: mpg.title,
            subtitle: subText,
            imageUrl: sharedBg,
            opacity: 0.80,
            blur: 8.0,
            titleFontSize: 36.0,
            subtitleFontSize: 18.0, // slightly smaller for large text blocks
            alignment: getAlignment(subText),
          ));
        } else {
          // Otherwise, separate them
          final List<String> mainCombined = [];
          if (block.header.isNotEmpty) mainCombined.add(block.header);
          mainCombined.addAll(block.bodyLines);

          final mainText = mainCombined.join('\n');
          slides.add(SlideData(
            id: '${slides.length + 1}'.padLeft(2, '0'),
            title: mpg.title,
            subtitle: mainText,
            imageUrl: sharedBg,
            opacity: 0.80,
            blur: 8.0,
            titleFontSize: 36.0,
            subtitleFontSize: 20.0,
            alignment: getAlignment(mainText),
          ));

          for (final romanLine in block.romanLines) {
            slides.add(SlideData(
              id: '${slides.length + 1}'.padLeft(2, '0'),
              title: mpg.title,
              subtitle: romanLine,
              imageUrl: sharedBg,
              opacity: 0.80,
              blur: 8.0,
              titleFontSize: 36.0,
              subtitleFontSize: 20.0,
              alignment: getAlignment(romanLine),
            ));
          }
        }
      }
    }

    return slides.isNotEmpty ? slides : _defaultSlides();
  }

  /// Original bracket-based parser logic as a fallback.
  static List<SlideData> _parseBracketOutline(String outline) {
    const String sharedBg =
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80';

    final lines = outline.split('\n');
    final List<SlideData> slides = [];

    String? currentTitle;
    final List<String> currentBodyLines = [];

    void flushSlide() {
      if (currentTitle == null) return;
      final body = currentBodyLines
          .where((l) => l.trim().isNotEmpty)
          .join(' • ');
      slides.add(SlideData(
        id: '${slides.length + 1}'.padLeft(2, '0'),
        title: currentTitle!,
        subtitle: body.isNotEmpty ? body : '',
        imageUrl: sharedBg,
        opacity: 0.80,
        blur: 8.0,
        alignment: body.isNotEmpty ? TextAlign.left : TextAlign.center, // Center title-only slides
      ));
      currentTitle = null;
      currentBodyLines.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        flushSlide();
        currentTitle = line.substring(1, line.length - 1);
      } else {
        currentBodyLines.add(line);
      }
    }
    flushSlide();

    if (slides.isEmpty) {
      final nonEmpty = lines.where((l) => l.trim().isNotEmpty).toList();
      for (int i = 0; i < nonEmpty.length; i++) {
        slides.add(SlideData(
          id: '${i + 1}'.padLeft(2, '0'),
          title: nonEmpty[i].trim(),
          subtitle: '',
          imageUrl: sharedBg,
          opacity: 0.80,
          blur: 8.0,
          alignment: TextAlign.center, // Center title-only slides
        ));
      }
    }

    return slides;
  }

  /// Original hardcoded demo slides used as fallback.
  static List<SlideData> _defaultSlides() {
    return [
      SlideData(
        id: '01',
        title: 'Welcome Home',
        subtitle: '"Peace be with you as we enter this sacred space."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAkigYecE0CmKCuZFuBavKgN8DzoLC7W6Sk1f-88TsL65rI2VnvQzMWzMBXlbn8NSWWMj3iuMzd11L6JwDZ2c8g0xtJ2u0GEE_8MBPBgHYWSh0YLC1YOuFntl9RJBWsp_VN3nRZxNGLDsJHoY5mYOytCHGZhxtVaiBfRrxImcruugnP5uLvBWeSb5hVCEijqYRd-ALjE3KK6juaQxJCITKZ5jv7tLDBMLKDJmX1snESiJYg_J9JA4PfxwbF4qYm65btRgUVbPErgMhD',
        opacity: 0.85,
        blur: 12.0,
      ),
      SlideData(
        id: '02',
        title: 'Worship Set 1',
        subtitle: '"Sing praises to the King, lift up holy hands."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBfTxPcvdVGtfS9lB7z9X1sbdQv7Ilwyi2_gIR8q6qyd9VBoA89wAD1lUuPKcv-bTKvDQfFzhBP6D7Wmk9GXpxYRw7FAL7uNi_tcvc3eygW39xLOHnW1sTQPIVorDBZlUEyEzmhNPNBCDJjA2Ij6dXwIx3KehHleNrkVpRci9akO3-G-MmNbU2NkBiLJ8yIjB5aE0YBidFgvYrgL8hM7H6EzeujgWZY61dJJ3HW-o51FReWjE5GK3bd7aYCLoO6ydFHTSxp8PoX38Pr',
        opacity: 0.70,
        blur: 4.0,
        alignment: TextAlign.center,
        isBold: true,
        isItalic: false,
      ),
      SlideData(
        id: '03',
        title: 'Sermon Notes',
        subtitle: '"Exploring the deep roots of our faith and community."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuBOy_uRm4spX4LG8doBchZNGyiO4lrxmQssiqyI1iBFyFONgeUCM5HyR_WsacGWJatGTaSzstvh3A7zkFM5td3MFYD-xSJa-ueTFJcUUCoIQqVNxm4-ij-iXs9bAGSuinsPa60GOYvzioSwl6ir3hv4gYp9koJQW3t9iNwMMd_0DUn2GN8_JD5pN31SbQYpl2Os2GzmPm7YG8Dsyc4RSXi64168o8knrfH0rilaDoh7w60YpEiQEIcyE0LjRoPA0C6KrEhbju4CVP4f',
        opacity: 0.90,
        blur: 15.0,
        alignment: TextAlign.left,
        isBold: false,
        isItalic: true,
      ),
      SlideData(
        id: '04',
        title: 'Closing Prayer',
        subtitle: '"Go forth in grace, spread peace and wisdom."',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuC7vrdf0-1MvJXE356j2QWAdqpVFRk3iunfVAlO_TA1nQeR2qaAk5aQbTiQ7x4o41c8QKHp0WjP_U0ZZ_TynH_Qj7LxQUjwbVylQIqSgYPdkhsy-2gOEjVYnnsbP5aEwkSlo7v4TvZwP-TgpmFPGT-Dm4H254TZk2sMH_A9jiSsreTqRqwsMd_ORqBdEm5kA6iG1yBUgpPJ28OD9zSa1v0wfl0mj4Cg3lcsoA2w5BUSKkS-ZXLZ_fB_BwPKYOW0DUcuWNXievN0BCOG',
        opacity: 0.80,
        blur: 8.0,
      ),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  void _onSlideChanged() {
    setState(() {});
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  /// Called when the user picks a new image — applies it to ALL slides.
  void _onAllSlidesImageChanged(String dataUrl) {
    setState(() {
      for (final slide in _slides) {
        slide.imageUrl = dataUrl;
      }
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  void _onLogoChanged(String? newLogo) {
    setState(() {
      for (final slide in _slides) {
        slide.logoUrl = newLogo;
      }
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  void _onLogoSizeChanged(double val) {
    setState(() {
      for (final slide in _slides) {
        slide.logoSize = val;
      }
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  void _setActiveSlide(int index) {
    setState(() {
      _activeSlideIndex = index;
      _titleController.text = _slides[index].title;
      _subtitleController.text = _slides[index].subtitle;
    });
    AppSettings.instance.activeSlideIndex = index;
  }

  void _addSlide() {
    setState(() {
      final String nextId = '${_slides.length + 1}'.padLeft(2, '0');
      // Inherit the current slide's background so all slides stay consistent
      final String inheritedBg = _slides[_activeSlideIndex].imageUrl;
      final newSlide = SlideData(
        id: nextId,
        title: 'New Slide',
        subtitle: '"Enter a holy verse or inspirational thought here."',
        imageUrl: inheritedBg,
        opacity: _slides[_activeSlideIndex].opacity,
        blur: _slides[_activeSlideIndex].blur,
        logoUrl: _slides[_activeSlideIndex].logoUrl,
        logoX: _slides[_activeSlideIndex].logoX,
        logoY: _slides[_activeSlideIndex].logoY,
        logoSize: _slides[_activeSlideIndex].logoSize,
      );
      _slides.add(newSlide);
      _setActiveSlide(_slides.length - 1);
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added new slide with the same background.'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

  void _duplicateSlide() {
    setState(() {
      final active = _slides[_activeSlideIndex];
      final String nextId = '${_slides.length + 1}'.padLeft(2, '0');
      final duplicate = SlideData(
        id: nextId,
        title: '${active.title} (Copy)',
        subtitle: active.subtitle,
        imageUrl: active.imageUrl,
        opacity: active.opacity,
        blur: active.blur,
        isBold: active.isBold,
        isItalic: active.isItalic,
        alignment: active.alignment,
        transition: active.transition,
        titleFontSize: active.titleFontSize,
        subtitleFontSize: active.subtitleFontSize,
        logoUrl: active.logoUrl,
        logoX: active.logoX,
        logoY: active.logoY,
        logoSize: active.logoSize,
      );
      _slides.insert(_activeSlideIndex + 1, duplicate);
      _setActiveSlide(_activeSlideIndex + 1);
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Slide duplicated successfully.'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

  void _removeSlide() {
    if (_slides.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A presentation must contain at least one slide.'),
          backgroundColor: SacredColors.error,
        ),
      );
      return;
    }
    setState(() {
      _slides.removeAt(_activeSlideIndex);
      if (_activeSlideIndex >= _slides.length) {
        _activeSlideIndex = _slides.length - 1;
      }
      _setActiveSlide(_activeSlideIndex);
    });
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed slide.'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final activeSlide = _slides[_activeSlideIndex];

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SacredColors.background,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: SacredColors.primary,
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _EditorNavBar(
            onSave: () {
              _saveToRecentList();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Draft saved successfully!'),
                  backgroundColor: SacredColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            onPresent: () {
              AppSettings.instance.updateActiveSlides(_slides);
              AppSettings.instance.activeSlideIndex = _activeSlideIndex;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FullscreenPresenterPage(),
                ),
              );
            },
          ),
        ),
        body: Row(
          children: [
            // Left Panel (Outline)
            if (isDesktop)
              _SlidesOutlineSidebar(
                slides: _slides,
                activeIndex: _activeSlideIndex,
                onSlideSelected: _setActiveSlide,
                onAddSlide: _addSlide,
              ),

            // Middle Workspace (Canvas)
            Expanded(
              child: (!isDesktop && _mobileSelectedTab != 1)
                  ? (_mobileSelectedTab == 0
                      ? _SlidesOutlineSidebar(
                          slides: _slides,
                          activeIndex: _activeSlideIndex,
                          onSlideSelected: _setActiveSlide,
                          onAddSlide: _addSlide,
                        )
                      : _PropertiesSidebar(
                          activeSlide: activeSlide,
                          titleController: _titleController,
                          subtitleController: _subtitleController,
                          onSlideChanged: _onSlideChanged,
                          onDuplicate: _duplicateSlide,
                          onDelete: _removeSlide,
                          onAllSlidesImageChanged: _onAllSlidesImageChanged,
                          onLogoChanged: _onLogoChanged,
                          onLogoSizeChanged: _onLogoSizeChanged,
                        ))
                  : _LiveWorkspaceCanvas(
                      activeSlide: activeSlide,
                      slideCount: _slides.length,
                      activeIndex: _activeSlideIndex,
                      onNavigate: (index) {
                        if (index >= 0 && index < _slides.length) {
                          _setActiveSlide(index);
                        }
                      },
                      onLogoPositionChanged: (x, y) {
                        setState(() {
                          for (final slide in _slides) {
                            slide.logoX = x;
                            slide.logoY = y;
                          }
                        });
                        AppSettings.instance.updateActiveSlides(_slides);
                        _saveToRecentList();
                      },
                    ),
            ),

            // Right Panel (Properties)
            if (isDesktop)
              _PropertiesSidebar(
                activeSlide: activeSlide,
                titleController: _titleController,
                subtitleController: _subtitleController,
                onSlideChanged: _onSlideChanged,
                onDuplicate: _duplicateSlide,
                onDelete: _removeSlide,
                onAllSlidesImageChanged: _onAllSlidesImageChanged,
                onLogoChanged: _onLogoChanged,
                onLogoSizeChanged: _onLogoSizeChanged,
              ),
          ],
        ),
        bottomNavigationBar: !isDesktop
            ? BottomNavigationBar(
                currentIndex: _mobileSelectedTab,
                selectedItemColor: SacredColors.primary,
                unselectedItemColor: SacredColors.onSurfaceVariant,
                onTap: (index) {
                  setState(() {
                    _mobileSelectedTab = index;
                  });
                },
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.view_carousel_outlined),
                    label: 'Outline',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.aspect_ratio),
                    label: 'Live Canvas',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.tune),
                    label: 'Properties',
                  ),
                ],
              )
            : null,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            right: isDesktop ? 340.0 : 0.0,
          ),
          child: _FloatingExportFAB(),
        ),
      ),
    );
  }
}

/// Navigation Bar specifically customized for presentation edits.
class _EditorNavBar extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onPresent;

  const _EditorNavBar({
    required this.onSave,
    required this.onPresent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(
            color: SacredColors.outlineVariant,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: SacredColors.primary),
                tooltip: 'Back to Dashboard',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: 8),
              Text(
                'Live Deck',
                style: SacredTypography.headlineMd(context).copyWith(
                  color: SacredColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 24),
              // Search slides indicator bar
              Container(
                height: 36,
                width: 220,
                decoration: BoxDecoration(
                  color: SacredColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: SacredColors.onSurfaceVariant,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: SacredTypography.labelLg(context).copyWith(
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search slides...',
                          hintStyle: TextStyle(
                            color: SacredColors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.cloud_off, color: SacredColors.onSurfaceVariant),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.notifications_none, color: SacredColors.onSurfaceVariant),
                onPressed: () {},
              ),
              SizedBox(width: 8),
              _EditorPillButton(
                onPressed: onSave,
                label: 'Save draft',
              ),
              SizedBox(width: 8),
              _EditorPillButton(
                onPressed: onPresent,
                label: 'Present',
              ),
              SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDY8LRvDsvImHRP9Eyjn2RGwg022ZHM4FoVMPdZnT2fyViMfbS8ohEhylRVfHmoHu1kyC_q_cBcLEx1NXiT-G3waNAarbu9q6pUPn_mowxq46gdELRL_s56PZetoJLTB4lHkX0N7uLdQUD72S2aNL_8wPQOr2OaNCVxquY0YoIQmH6OoY8xIjP48hbEJbHCa-qwHGOjeERQchb1gcWp_88oyubY1UaIpPceFAOfQ8vdglZkwGaa1FVK_2EMqQ1kpZ3yKGCVrqzAd5qA',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Outline Navigation Sidebar (Slide list builder)
class _SlidesOutlineSidebar extends StatelessWidget {
  final List<SlideData> slides;
  final int activeIndex;
  final ValueChanged<int> onSlideSelected;
  final VoidCallback onAddSlide;

  const _SlidesOutlineSidebar({
    required this.slides,
    required this.activeIndex,
    required this.onSlideSelected,
    required this.onAddSlide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
          right: BorderSide(
            color: SacredColors.outlineVariant,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar title section
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SLIDES',
                  style: SacredTypography.labelLg(context).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: SacredColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${slides.length} Total',
                  style: SacredTypography.labelSm(context).copyWith(
                    color: SacredColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable thumbnail cards
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                final slide = slides[index];
                final bool isActive = index == activeIndex;

                return Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: _SlideThumbnailCard(
                    slide: slide,
                    isActive: isActive,
                    indexText: '${index + 1}'.padLeft(2, '0'),
                    onTap: () => onSlideSelected(index),
                  ),
                );
              },
            ),
          ),

          // Add Slide Dashed CTA Button
          Padding(
            padding: EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: SacredColors.outlineVariant,
                strokeWidth: 2.0,
                radius: 12.0,
              ),
              child: InkWell(
                onTap: onAddSlide,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: SacredColors.onSurfaceVariant),
                      SizedBox(width: 8),
                      Text(
                        'Add Slide',
                        style: SacredTypography.labelLg(context).copyWith(
                          color: SacredColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic thumbnail representation containing saturation grayscale transition.
class _SlideThumbnailCard extends StatefulWidget {
  final SlideData slide;
  final bool isActive;
  final String indexText;
  final VoidCallback onTap;

  const _SlideThumbnailCard({
    required this.slide,
    required this.isActive,
    required this.indexText,
    required this.onTap,
  });

  @override
  State<_SlideThumbnailCard> createState() => _SlideThumbnailCardState();
}

class _SlideThumbnailCardState extends State<_SlideThumbnailCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Pure saturation matrix values
    const grayscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0, // Red
      0.2126, 0.7152, 0.0722, 0, 0, // Green
      0.2126, 0.7152, 0.0722, 0, 0, // Blue
      0, 0, 0, 1, 0, // Alpha
    ];

    final bool renderFullColor = widget.isActive || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: widget.isActive ? SacredShadows.sacred : null,
                border: Border.all(
                  color: widget.isActive
                      ? SacredColors.primary
                      : (_isHovered
                          ? SacredColors.primary.withValues(alpha: 0.5)
                          : SacredColors.outlineVariant),
                  width: widget.isActive ? 2.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      // Grayscale ColorFilter Transition Layer
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ColorFiltered(
                            colorFilter: renderFullColor
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                : const ColorFilter.matrix(grayscaleMatrix),
                            child: widget.slide.imageUrl.isEmpty
                                ? Container(color: Colors.black)
                                : widget.slide.imageUrl.startsWith('data:')
                                    ? Image.memory(
                                        _decodeDataUrl(widget.slide.imageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, e, s) => Container(
                                          color: SacredColors.surfaceContainerHigh,
                                          child: Icon(Icons.image, color: SacredColors.primary),
                                        ),
                                      )
                                    : Image.network(
                                        widget.slide.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, e, s) => Container(
                                          color: SacredColors.surfaceContainerHigh,
                                          child: Icon(Icons.image, color: SacredColors.primary),
                                        ),
                                      ),
                          ),
                        ),
                      ),

                      // Index Slide Badge
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.isActive ? SacredColors.primary : SacredColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.indexText,
                            style: SacredTypography.labelSm(context).copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: widget.isActive ? Colors.white : SacredColors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                widget.slide.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SacredTypography.labelSm(context).copyWith(
                  fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                  color: widget.isActive ? SacredColors.primary : SacredColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Central Preview Canvas workspace featuring real-time state mirroring.
class _LiveWorkspaceCanvas extends StatelessWidget {
  final SlideData activeSlide;
  final int slideCount;
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final Function(double, double)? onLogoPositionChanged;

  const _LiveWorkspaceCanvas({
    required this.activeSlide,
    required this.slideCount,
    required this.activeIndex,
    required this.onNavigate,
    this.onLogoPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SacredColors.surfaceContainerLow,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AspectRatio 16:9 Workspace boundaries
          Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          offset: const Offset(0, 20),
                          blurRadius: 40,
                        ),
                      ],
                      border: Border.all(
                        color: SacredColors.outlineVariant,
                        width: 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          // Background Image Layer with custom opacity and live blurs
                          Positioned.fill(
                            child: activeSlide.imageUrl.isEmpty
                                ? Container(color: Colors.black)
                                : ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: activeSlide.blur,
                                      sigmaY: activeSlide.blur,
                                    ),
                                    child: activeSlide.imageUrl.startsWith('data:')
                                        ? Image.memory(
                                            _decodeDataUrl(activeSlide.imageUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: SacredColors.surfaceContainerHighest),
                                          )
                                        : Image.network(
                                            activeSlide.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Container(color: SacredColors.surfaceContainerHighest),
                                          ),
                                  ),
                          ),

                          // Translucent overlay blending
                          if (activeSlide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 1.0 - activeSlide.opacity),
                              ),
                            ),

                          // Purple spiritual overlay blending
                          if (activeSlide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                color: SacredColors.primary.withValues(alpha: 0.20),
                              ),
                            ),

                          // Typography Text Elements
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 48.0, vertical: 32.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    activeSlide.title,
                                    textAlign: activeSlide.alignment,
                                    style: GoogleFonts.getFont(
                                      AppSettings.instance.fontFamily,
                                      textStyle: TextStyle(
                                        fontSize: activeSlide.titleFontSize,
                                        color: Colors.white,
                                        fontWeight: activeSlide.isBold ? FontWeight.bold : FontWeight.normal,
                                        fontStyle: activeSlide.isItalic ? FontStyle.italic : FontStyle.normal,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black45,
                                            offset: Offset(0, 4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    width: 96,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: SacredColors.secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        activeSlide.subtitle,
                                        textAlign: activeSlide.alignment,
                                        style: GoogleFonts.inter(
                                          textStyle: TextStyle(
                                            fontSize: activeSlide.subtitleFontSize,
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontStyle: FontStyle.italic,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black45,
                                                offset: Offset(0, 2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Draggable Logo layer — handled by a dedicated StatefulWidget
                          // so the drag position is tracked locally without parent rebuilds.
                          if (activeSlide.logoUrl != null && activeSlide.logoUrl!.isNotEmpty)
                            Positioned.fill(
                              child: _DraggableLogoLayer(
                                logoUrl: activeSlide.logoUrl!,
                                logoX: activeSlide.logoX,
                                logoY: activeSlide.logoY,
                                logoSize: activeSlide.logoSize,
                                onPositionChanged: onLogoPositionChanged,
                              ),
                            ),


                          // Floating Canvas Preview Controls
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _CanvasPreviewBar(
                                activeIndex: activeIndex,
                                totalCount: slideCount,
                                onNavigate: onNavigate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Aspect/Resolution details footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.aspect_ratio, color: SacredColors.outline, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '16:9 Aspect Ratio',
                    style: SacredTypography.labelSm(context).copyWith(
                      color: SacredColors.outline,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 24),
              Row(
                children: [
                  Icon(Icons.hd_outlined, color: SacredColors.outline, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '4K Resolution (3840x2160)',
                    style: SacredTypography.labelSm(context).copyWith(
                      color: SacredColors.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Micro player bar sitting inside active canvas workspace.
class _CanvasPreviewBar extends StatelessWidget {
  final int activeIndex;
  final int totalCount;
  final ValueChanged<int> onNavigate;

  const _CanvasPreviewBar({
    required this.activeIndex,
    required this.totalCount,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: SacredColors.outlineVariant,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.skip_previous, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: activeIndex > 0 ? () => onNavigate(activeIndex - 1) : null,
          ),
          SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: SacredColors.primary,
            child: IconButton(
              icon: Icon(Icons.play_arrow, size: 16, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Starting slideshow preview...'),
                    backgroundColor: SacredColors.primary,
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.skip_next, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: activeIndex < totalCount - 1 ? () => onNavigate(activeIndex + 1) : null,
          ),
          Container(
            width: 1,
            height: 16,
            color: SacredColors.outlineVariant,
            margin: EdgeInsets.symmetric(horizontal: 16),
          ),
          Text(
            'Slide ${activeIndex + 1} of $totalCount',
            style: SacredTypography.labelSm(context).copyWith(
              color: SacredColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Draggable Logo Layer
//
// Uses local StatefulWidget state so that ongoing pan gestures do NOT trigger
// parent rebuilds. The GestureDetector stays stable under the pointer during
// the entire drag, and the parent is updated on pan-end (and throttled during).
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableLogoLayer extends StatefulWidget {
  final String logoUrl;
  final double logoX;   // relative 0.0–1.0
  final double logoY;   // relative 0.0–1.0
  final double logoSize; // base pixel size at 960px canvas width
  final Function(double, double)? onPositionChanged;

  const _DraggableLogoLayer({
    required this.logoUrl,
    required this.logoX,
    required this.logoY,
    required this.logoSize,
    this.onPositionChanged,
  });

  @override
  State<_DraggableLogoLayer> createState() => _DraggableLogoLayerState();
}

class _DraggableLogoLayerState extends State<_DraggableLogoLayer> {
  /// Pixel position tracked locally during an active drag.
  /// null means we use the externally stored relative position.
  double? _dragPixelX;
  double? _dragPixelY;

  @override
  void didUpdateWidget(_DraggableLogoLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the slide changes (different logoUrl or position committed by parent)
    // reset local drag state so we pick up the new stored position.
    if (oldWidget.logoUrl != widget.logoUrl) {
      _dragPixelX = null;
      _dragPixelY = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth;
      final double h = constraints.maxHeight;
      if (w == 0 || h == 0) return const SizedBox.expand();

      final double scale = w / 960.0;
      final double scaledLogoSize = (widget.logoSize * scale).clamp(10.0, w);
      final double maxLeft = w - scaledLogoSize;
      final double maxTop  = h - scaledLogoSize;

      // During a drag, use local pixel coords; otherwise derive from stored relative.
      final double left = (_dragPixelX ?? (widget.logoX * w)).clamp(0.0, maxLeft);
      final double top  = (_dragPixelY ?? (widget.logoY * h)).clamp(0.0, maxTop);

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: left,
            top: top,
            width: scaledLogoSize,
            height: scaledLogoSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {
                // Capture pixel start position so cumulative delta is always correct.
                setState(() {
                  _dragPixelX = left;
                  _dragPixelY = top;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _dragPixelX = ((_dragPixelX ?? left) + details.delta.dx)
                      .clamp(0.0, maxLeft);
                  _dragPixelY = ((_dragPixelY ?? top) + details.delta.dy)
                      .clamp(0.0, maxTop);
                });
                // Sync to parent during drag (throttled by Flutter's frame rate).
                widget.onPositionChanged?.call(
                  _dragPixelX! / w,
                  _dragPixelY! / h,
                );
              },
              onPanEnd: (_) {
                if (_dragPixelX != null) {
                  widget.onPositionChanged?.call(
                    _dragPixelX! / w,
                    _dragPixelY! / h,
                  );
                }
                // Keep local position so the logo stays where released.
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: widget.logoUrl.startsWith('data:')
                      ? Image.memory(
                          _decodeDataUrl(widget.logoUrl),
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.black45,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white, size: 24),
                          ),
                        )
                      : Image.network(
                          widget.logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Container(
                            color: Colors.black45,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white, size: 24),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}


class _PropertiesSidebar extends StatelessWidget {
  final SlideData activeSlide;
  final TextEditingController titleController;
  final TextEditingController subtitleController;
  final VoidCallback onSlideChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<String> onAllSlidesImageChanged;
  final ValueChanged<String?> onLogoChanged;
  final ValueChanged<double> onLogoSizeChanged;

  const _PropertiesSidebar({
    required this.activeSlide,
    required this.titleController,
    required this.subtitleController,
    required this.onSlideChanged,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAllSlidesImageChanged,
    required this.onLogoChanged,
    required this.onLogoSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
          left: BorderSide(
            color: SacredColors.outlineVariant,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Properties',
              style: SacredTypography.headlineMd(context).copyWith(
                color: SacredColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),

            // Text Inputs Editor
            Text(
              'SLIDE TITLE',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: titleController,
              onChanged: (text) {
                activeSlide.title = text;
                onSlideChanged();
              },
              style: SacredTypography.bodyLg(context).copyWith(
                color: SacredColors.onSurface,
              ),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SacredColors.outlineVariant),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SacredColors.primary),
                ),
              ),
            ),
            SizedBox(height: 24),

            Text(
              'SLIDE QUOTE / SUBTITLE',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: subtitleController,
              onChanged: (text) {
                activeSlide.subtitle = text;
                onSlideChanged();
              },
              style: SacredTypography.bodyMd(context).copyWith(
                color: SacredColors.onSurface,
              ),
              decoration: InputDecoration(
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SacredColors.outlineVariant),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SacredColors.primary),
                ),
              ),
            ),
            SizedBox(height: 16),

            // ── Font Size Controls ──────────────────────────────
            Text(
              'TITLE FONT SIZE',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: activeSlide.titleFontSize,
                    min: 16.0,
                    max: 96.0,
                    divisions: 16,
                    activeColor: SacredColors.primary,
                    inactiveColor: SacredColors.surfaceContainerHighest,
                    onChanged: (val) {
                      activeSlide.titleFontSize = val;
                      onSlideChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${activeSlide.titleFontSize.toInt()}pt',
                    style: SacredTypography.labelSm(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: SacredColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            Text(
              'SUBTITLE FONT SIZE',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: activeSlide.subtitleFontSize,
                    min: 10.0,
                    max: 48.0,
                    divisions: 19,
                    activeColor: SacredColors.primary,
                    inactiveColor: SacredColors.surfaceContainerHighest,
                    onChanged: (val) {
                      activeSlide.subtitleFontSize = val;
                      onSlideChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${activeSlide.subtitleFontSize.toInt()}pt',
                    style: SacredTypography.labelSm(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: SacredColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Typography formatting toggles
            Row(
              children: [
                Expanded(
                  child: _FormatToggleIcon(
                    icon: Icons.format_bold,
                    isSelected: activeSlide.isBold,
                    onPressed: () {
                      activeSlide.isBold = !activeSlide.isBold;
                      onSlideChanged();
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _FormatToggleIcon(
                    icon: Icons.format_italic,
                    isSelected: activeSlide.isItalic,
                    onPressed: () {
                      activeSlide.isItalic = !activeSlide.isItalic;
                      onSlideChanged();
                    },
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: PopupMenuButton<TextAlign>(
                    initialValue: activeSlide.alignment,
                    onSelected: (alignment) {
                      activeSlide.alignment = alignment;
                      onSlideChanged();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: TextAlign.left,
                        child: Row(
                          children: [
                            Icon(Icons.format_align_left),
                            SizedBox(width: 8),
                            Text('Left'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TextAlign.center,
                        child: Row(
                          children: [
                            Icon(Icons.format_align_center),
                            SizedBox(width: 8),
                            Text('Center'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TextAlign.right,
                        child: Row(
                          children: [
                            Icon(Icons.format_align_right),
                            SizedBox(width: 8),
                            Text('Right'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: SacredColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SacredColors.outlineVariant),
                      ),
                      child: Icon(
                        activeSlide.alignment == TextAlign.left
                            ? Icons.format_align_left
                            : (activeSlide.alignment == TextAlign.right
                                ? Icons.format_align_right
                                : Icons.format_align_center),
                        size: 20,
                        color: SacredColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'BACKGROUND IMAGE',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 12),
            _BackgroundImageEditorCard(
              imageUrl: activeSlide.imageUrl,
              onImageChanged: onAllSlidesImageChanged,
            ),
            SizedBox(height: 24),

            // Logo controls
            Text(
              'SLIDE LOGO',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 12),
            _LogoImageEditorCard(
              logoUrl: activeSlide.logoUrl,
              onLogoChanged: onLogoChanged,
            ),
            if (activeSlide.logoUrl != null && activeSlide.logoUrl!.isNotEmpty) ...[
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Logo Size', style: SacredTypography.labelSm(context)),
                  Text(
                    '${activeSlide.logoSize.toInt()}px',
                    style: SacredTypography.labelSm(context).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: activeSlide.logoSize,
                min: 40.0,
                max: 200.0,
                activeColor: SacredColors.primary,
                inactiveColor: SacredColors.surfaceContainerHighest,
                onChanged: onLogoSizeChanged,
              ),
            ],
            SizedBox(height: 24),

            // Opacity slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Opacity', style: SacredTypography.labelSm(context)),
                Text(
                  '${(activeSlide.opacity * 100).toInt()}%',
                  style: SacredTypography.labelSm(context).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: activeSlide.opacity,
              min: 0.0,
              max: 1.0,
              activeColor: SacredColors.primary,
              inactiveColor: SacredColors.surfaceContainerHighest,
              onChanged: (val) {
                activeSlide.opacity = val;
                onSlideChanged();
              },
            ),
            SizedBox(height: 16),

            // Blur slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Blur', style: SacredTypography.labelSm(context)),
                Text(
                  '${activeSlide.blur.toInt()}px',
                  style: SacredTypography.labelSm(context).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: activeSlide.blur,
              min: 0.0,
              max: 30.0,
              activeColor: SacredColors.primary,
              inactiveColor: SacredColors.surfaceContainerHighest,
              onChanged: (val) {
                activeSlide.blur = val;
                onSlideChanged();
              },
            ),
            SizedBox(height: 32),

            // Transition selector dropdown
            Text(
              'TRANSITION',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: SacredColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SacredColors.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeSlide.transition,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down),
                  onChanged: (val) {
                    if (val != null) {
                      activeSlide.transition = val;
                      onSlideChanged();
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 'Cross Dissolve', child: Text('Cross Dissolve')),
                    DropdownMenuItem(value: 'Wipe Down', child: Text('Wipe Down')),
                    DropdownMenuItem(value: 'Sacred Bloom', child: Text('Sacred Bloom')),
                    DropdownMenuItem(value: 'Soft Fade', child: Text('Soft Fade')),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),

            // Quick actions duplicated/removed
            ElevatedButton.icon(
              onPressed: onDuplicate,
              icon: Icon(Icons.content_copy, size: 18),
              label: const Text('Duplicate Slide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SacredColors.surfaceContainerHighest,
                foregroundColor: SacredColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove Slide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: SacredColors.errorContainer,
                foregroundColor: SacredColors.onErrorContainer,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subcomponent format toggle buttons.
class _FormatToggleIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _FormatToggleIcon({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? SacredColors.primaryFixedDim.withValues(alpha: 0.3) : SacredColors.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? SacredColors.primary : SacredColors.outlineVariant,
            width: 1.0,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? SacredColors.primary : SacredColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Image card selector inside properties — opens system file picker on tap.
class _BackgroundImageEditorCard extends StatefulWidget {
  final String imageUrl;
  final ValueChanged<String> onImageChanged;

  const _BackgroundImageEditorCard({
    required this.imageUrl,
    required this.onImageChanged,
  });

  @override
  State<_BackgroundImageEditorCard> createState() => _BackgroundImageEditorCardState();
}

class _BackgroundImageEditorCardState extends State<_BackgroundImageEditorCard> {
  bool _isHovered = false;
  bool _isPicking = false;

  void _pickImage() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb, // on web, bytes come in-memory
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      final picked = result.files.first;
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = picked.bytes;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }

      if (bytes == null) {
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      // Determine MIME type from extension
      final ext = (picked.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'gif'
              ? 'image/gif'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';

      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      widget.onImageChanged(dataUrl);
    } catch (err) {
      debugPrint('Error picking image: $err');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDataUrl = widget.imageUrl.startsWith('data:');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickImage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: isDataUrl
                      ? Image.memory(
                          _decodeDataUrl(widget.imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: SacredColors.surfaceContainerHigh,
                            child: Icon(Icons.image, color: SacredColors.primary),
                          ),
                        )
                      : Image.network(
                          widget.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            color: SacredColors.surfaceContainerHigh,
                            child: Icon(Icons.image, color: SacredColors.primary),
                          ),
                        ),
                ),

                // Hover / loading overlay
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: (_isHovered || _isPicking) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: SacredColors.primary.withValues(alpha: 0.65),
                      alignment: Alignment.center,
                      child: _isPicking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload_file, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Choose Image',
                                  style: SacredTypography.labelSm(context).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}

/// Floating PPTX Export Action Button featuring animate pro badging
class _FloatingExportFAB extends StatefulWidget {
  @override
  State<_FloatingExportFAB> createState() => _FloatingExportFABState();
}

class _FloatingExportFABState extends State<_FloatingExportFAB> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.diagonal3Values(_isHovered ? 1.03 : 1.0, _isHovered ? 1.03 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        child: FloatingActionButton.extended(
          onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExportPage()),
        );
      },
          backgroundColor: SacredColors.secondaryContainer,
          elevation: _isHovered ? 16 : 8,
          label: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.file_download,
                    color: SacredColors.onSecondaryFixed,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'EXPORT PPTX',
                    style: SacredTypography.labelLg(context).copyWith(
                      color: SacredColors.onSecondaryFixed,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -24,
                right: -16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SacredColors.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
}

/// Generic Navigation pill controls.
class _EditorPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _EditorPillButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: SacredColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: SacredTypography.labelSm(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// painter dashed outline border representation.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dash = 4.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashPath.addPath(
          measurePath.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo card selector inside properties — opens system file picker on tap and handles transparency preserving compression.
class _LogoImageEditorCard extends StatefulWidget {
  final String? logoUrl;
  final ValueChanged<String?> onLogoChanged;

  const _LogoImageEditorCard({
    required this.logoUrl,
    required this.onLogoChanged,
  });

  @override
  State<_LogoImageEditorCard> createState() => _LogoImageEditorCardState();
}

class _LogoImageEditorCardState extends State<_LogoImageEditorCard> {
  bool _isHovered = false;
  bool _isPicking = false;

  void _pickImage() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      final picked = result.files.first;
      Uint8List? bytes;

      if (kIsWeb) {
        bytes = picked.bytes;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }

      if (bytes == null) {
        if (mounted) setState(() => _isPicking = false);
        return;
      }

      // Determine MIME type from extension (keep PNG to preserve transparency)
      final ext = (picked.extension ?? 'png').toLowerCase();
      final mime = ext == 'jpeg' || ext == 'jpg'
          ? 'image/jpeg'
          : ext == 'gif'
              ? 'image/gif'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/png';

      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      widget.onLogoChanged(dataUrl);
    } catch (err) {
      debugPrint('Error picking logo: $err');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLogo = widget.logoUrl != null && widget.logoUrl!.isNotEmpty;
    final bool isDataUrl = hasLogo && widget.logoUrl!.startsWith('data:');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: SacredColors.surfaceContainerHigh,
                border: Border.all(
                  color: hasLogo ? SacredColors.outlineVariant : SacredColors.outline,
                  style: hasLogo ? BorderStyle.solid : BorderStyle.none,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      // If no logo, show a nice upload placeholder with CustomPaint dashed border
                      if (!hasLogo)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DashedBorderPainter(
                              color: SacredColors.outline,
                              radius: 12,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 32, color: SacredColors.onSurfaceVariant),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload Logo (PNG/JPEG)',
                                    style: SacredTypography.labelSm(context).copyWith(
                                      color: SacredColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        // Logo display with checkerboard-like neutral background to see transparency
                        Positioned.fill(
                          child: Container(
                            color: Colors.black12, // subtle dark background to see light logos
                            padding: const EdgeInsets.all(16),
                            child: isDataUrl
                                ? Image.memory(
                                    _decodeDataUrl(widget.logoUrl!),
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => Center(
                                      child: Icon(Icons.broken_image, color: SacredColors.primary),
                                    ),
                                  )
                                : Image.network(
                                    widget.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => Center(
                                      child: Icon(Icons.broken_image, color: SacredColors.primary),
                                    ),
                                  ),
                          ),
                        ),

                      // Hover/loading overlay
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: (_isHovered || _isPicking) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            color: SacredColors.primary.withValues(alpha: 0.65),
                            alignment: Alignment.center,
                            child: _isPicking
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_file, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        hasLogo ? 'Replace Logo' : 'Choose Logo',
                                        style: SacredTypography.labelSm(context).copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
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
              ),
            ),
          ),
          // Delete / Remove logo button overlay when hasLogo
          if (hasLogo && !_isPicking)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  widget.onLogoChanged(null);
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MainPointGroup {
  String title;
  final List<String> lines;

  MainPointGroup({required this.title, required this.lines});
}

class SubPointBlock {
  final String header;
  final List<String> bodyLines = [];
  final List<String> romanLines = [];

  SubPointBlock({required this.header});
}
