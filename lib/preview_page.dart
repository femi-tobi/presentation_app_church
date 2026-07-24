import 'package:flutter/services.dart';
import 'dart:async';
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
  return decodeDataUrl(dataUrl);
}


class PreviewPage extends StatefulWidget {
  final String presentationId;
  final String outlineText;
  final String selectedTheme;
  final List<SlideData>? initialSlides;
  final List<SlideSection>? initialSections;

  const PreviewPage({
    super.key,
    required this.presentationId,
    this.outlineText = '',
    this.selectedTheme = 'Minimal',
    this.initialSlides,
    this.initialSections,
  });

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late List<SlideSection> _sections;
  late List<SlideData> _slides;
  int _activeSlideIndex = 0;
  int _mobileSelectedTab = 1; // 0: Slides Outline, 1: Live Canvas, 2: Properties
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  bool _applyToAll = false;

  void _applyActiveStylesToAll() {
    if (_slides.isEmpty) return;
    final active = _slides[_activeSlideIndex];
    for (final slide in _slides) {
      if (slide.id == active.id) continue;
      slide.imageUrl = active.imageUrl;
      slide.bgColorValue = active.bgColorValue;
      slide.opacity = active.opacity;
      slide.blur = active.blur;
      slide.isBold = active.isBold;
      slide.isItalic = active.isItalic;
      slide.alignment = active.alignment;
      slide.transition = active.transition;
      slide.titleFontSize = active.titleFontSize;
      slide.subtitleFontSize = active.subtitleFontSize;
      slide.logoUrl = active.logoUrl;
      slide.logoX = active.logoX;
      slide.logoY = active.logoY;
      slide.logoSize = active.logoSize;
      slide.textX = active.textX;
      slide.textY = active.textY;
    }
  }

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
    
    if (widget.initialSections != null && widget.initialSections!.isNotEmpty) {
      _sections = List.from(widget.initialSections!.map((s) => SlideSection(
        id: s.id,
        name: s.name,
        slideIds: List.from(s.slideIds),
        isCollapsed: s.isCollapsed,
        colorValue: s.colorValue,
      )));
    } else {
      _sections = [
        SlideSection(
          id: 'section_01',
          name: 'Section 1',
          slideIds: _slides.map((s) => s.id).toList(),
        )
      ];
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
      sections: _sections,
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
    if (_applyToAll) {
      _applyActiveStylesToAll();
    } else {
      _slides[_activeSlideIndex].update();
    }
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  /// Called when the user picks a new image.
  void _onSlideImageChanged(String dataUrl) {
    _slides[_activeSlideIndex].imageUrl = dataUrl;
    _slides[_activeSlideIndex].bgColorValue = 0xFF000000;
    if (_applyToAll) {
      _applyActiveStylesToAll();
    } else {
      _slides[_activeSlideIndex].update();
    }
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  void _onLogoChanged(String? newLogo) {
    _slides[_activeSlideIndex].logoUrl = newLogo;
    if (_applyToAll) {
      _applyActiveStylesToAll();
    } else {
      _slides[_activeSlideIndex].update();
    }
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
  }

  void _onLogoSizeChanged(double val) {
    _slides[_activeSlideIndex].logoSize = val;
    if (_applyToAll) {
      _applyActiveStylesToAll();
    } else {
      _slides[_activeSlideIndex].update();
    }
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

  void _syncSlidesFromSections() {
    final activeSlideId = _slides.isNotEmpty ? _slides[_activeSlideIndex].id : null;
    final List<SlideData> ordered = [];
    for (final section in _sections) {
      for (final slideId in section.slideIds) {
        final slide = _slides.firstWhere((s) => s.id == slideId, orElse: () => null as dynamic);
        if (slide != null) {
          slide.sectionId = section.id;
          ordered.add(slide);
        }
      }
    }
    for (final slide in _slides) {
      if (!ordered.any((s) => s.id == slide.id)) {
        ordered.add(slide);
        if (_sections.isNotEmpty) {
          _sections.last.slideIds.add(slide.id);
          slide.sectionId = _sections.last.id;
        } else {
          final fallbackSection = SlideSection(id: 'section_fallback', name: 'Section 1', slideIds: [slide.id]);
          _sections.add(fallbackSection);
          slide.sectionId = fallbackSection.id;
        }
      }
    }
    _slides = ordered;
    if (activeSlideId != null) {
      final newIdx = _slides.indexWhere((s) => s.id == activeSlideId);
      if (newIdx != -1) {
        _activeSlideIndex = newIdx;
        AppSettings.instance.activeSlideIndex = newIdx;
      }
    }
    AppSettings.instance.updateActiveSlides(_slides);
    _saveToRecentList();
    setState(() {});
  }

  void _addSection(String name, {int? index, List<String>? slideIds}) {
    final newSection = SlideSection(
      id: 'section_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      slideIds: slideIds ?? [],
    );
    setState(() {
      if (index != null) {
        _sections.insert(index, newSection);
      } else {
        _sections.add(newSection);
      }
    });
    _syncSlidesFromSections();
  }

  void _addSectionBeforeSlide(String slideId, String name) {
    int sectionIdx = -1;
    int slideIdxInSection = -1;
    for (int i = 0; i < _sections.length; i++) {
      final idx = _sections[i].slideIds.indexOf(slideId);
      if (idx != -1) {
        sectionIdx = i;
        slideIdxInSection = idx;
        break;
      }
    }
    if (sectionIdx != -1) {
      final existingSection = _sections[sectionIdx];
      final List<String> beforeSlides = existingSection.slideIds.sublist(0, slideIdxInSection);
      final List<String> afterSlides = existingSection.slideIds.sublist(slideIdxInSection);
      
      setState(() {
        existingSection.slideIds = beforeSlides;
        final newSection = SlideSection(
          id: 'section_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          slideIds: afterSlides,
        );
        _sections.insert(sectionIdx + 1, newSection);
      });
      _syncSlidesFromSections();
    }
  }

  void _deleteSection(String id) {
    if (_sections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the last remaining section.')),
      );
      return;
    }
    final sectionIdx = _sections.indexWhere((s) => s.id == id);
    if (sectionIdx != -1) {
      final sectionToDelete = _sections[sectionIdx];
      setState(() {
        final targetSectionIdx = sectionIdx > 0 ? sectionIdx - 1 : 0;
        final targetSection = _sections[targetSectionIdx == sectionIdx ? 1 : targetSectionIdx];
        targetSection.slideIds.addAll(sectionToDelete.slideIds);
        _sections.removeAt(sectionIdx);
      });
      _syncSlidesFromSections();
    }
  }

  void _renameSection(String id, String newName) {
    final idx = _sections.indexWhere((s) => s.id == id);
    if (idx != -1) {
      setState(() {
        _sections[idx].name = newName;
      });
      _saveToRecentList();
    }
  }

  void _moveSection(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= _sections.length) return;
    setState(() {
      final sec = _sections.removeAt(fromIndex);
      _sections.insert(toIndex, sec);
    });
    _syncSlidesFromSections();
  }

  void _moveSlideToSection(String slideId, String targetSectionId, int targetIndex) {
    setState(() {
      for (final section in _sections) {
        section.slideIds.remove(slideId);
      }
      final targetSection = _sections.firstWhere((s) => s.id == targetSectionId);
      if (targetIndex >= 0 && targetIndex <= targetSection.slideIds.length) {
        targetSection.slideIds.insert(targetIndex, slideId);
      } else {
        targetSection.slideIds.add(slideId);
      }
    });
    _syncSlidesFromSections();
  }

  void _moveSlideInOutline(int from, int to) {
    if (to < 0 || to >= _slides.length) return;
    final slideId = _slides[from].id;
    final targetSlideId = _slides[to].id;
    
    setState(() {
      String? fromSectionId;
      String? toSectionId;
      for (final sec in _sections) {
        if (sec.slideIds.contains(slideId)) fromSectionId = sec.id;
        if (sec.slideIds.contains(targetSlideId)) toSectionId = sec.id;
      }
      
      if (fromSectionId != null && toSectionId != null) {
        final fromSec = _sections.firstWhere((s) => s.id == fromSectionId);
        final toSec = _sections.firstWhere((s) => s.id == toSectionId);
        
        fromSec.slideIds.remove(slideId);
        final targetIdx = toSec.slideIds.indexOf(targetSlideId);
        final insertIdx = to > from ? targetIdx + 1 : targetIdx;
        toSec.slideIds.insert(insertIdx.clamp(0, toSec.slideIds.length), slideId);
      }
    });
    _syncSlidesFromSections();
  }

  void _showSlideRenameDialog(BuildContext context, SlideData slide) {
    final titleController = TextEditingController(text: slide.title);
    final subtitleController = TextEditingController(text: slide.subtitle);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Slide Content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                decoration: const InputDecoration(labelText: 'Subtitle'),
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  slide.title = titleController.text.trim();
                  slide.subtitle = subtitleController.text.trim();
                });
                slide.update();
                _saveToRecentList();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _duplicateSection(String sectionId) {
    final sectionIdx = _sections.indexWhere((s) => s.id == sectionId);
    if (sectionIdx != -1) {
      final sourceSection = _sections[sectionIdx];
      final List<String> duplicatedSlideIds = [];
      
      for (final slideId in sourceSection.slideIds) {
        final slideIdx = _slides.indexWhere((s) => s.id == slideId);
        if (slideIdx != -1) {
          final original = _slides[slideIdx];
          final String newSlideId = 'slide_${DateTime.now().millisecondsSinceEpoch}_${slideId}';
          final copy = SlideData(
            id: newSlideId,
            title: original.title,
            subtitle: original.subtitle,
            imageUrl: original.imageUrl,
            opacity: original.opacity,
            blur: original.blur,
            isBold: original.isBold,
            isItalic: original.isItalic,
            alignment: original.alignment,
            transition: original.transition,
            titleFontSize: original.titleFontSize,
            subtitleFontSize: original.subtitleFontSize,
            logoUrl: original.logoUrl,
            logoX: original.logoX,
            logoY: original.logoY,
            logoSize: original.logoSize,
          );
          _slides.add(copy);
          duplicatedSlideIds.add(newSlideId);
        }
      }
      
      final String newSectionId = 'section_${DateTime.now().millisecondsSinceEpoch}';
      final duplicateSection = SlideSection(
        id: newSectionId,
        name: '${sourceSection.name} (Copy)',
        slideIds: duplicatedSlideIds,
        colorValue: sourceSection.colorValue,
      );
      
      setState(() {
        _sections.insert(sectionIdx + 1, duplicateSection);
      });
      _syncSlidesFromSections();
    }
  }

  void _addSlide() {
    setState(() {
      final String nextId = 'slide_${DateTime.now().millisecondsSinceEpoch}';
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
      
      final activeSlideId = _slides[_activeSlideIndex].id;
      final section = _sections.firstWhere((s) => s.slideIds.contains(activeSlideId));
      final idx = section.slideIds.indexOf(activeSlideId);
      section.slideIds.insert(idx + 1, nextId);
      _slides.add(newSlide);
    });
    _syncSlidesFromSections();
    _setActiveSlide(_activeSlideIndex + 1);
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
      final String nextId = 'slide_${DateTime.now().millisecondsSinceEpoch}';
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
      
      final activeSlideId = active.id;
      final section = _sections.firstWhere((s) => s.slideIds.contains(activeSlideId));
      final idx = section.slideIds.indexOf(activeSlideId);
      section.slideIds.insert(idx + 1, nextId);
      _slides.add(duplicate);
    });
    _syncSlidesFromSections();
    _setActiveSlide(_activeSlideIndex + 1);
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
      final slideId = _slides[_activeSlideIndex].id;
      for (final section in _sections) {
        section.slideIds.remove(slideId);
      }
      _slides.removeAt(_activeSlideIndex);
      if (_activeSlideIndex >= _slides.length) {
        _activeSlideIndex = _slides.length - 1;
      }
      _setActiveSlide(_activeSlideIndex);
    });
    _syncSlidesFromSections();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed slide.'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

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
                sections: _sections,
                slides: _slides,
                activeIndex: _activeSlideIndex,
                onSlideSelected: _setActiveSlide,
                onAddSlide: _addSlide,
                onAddSection: (name) => _addSection(name),
                onRenameSection: _renameSection,
                onDeleteSection: _deleteSection,
                onMoveSection: _moveSection,
                onMoveSlideToSection: _moveSlideToSection,
                onAddSectionBeforeSlide: _addSectionBeforeSlide,
                onDuplicateSlide: (idx) {
                  _setActiveSlide(idx);
                  _duplicateSlide();
                },
                onDeleteSlide: (idx) {
                  _setActiveSlide(idx);
                  _removeSlide();
                },
                onMoveSlideInOutline: _moveSlideInOutline,
                onRenameSlide: (slide) => _showSlideRenameDialog(context, slide),
                onDuplicateSection: _duplicateSection,
              ),

            // Middle Workspace (Canvas)
            Expanded(
              child: (!isDesktop && _mobileSelectedTab != 1)
                  ? (_mobileSelectedTab == 0
                      ? _SlidesOutlineSidebar(
                          sections: _sections,
                          slides: _slides,
                          activeIndex: _activeSlideIndex,
                          onSlideSelected: _setActiveSlide,
                          onAddSlide: _addSlide,
                          onAddSection: (name) => _addSection(name),
                          onRenameSection: _renameSection,
                          onDeleteSection: _deleteSection,
                          onMoveSection: _moveSection,
                          onMoveSlideToSection: _moveSlideToSection,
                          onAddSectionBeforeSlide: _addSectionBeforeSlide,
                          onDuplicateSlide: (idx) {
                            _setActiveSlide(idx);
                            _duplicateSlide();
                          },
                          onDeleteSlide: (idx) {
                            _setActiveSlide(idx);
                            _removeSlide();
                          },
                          onMoveSlideInOutline: _moveSlideInOutline,
                          onRenameSlide: (slide) => _showSlideRenameDialog(context, slide),
                          onDuplicateSection: _duplicateSection,
                        )
                      : _PropertiesSidebar(
                          activeSlide: activeSlide,
                          titleController: _titleController,
                          subtitleController: _subtitleController,
                          onSlideChanged: _onSlideChanged,
                          onDuplicate: _duplicateSlide,
                          onDelete: _removeSlide,
                          onAllSlidesImageChanged: _onSlideImageChanged,
                          onLogoChanged: _onLogoChanged,
                          onLogoSizeChanged: _onLogoSizeChanged,
                          onBgColorChanged: (color) {
                            activeSlide.bgColorValue = color.value;
                            activeSlide.imageUrl = "";
                            if (_applyToAll) {
                              _applyActiveStylesToAll();
                            } else {
                              activeSlide.update();
                            }
                            AppSettings.instance.updateActiveSlides(_slides);
                            _saveToRecentList();
                          },
                          applyToAll: _applyToAll,
                          onApplyToAllChanged: (val) {
                            setState(() {
                              _applyToAll = val;
                            });
                          },
                          onApplyStylesToAllPressed: () {
                            setState(() {
                              _applyActiveStylesToAll();
                            });
                            AppSettings.instance.updateActiveSlides(_slides);
                            _saveToRecentList();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Applied current style to all slides.'),
                                backgroundColor: SacredColors.primary,
                              ),
                            );
                          },
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
                        activeSlide.logoX = x;
                        activeSlide.logoY = y;
                        if (_applyToAll) {
                          _applyActiveStylesToAll();
                        } else {
                          activeSlide.update();
                        }
                        AppSettings.instance.updateActiveSlides(_slides);
                        _saveToRecentList();
                      },
                      onTextPositionChanged: (x, y) {
                        activeSlide.textX = x;
                        activeSlide.textY = y;
                        if (_applyToAll) {
                          _applyActiveStylesToAll();
                        } else {
                          activeSlide.update();
                        }
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
                onAllSlidesImageChanged: _onSlideImageChanged,
                onLogoChanged: _onLogoChanged,
                onLogoSizeChanged: _onLogoSizeChanged,
                onBgColorChanged: (color) {
                  activeSlide.bgColorValue = color.value;
                  activeSlide.imageUrl = "";
                  if (_applyToAll) {
                    _applyActiveStylesToAll();
                  } else {
                    activeSlide.update();
                  }
                  AppSettings.instance.updateActiveSlides(_slides);
                  _saveToRecentList();
                },
                applyToAll: _applyToAll,
                onApplyToAllChanged: (val) {
                  setState(() {
                    _applyToAll = val;
                  });
                },
                onApplyStylesToAllPressed: () {
                  setState(() {
                    _applyActiveStylesToAll();
                  });
                  AppSettings.instance.updateActiveSlides(_slides);
                  _saveToRecentList();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Applied current style to all slides.'),
                      backgroundColor: SacredColors.primary,
                    ),
                  );
                },
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
                  border: Border.all(color: SacredColors.outlineVariant, width: 1),
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDY8LRvDsvImHRP9Eyjn2RGwg022ZHM4FoVMPdZnT2fyViMfbS8ohEhylRVfHmoHu1kyC_q_cBcLEx1NXiT-G3waNAarbu9q6pUPn_mowxq46gdELRL_s56PZetoJLTB4lHkX0N7uLdQUD72S2aNL_8wPQOr2OaNCVxquY0YoIQmH6OoY8xIjP48hbEJbHCa-qwHGOjeERQchb1gcWp_88oyubY1UaIpPceFAOfQ8vdglZkwGaa1FVK_2EMqQ1kpZ3yKGCVrqzAd5qA',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: SacredColors.outlineVariant,
                        child: const Icon(Icons.person, size: 16),
                      );
                    },
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
// ─────────────────────────────────────────────────────────────────────────────
// PowerPoint Section Sidebar Classes
// ─────────────────────────────────────────────────────────────────────────────

abstract class SidebarItem {}

class SectionHeaderItem extends SidebarItem {
  final SlideSection section;
  final int sectionIndex;
  SectionHeaderItem(this.section, this.sectionIndex);
}

class SlideItem extends SidebarItem {
  final SlideData slide;
  final int slideIndex; // index in flat slides list
  final int slideIndexInSection;
  final String sectionId;
  SlideItem(this.slide, this.slideIndex, this.slideIndexInSection, this.sectionId);
}

class DropTargetItem extends SidebarItem {
  final String sectionId;
  final int indexInSection;
  final bool isBetweenSections;
  DropTargetItem(this.sectionId, this.indexInSection, {this.isBetweenSections = false});
}

class _SidebarDropTarget extends StatefulWidget {
  final String sectionId;
  final int index;
  final bool isSectionTarget;
  final Function(String draggedId, String targetSectionId, int targetIndex) onDrop;

  const _SidebarDropTarget({
    required this.sectionId,
    required this.index,
    required this.isSectionTarget,
    required this.onDrop,
  });

  @override
  State<_SidebarDropTarget> createState() => _SidebarDropTargetState();
}

class _SidebarDropTargetState extends State<_SidebarDropTarget> {
  bool _isOver = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final draggedId = details.data;
        if (widget.isSectionTarget) {
          return draggedId.startsWith('section_');
        } else {
          return !draggedId.startsWith('section_');
        }
      },
      onAcceptWithDetails: (details) {
        widget.onDrop(details.data, widget.sectionId, widget.index);
        setState(() {
          _isOver = false;
        });
      },
      onLeave: (_) {
        setState(() {
          _isOver = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        if (candidateData.isNotEmpty) {
          _isOver = true;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: _isOver ? (widget.isSectionTarget ? 24.0 : 16.0) : 6.0,
          width: double.infinity,
          alignment: Alignment.center,
          child: _isOver
              ? Container(
                  height: widget.isSectionTarget ? 6.0 : 4.0,
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: SacredColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SectionHeader extends StatefulWidget {
  final SlideSection section;
  final int slideCount;
  final bool isActive;
  final VoidCallback onToggleCollapse;
  final VoidCallback onAddSlide;
  final Function(String) onRename;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Function(int)? onColorChange;
  final VoidCallback? onDuplicate;
  final VoidCallback? onAutoExpand;

  const _SectionHeader({
    required this.section,
    required this.slideCount,
    required this.isActive,
    required this.onToggleCollapse,
    required this.onAddSlide,
    required this.onRename,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
    this.onColorChange,
    this.onDuplicate,
    this.onAutoExpand,
  });

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _isHovered = false;
  Timer? _autoExpandTimer;

  @override
  void dispose() {
    _autoExpandTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget header = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onDoubleTap: () {
          _showRenameDialog(context, widget.section.name, 'Rename Section', widget.onRename);
        },
        onSecondaryTapUp: (details) {
          _showSectionContextMenu(context, details.globalPosition);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: widget.section.colorValue != null
                ? Color(widget.section.colorValue!).withValues(alpha: _isHovered ? 0.25 : 0.15)
                : (_isHovered
                    ? SacredColors.surfaceContainerHigh.withValues(alpha: 0.95)
                    : SacredColors.surfaceContainerHigh.withValues(alpha: 0.8)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isActive ? SacredColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  widget.section.isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 18,
                  color: SacredColors.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onToggleCollapse,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.section.name,
                  style: SacredTypography.labelLg(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.section.colorValue != null
                        ? Color(widget.section.colorValue!)
                        : SacredColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${widget.slideCount} slide${widget.slideCount == 1 ? '' : 's'}',
                style: SacredTypography.labelSm(context).copyWith(
                  color: SacredColors.outline,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onAddSlide,
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final offset = renderBox.localToGlobal(Offset.zero);
                  _showSectionContextMenu(context, offset + Offset(renderBox.size.width - 100, 24));
                },
              ),
            ],
          ),
        ),
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => !details.data.startsWith('section_'),
      onMove: (_) {
        if (widget.section.isCollapsed) {
          _autoExpandTimer ??= Timer(const Duration(milliseconds: 600), () {
            widget.onAutoExpand?.call();
          });
        }
      },
      onLeave: (_) {
        _autoExpandTimer?.cancel();
        _autoExpandTimer = null;
      },
      onAcceptWithDetails: (_) {
        _autoExpandTimer?.cancel();
        _autoExpandTimer = null;
      },
      builder: (context, candidateData, rejectedData) {
        return Draggable<String>(
          data: widget.section.id,
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: SacredColors.primary.withValues(alpha: 0.9),
              child: Text(
                widget.section.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.4,
            child: header,
          ),
          child: header,
        );
      },
    );
  }

  void _showSectionContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit, size: 18),
            title: Text('Rename Section'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'move_up',
          enabled: widget.onMoveUp != null,
          child: const ListTile(
            leading: Icon(Icons.arrow_upward, size: 18),
            title: Text('Move Section Up'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'move_down',
          enabled: widget.onMoveDown != null,
          child: const ListTile(
            leading: Icon(Icons.arrow_downward, size: 18),
            title: Text('Move Section Down'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'color',
          child: ListTile(
            leading: Icon(Icons.palette_outlined, size: 18),
            title: Text('Choose Color'),
            dense: true,
          ),
        ),
        if (widget.onDuplicate != null)
          const PopupMenuItem(
            value: 'duplicate',
            child: ListTile(
              leading: Icon(Icons.content_copy, size: 18),
              title: Text('Duplicate Section'),
              dense: true,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
            title: Text('Delete Section', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        _showRenameDialog(context, widget.section.name, 'Rename Section', widget.onRename);
      } else if (value == 'move_up') {
        widget.onMoveUp?.call();
      } else if (value == 'move_down') {
        widget.onMoveDown?.call();
      } else if (value == 'delete') {
        widget.onDelete();
      } else if (value == 'duplicate') {
        widget.onDuplicate?.call();
      } else if (value == 'color') {
        _showColorPicker(context);
      }
    });
  }

  void _showColorPicker(BuildContext context) {
    Color selectedColor = widget.section.colorValue != null && widget.section.colorValue != 0
        ? Color(widget.section.colorValue!)
        : Colors.blue;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final baseColors = [
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.blueGrey,
            ];

            MaterialColor? matchingBase;
            for (final base in baseColors) {
              if (base is MaterialColor) {
                if (base.value == selectedColor.value) {
                  matchingBase = base;
                  break;
                }
                for (final shade in [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) {
                  if (base[shade]?.value == selectedColor.value) {
                    matchingBase = base;
                    break;
                  }
                }
                if (matchingBase != null) break;
              }
            }

            final shades = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];

            return AlertDialog(
              title: const Text('Section Color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview box
                    Container(
                      height: 50,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Preview: #${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: TextStyle(
                          color: ThemeData.estimateBrightnessForColor(selectedColor) == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Base Color', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // Grid of base colors
                    SizedBox(
                      height: 80,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: baseColors.length,
                        itemBuilder: (context, index) {
                          final color = baseColors[index];
                          final isSelected = matchingBase == color;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                                if (color is MaterialColor) {
                                  matchingBase = color;
                                } else {
                                  matchingBase = null;
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.black, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (matchingBase != null) ...[
                      const SizedBox(height: 16),
                      const Text('Shades', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Shades selection row
                      SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: shades.length,
                          itemBuilder: (context, index) {
                            final shade = shades[index];
                            final color = matchingBase![shade]!;
                            final isSelected = selectedColor.value == color.value;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = color;
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: isSelected
                                      ? Border.all(color: Colors.black, width: 2.5)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Custom Fine-Tuning (HSL)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // HSL Sliders
                    Builder(
                      builder: (context) {
                        final hsl = HSLColor.fromColor(selectedColor);
                        return Column(
                          children: [
                            // Hue
                            Row(
                              children: [
                                const SizedBox(width: 30, child: Text('H')),
                                Expanded(
                                  child: Slider(
                                    value: hsl.hue,
                                    min: 0.0,
                                    max: 360.0,
                                    activeColor: Colors.red,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedColor = hsl.withHue(val).toColor();
                                      });
                                    },
                                  ),
                                ),
                                Text('${hsl.hue.round()}°'),
                              ],
                            ),
                            // Saturation
                            Row(
                              children: [
                                const SizedBox(width: 30, child: Text('S')),
                                Expanded(
                                  child: Slider(
                                    value: hsl.saturation,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: Colors.green,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedColor = hsl.withSaturation(val).toColor();
                                      });
                                    },
                                  ),
                                ),
                                Text('${(hsl.saturation * 100).round()}%'),
                              ],
                            ),
                            // Lightness
                            Row(
                              children: [
                                const SizedBox(width: 30, child: Text('L')),
                                Expanded(
                                  child: Slider(
                                    value: hsl.lightness,
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: Colors.blue,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        selectedColor = hsl.withLightness(val).toColor();
                                      });
                                    },
                                  ),
                                ),
                                Text('${(hsl.lightness * 100).round()}%'),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.onColorChange?.call(0);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear Color'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onColorChange?.call(selectedColor.value);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SlidesOutlineSidebar extends StatefulWidget {
  final List<SlideSection> sections;
  final List<SlideData> slides;
  final int activeIndex;
  final ValueChanged<int> onSlideSelected;
  final VoidCallback onAddSlide;
  final Function(String name) onAddSection;
  final Function(String id, String newName) onRenameSection;
  final Function(String id) onDeleteSection;
  final Function(int fromIndex, int toIndex) onMoveSection;
  final Function(String slideId, String targetSectionId, int targetIndex) onMoveSlideToSection;
  final Function(String slideId, String name) onAddSectionBeforeSlide;
  final Function(int slideIndex) onDuplicateSlide;
  final Function(int slideIndex) onDeleteSlide;
  final Function(int fromIndex, int toIndex) onMoveSlideInOutline;
  final Function(SlideData slide) onRenameSlide;
  final Function(String id)? onDuplicateSection;

  const _SlidesOutlineSidebar({
    required this.sections,
    required this.slides,
    required this.activeIndex,
    required this.onSlideSelected,
    required this.onAddSlide,
    required this.onAddSection,
    required this.onRenameSection,
    required this.onDeleteSection,
    required this.onMoveSection,
    required this.onMoveSlideToSection,
    required this.onAddSectionBeforeSlide,
    required this.onDuplicateSlide,
    required this.onDeleteSlide,
    required this.onMoveSlideInOutline,
    required this.onRenameSlide,
    this.onDuplicateSection,
  });

  @override
  State<_SlidesOutlineSidebar> createState() => _SlidesOutlineSidebarState();
}

class _SlidesOutlineSidebarState extends State<_SlidesOutlineSidebar> {
  final FocusNode _sidebarFocusNode = FocusNode();

  @override
  void dispose() {
    _sidebarFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<SidebarItem> items = [];
    
    for (int sIdx = 0; sIdx < widget.sections.length; sIdx++) {
      final section = widget.sections[sIdx];
      items.add(DropTargetItem(section.id, sIdx, isBetweenSections: true));
      items.add(SectionHeaderItem(section, sIdx));
      
      if (!section.isCollapsed) {
        items.add(DropTargetItem(section.id, 0));
        
        for (int i = 0; i < section.slideIds.length; i++) {
          final slideId = section.slideIds[i];
          final slideIdx = widget.slides.indexWhere((s) => s.id == slideId);
          if (slideIdx != -1) {
            items.add(SlideItem(widget.slides[slideIdx], slideIdx, i, section.id));
            items.add(DropTargetItem(section.id, i + 1));
          }
        }
      }
    }
    
    if (widget.sections.isNotEmpty) {
      items.add(DropTargetItem(widget.sections.last.id, widget.sections.length, isBetweenSections: true));
    }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      tooltip: 'Add Section',
                      onPressed: () {
                        _showRenameDialog(context, '', 'New Section Name', (name) {
                          widget.onAddSection(name);
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.slides.length} Total',
                      style: SacredTypography.labelSm(context).copyWith(
                        color: SacredColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Focus(
              focusNode: _sidebarFocusNode,
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (widget.slides.isEmpty || widget.activeIndex >= widget.slides.length) {
                    return KeyEventResult.ignored;
                  }
                  final activeSlideId = widget.slides[widget.activeIndex].id;
                  final activeSection = widget.sections.firstWhere(
                    (s) => s.slideIds.contains(activeSlideId),
                    orElse: () => null as dynamic,
                  );

                  if (event.logicalKey == LogicalKeyboardKey.f2) {
                    if (activeSection != null) {
                      _showRenameDialog(context, activeSection.name, 'Rename Section', (val) {
                        widget.onRenameSection(activeSection.id, val);
                      });
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.delete) {
                    if (activeSection != null) {
                      widget.onDeleteSection(activeSection.id);
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    if (activeSection != null && !activeSection.isCollapsed) {
                      setState(() {
                        activeSection.isCollapsed = true;
                      });
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    if (activeSection != null && activeSection.isCollapsed) {
                      setState(() {
                        activeSection.isCollapsed = false;
                      });
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: items.length,
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  
                  if (item is SectionHeaderItem) {
                    final activeSlideId = widget.slides.isNotEmpty && widget.activeIndex < widget.slides.length
                        ? widget.slides[widget.activeIndex].id
                        : '';
                    final bool isSectionActive = item.section.slideIds.contains(activeSlideId);

                    return Semantics(
                      label: '${item.section.name} section, ${item.section.slideIds.length} slides',
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: _SectionHeader(
                          section: item.section,
                          slideCount: item.section.slideIds.length,
                          isActive: isSectionActive,
                          onToggleCollapse: () {
                            setState(() {
                              item.section.isCollapsed = !item.section.isCollapsed;
                            });
                            widget.onRenameSection(item.section.id, item.section.name);
                          },
                          onAddSlide: () {
                            if (item.section.slideIds.isNotEmpty) {
                              final lastSlideId = item.section.slideIds.last;
                              final lastSlideIdx = widget.slides.indexWhere((s) => s.id == lastSlideId);
                              if (lastSlideIdx != -1) {
                                widget.onSlideSelected(lastSlideIdx);
                              }
                            }
                            widget.onAddSlide();
                          },
                          onRename: (newName) => widget.onRenameSection(item.section.id, newName),
                          onDelete: () => widget.onDeleteSection(item.section.id),
                          onMoveUp: item.sectionIndex > 0
                              ? () => widget.onMoveSection(item.sectionIndex, item.sectionIndex - 1)
                              : null,
                          onMoveDown: item.sectionIndex < widget.sections.length - 1
                              ? () => widget.onMoveSection(item.sectionIndex, item.sectionIndex + 1)
                              : null,
                          onColorChange: (colorVal) {
                            setState(() {
                              item.section.colorValue = colorVal == 0 ? null : colorVal;
                            });
                            widget.onRenameSection(item.section.id, item.section.name);
                          },
                          onDuplicate: widget.onDuplicateSection != null
                              ? () => widget.onDuplicateSection!(item.section.id)
                              : null,
                          onAutoExpand: () {
                            setState(() {
                              item.section.isCollapsed = false;
                            });
                          },
                        ),
                      ),
                    );
                  } else if (item is SlideItem) {
                    final bool isActive = item.slideIndex == widget.activeIndex;
                    
                    return Semantics(
                      label: 'Slide ${item.slideIndex + 1}, title: ${item.slide.title}',
                      selected: isActive,
                      child: Draggable<String>(
                        data: item.slide.id,
                        feedback: Material(
                          elevation: 12,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 180,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  color: Color(item.slide.bgColorValue),
                                  alignment: Alignment.center,
                                  child: Text(
                                    item.slide.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
                            child: _SlideThumbnailCard(
                              slide: item.slide,
                              isActive: isActive,
                              indexText: '${item.slideIndex + 1}'.padLeft(2, '0'),
                              onTap: () => widget.onSlideSelected(item.slideIndex),
                            ),
                          ),
                        ),
                        child: GestureDetector(
                          onSecondaryTapUp: (details) {
                            _showSlideContextMenu(context, details.globalPosition, item.slideIndex, item.slide.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
                            child: _SlideThumbnailCard(
                              slide: item.slide,
                              isActive: isActive,
                              indexText: '${item.slideIndex + 1}'.padLeft(2, '0'),
                              onTap: () => widget.onSlideSelected(item.slideIndex),
                            ),
                          ),
                        ),
                      ),
                    );
                  } else if (item is DropTargetItem) {
                    return _SidebarDropTarget(
                      sectionId: item.sectionId,
                      index: item.indexInSection,
                      isSectionTarget: item.isBetweenSections,
                      onDrop: (draggedId, targetSectionId, targetIndex) {
                        if (item.isBetweenSections) {
                          final fromIdx = widget.sections.indexWhere((s) => s.id == draggedId);
                          if (fromIdx != -1) {
                            widget.onMoveSection(fromIdx, targetIndex);
                          }
                        } else {
                          widget.onMoveSlideToSection(draggedId, targetSectionId, targetIndex);
                        }
                      },
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: SacredColors.outlineVariant,
                strokeWidth: 2.0,
                radius: 12.0,
              ),
              child: InkWell(
                onTap: widget.onAddSlide,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: SacredColors.onSurfaceVariant),
                      const SizedBox(width: 8),
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

  void _showSlideContextMenu(BuildContext context, Offset position, int slideIndex, String slideId) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit, size: 18),
            title: Text('Edit Text Content'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'move_up',
          enabled: slideIndex > 0,
          child: const ListTile(
            leading: Icon(Icons.arrow_upward, size: 18),
            title: Text('Move Slide Up'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: 'move_down',
          enabled: slideIndex < widget.slides.length - 1,
          child: const ListTile(
            leading: Icon(Icons.arrow_downward, size: 18),
            title: Text('Move Slide Down'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.content_copy, size: 18),
            title: Text('Duplicate Slide'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'add_section_before',
          child: ListTile(
            leading: Icon(Icons.add_box_outlined, size: 18),
            title: Text('Add Section Before'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'add_section_after',
          child: ListTile(
            leading: Icon(Icons.add_box_outlined, size: 18),
            title: Text('Add Section After'),
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
            title: Text('Delete Slide', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        widget.onRenameSlide(widget.slides[slideIndex]);
      } else if (value == 'move_up') {
        widget.onMoveSlideInOutline(slideIndex, slideIndex - 1);
      } else if (value == 'move_down') {
        widget.onMoveSlideInOutline(slideIndex, slideIndex + 1);
      } else if (value == 'duplicate') {
        widget.onDuplicateSlide(slideIndex);
      } else if (value == 'add_section_before') {
        _showRenameDialog(context, '', 'New Section Name', (name) {
          widget.onAddSectionBeforeSlide(slideId, name);
        });
      } else if (value == 'add_section_after') {
        _showRenameDialog(context, '', 'New Section Name', (name) {
          final section = widget.sections.firstWhere((s) => s.slideIds.contains(slideId));
          final idx = section.slideIds.indexOf(slideId);
          if (idx < section.slideIds.length - 1) {
            final nextSlideId = section.slideIds[idx + 1];
            widget.onAddSectionBeforeSlide(nextSlideId, name);
          } else {
            widget.onAddSection(name);
          }
        });
      } else if (value == 'delete') {
        widget.onDeleteSlide(slideIndex);
      }
    });
  }
}

Future<void> _showRenameDialog(BuildContext context, String initialValue, String title, ValueChanged<String> onRename) async {
  final controller = TextEditingController(text: initialValue);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              onRename(val.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onRename(controller.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      );
    },
  );
}

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
    const grayscaleMatrix = <double>[
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ];

    return ListenableBuilder(
      listenable: widget.slide,
      builder: (context, _) {
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double thumbnailWidth = constraints.maxWidth;
                          final double thumbnailHeight = constraints.maxHeight;
                          final double scale = thumbnailWidth / 960.0;

                          return Stack(
                            children: [
                              Positioned.fill(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  child: ColorFiltered(
                                    colorFilter: renderFullColor
                                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                        : const ColorFilter.matrix(grayscaleMatrix),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            color: Color(widget.slide.bgColorValue),
                                          ),
                                        ),
                                        if (widget.slide.imageUrl.isNotEmpty)
                                          Positioned.fill(
                                            child: widget.slide.imageUrl.startsWith('data:')
                                                ? Image.memory(
                                                    _decodeDataUrl(widget.slide.imageUrl),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, e, s) => const SizedBox(),
                                                  )
                                                : Image.network(
                                                    widget.slide.imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, e, s) => const SizedBox(),
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              if (widget.slide.logoUrl != null && widget.slide.logoUrl!.isNotEmpty)
                                Positioned(
                                  left: widget.slide.logoX * thumbnailWidth,
                                  top: widget.slide.logoY * thumbnailHeight,
                                  width: widget.slide.logoSize * scale,
                                  height: widget.slide.logoSize * scale,
                                  child: IgnorePointer(
                                    child: widget.slide.logoUrl!.startsWith('data:')
                                        ? Image.memory(
                                            _decodeDataUrl(widget.slide.logoUrl!),
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, e, s) => const SizedBox(),
                                          )
                                        : Image.network(
                                            widget.slide.logoUrl!,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, e, s) => const SizedBox(),
                                          ),
                                  ),
                                ),

                              Positioned(
                                left: (widget.slide.textX * thumbnailWidth) + (48.0 * scale),
                                top: (widget.slide.textY * thumbnailHeight) + (32.0 * scale),
                                width: thumbnailWidth - (96.0 * scale),
                                height: thumbnailHeight - (64.0 * scale),
                                child: IgnorePointer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.slide.title,
                                        textAlign: widget.slide.alignment,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.getFont(
                                          AppSettings.instance.fontFamily,
                                          textStyle: TextStyle(
                                            fontSize: (widget.slide.titleFontSize * scale).clamp(4.0, 40.0),
                                            color: Colors.white,
                                            fontWeight: widget.slide.isBold ? FontWeight.bold : FontWeight.normal,
                                            fontStyle: widget.slide.isItalic ? FontStyle.italic : FontStyle.normal,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black45,
                                                offset: Offset(0, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (widget.slide.subtitle.trim().isNotEmpty) ...[
                                        SizedBox(height: 4.0 * scale),
                                        Container(
                                          width: 24.0 * scale,
                                          height: (1.0 * scale).clamp(0.5, 4.0),
                                          color: SacredColors.secondaryContainer,
                                        ),
                                        SizedBox(height: 4.0 * scale),
                                        Expanded(
                                          child: Text(
                                            widget.slide.subtitle,
                                            textAlign: widget.slide.alignment,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              textStyle: TextStyle(
                                                fontSize: (widget.slide.subtitleFontSize * scale).clamp(3.0, 30.0),
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontStyle: FontStyle.italic,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black45,
                                                    offset: Offset(0, 0.5),
                                                    blurRadius: 1.5,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
      },
    );
  }
}

class _LiveWorkspaceCanvas extends StatelessWidget {
  final SlideData activeSlide;
  final int slideCount;
  final int activeIndex;
  final ValueChanged<int> onNavigate;
  final Function(double, double)? onLogoPositionChanged;
  final Function(double, double)? onTextPositionChanged;

  const _LiveWorkspaceCanvas({
    required this.activeSlide,
    required this.slideCount,
    required this.activeIndex,
    required this.onNavigate,
    this.onLogoPositionChanged,
    this.onTextPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activeSlide,
      builder: (context, _) {
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
                          // Base Background Color Layer
                          Positioned.fill(
                            child: Container(
                              color: Color(activeSlide.bgColorValue),
                            ),
                          ),

                          // Background Image Layer with custom opacity and live blurs
                          if (activeSlide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: Opacity(
                                opacity: activeSlide.opacity,
                                child: activeSlide.blur == 0.0
                                    ? (activeSlide.imageUrl.startsWith('data:')
                                        ? Image.memory(
                                            _decodeDataUrl(activeSlide.imageUrl),
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.low,
                                            errorBuilder: (c, e, s) => const SizedBox(),
                                          )
                                        : Image.network(
                                            activeSlide.imageUrl,
                                            fit: BoxFit.cover,
                                            filterQuality: FilterQuality.low,
                                            errorBuilder: (c, e, s) => const SizedBox(),
                                          ))
                                    : ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: activeSlide.blur,
                                          sigmaY: activeSlide.blur,
                                        ),
                                        child: activeSlide.imageUrl.startsWith('data:')
                                            ? Image.memory(
                                                _decodeDataUrl(activeSlide.imageUrl),
                                                fit: BoxFit.cover,
                                                filterQuality: FilterQuality.low,
                                                errorBuilder: (c, e, s) => const SizedBox(),
                                              )
                                            : Image.network(
                                                activeSlide.imageUrl,
                                                fit: BoxFit.cover,
                                                filterQuality: FilterQuality.low,
                                                errorBuilder: (c, e, s) => const SizedBox(),
                                              ),
                                      ),
                              ),
                            ),

                          // Purple spiritual overlay blending
                          if (activeSlide.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  color: SacredColors.primary.withValues(alpha: 0.20),
                                ),
                              ),
                            ),

                          // Draggable Typography Text Layer
                          Positioned.fill(
                            child: _DraggableTextLayer(
                              activeSlide: activeSlide,
                              onPositionChanged: onTextPositionChanged,
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
      },
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
              },
              onPanEnd: (_) {
                if (_dragPixelX != null) {
                  widget.onPositionChanged?.call(
                    _dragPixelX! / w,
                    _dragPixelY! / h,
                  );
                }
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
                      : (widget.logoUrl.startsWith('assets/')
                          ? Image.asset(
                              widget.logoUrl,
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
                            )),
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
  final ValueChanged<Color> onBgColorChanged;
  final bool applyToAll;
  final ValueChanged<bool> onApplyToAllChanged;
  final VoidCallback onApplyStylesToAllPressed;

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
    required this.onBgColorChanged,
    required this.applyToAll,
    required this.onApplyToAllChanged,
    required this.onApplyStylesToAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activeSlide,
      builder: (context, _) {
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Apply to all slides',
                    style: SacredTypography.bodyMd(context).copyWith(
                      color: SacredColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: applyToAll,
                  activeColor: SacredColors.primary,
                  onChanged: onApplyToAllChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: const Text('Apply current style to all'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SacredColors.primary,
                  side: BorderSide(color: SacredColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onApplyStylesToAllPressed,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

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
              'BACKGROUND COLOR',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 12),
            _BackgroundColorSelector(
              selectedColor: Color(activeSlide.bgColorValue),
              onColorChanged: onBgColorChanged,
            ),
            SizedBox(height: 24),

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
      },
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
                                : (widget.logoUrl!.startsWith('assets/')
                                    ? Image.asset(
                                        widget.logoUrl!,
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
                                      )),
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

// ─────────────────────────────────────────────────────────────────────────────
// Draggable Typography Text Layer
// ─────────────────────────────────────────────────────────────────────────────
class _DraggableTextLayer extends StatefulWidget {
  final SlideData activeSlide;
  final Function(double, double)? onPositionChanged;

  const _DraggableTextLayer({
    required this.activeSlide,
    this.onPositionChanged,
  });

  @override
  State<_DraggableTextLayer> createState() => _DraggableTextLayerState();
}

class _DraggableTextLayerState extends State<_DraggableTextLayer> {
  double? _dragPixelX;
  double? _dragPixelY;
  bool _showBorder = false;

  @override
  void didUpdateWidget(_DraggableTextLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset local position when slide changes
    if (oldWidget.activeSlide.id != widget.activeSlide.id) {
      _dragPixelX = null;
      _dragPixelY = null;
      _showBorder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double w = constraints.maxWidth;
      final double h = constraints.maxHeight;
      if (w == 0 || h == 0) return const SizedBox.expand();

      final double scale = w / 960.0;

      // Drag offsets range: let them drag up to 85% off screen vertically/horizontally
      final double maxLeft = w * 0.85;
      final double minLeft = -w * 0.85;
      final double maxTop  = h * 0.85;
      final double minTop  = -h * 0.85;

      final double left = (_dragPixelX ?? (widget.activeSlide.textX * w)).clamp(minLeft, maxLeft);
      final double top  = (_dragPixelY ?? (widget.activeSlide.textY * h)).clamp(minTop, maxTop);

      final hasSubtitle = widget.activeSlide.subtitle.trim().isNotEmpty;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: left,
            top: top,
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) {
                setState(() {
                  _showBorder = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _showBorder = false;
                });
              },
              onTapCancel: () {
                setState(() {
                  _showBorder = false;
                });
              },
              onPanStart: (_) {
                setState(() {
                  _dragPixelX = left;
                  _dragPixelY = top;
                  _showBorder = true;
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _dragPixelX = ((_dragPixelX ?? left) + details.delta.dx).clamp(minLeft, maxLeft);
                  _dragPixelY = ((_dragPixelY ?? top) + details.delta.dy).clamp(minTop, maxTop);
                });
              },
              onPanEnd: (_) {
                if (_dragPixelX != null) {
                  widget.onPositionChanged?.call(
                    _dragPixelX! / w,
                    _dragPixelY! / h,
                  );
                }
                setState(() {
                  _showBorder = false;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _showBorder ? Colors.white54 : Colors.transparent,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (48.0 * scale).clamp(8.0, w),
                    vertical: (32.0 * scale).clamp(8.0, h),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.activeSlide.title,
                        textAlign: widget.activeSlide.alignment,
                        style: GoogleFonts.getFont(
                          AppSettings.instance.fontFamily,
                          textStyle: TextStyle(
                            fontSize: (widget.activeSlide.titleFontSize * scale).clamp(8.0, 150.0),
                            color: Colors.white,
                            fontWeight: widget.activeSlide.isBold ? FontWeight.bold : FontWeight.normal,
                            fontStyle: widget.activeSlide.isItalic ? FontStyle.italic : FontStyle.normal,
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
                      if (hasSubtitle) ...[
                        SizedBox(height: 16.0 * scale),
                        Container(
                          width: 96.0 * scale,
                          height: (4.0 * scale).clamp(1.0, 20.0),
                          decoration: BoxDecoration(
                            color: SacredColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.activeSlide.subtitle,
                              textAlign: widget.activeSlide.alignment,
                              style: GoogleFonts.inter(
                                textStyle: TextStyle(
                                  fontSize: (widget.activeSlide.subtitleFontSize * scale).clamp(6.0, 100.0),
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
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Background Color Selector
// ─────────────────────────────────────────────────────────────────────────────
class _BackgroundColorSelector extends StatefulWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const _BackgroundColorSelector({
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  State<_BackgroundColorSelector> createState() => _BackgroundColorSelectorState();
}

class _BackgroundColorSelectorState extends State<_BackgroundColorSelector> {
  late TextEditingController _hexController;

  final List<Color> _presetBgColors = const [
    Color(0xFF000000), // Pure Black
    Color(0xFF0F172A), // Slate Black
    Color(0xFF2E0052), // Spiritual Purple
    Color(0xFF1E1B4B), // Deep Blue
    Color(0xFF450A0A), // Deep Red
    Color(0xFF064E3B), // Deep Green
  ];

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(
      text: '#${widget.selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
    );
  }

  @override
  void didUpdateWidget(_BackgroundColorSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor != widget.selectedColor) {
      _hexController.text = '#${widget.selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetBgColors.map((color) {
              final isSelected = color.value == widget.selectedColor.value;
              return GestureDetector(
                onTap: () => widget.onColorChanged(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white24,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: Colors.white24, blurRadius: 4)]
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: widget.selectedColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _hexController,
                  style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '#000000',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: SacredColors.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onSubmitted: (val) {
                    try {
                      final cleanHex = val.replaceAll('#', '').trim();
                      if (cleanHex.length == 6) {
                        final color = Color(int.parse('0xFF$cleanHex'));
                        widget.onColorChanged(color);
                      }
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
