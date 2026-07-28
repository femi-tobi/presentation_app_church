import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bible_service.dart';
import 'dashboard_page.dart'; // SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'preview_page.dart';
import 'presentation_controller.dart';
import 'fullscreen_presenter_page.dart';
import 'display_manager.dart';

class BibleShowPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const BibleShowPage({super.key, required this.scaffoldKey});

  @override
  State<BibleShowPage> createState() => _BibleShowPageState();
}

class _BibleShowPageState extends State<BibleShowPage> {
  String _selectedTranslation = 'KJV';
  List<String> _books = [];
  String? _selectedBook;
  BibleBook? _currentBookData;
  BibleChapter? _selectedChapter;
  
  // Translation Comparison
  bool _isComparing = false;
  BibleBook? _comparisonBookData;
  String _comparisonTranslation = 'NIV';
  
  // Selection
  final Set<String> _selectedVerseNumbers = {};
  final List<SlideData> _presentationQueue = [];

  // Resizable layout sizes
  double _sidebarWidth = 320.0;
  double _booksSectionHeight = 370.0; // 260 for books + 110 for chapters
  bool _isSidebarCollapsed = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  ParsedReference? _currentParsedRef;
  String _autoCompleteSuggestion = '';

  // Focus
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  // Undo/Redo queues for navigation
  final List<Map<String, String>> _navigationHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final books = await BibleService.instance.getBooks(_selectedTranslation);
    setState(() {
      _books = books;
    });
    // Auto-select Genesis
    if (books.isNotEmpty) {
      _selectBook(books.first, pushHistory: true);
    }
  }

  Future<void> _selectBook(String bookName, {bool pushHistory = true, String? targetChapter}) async {
    final bookData = await BibleService.instance.loadBook(_selectedTranslation, bookName);
    BibleBook? compData;
    if (_isComparing) {
      compData = await BibleService.instance.loadBook(_comparisonTranslation, bookName);
    }
    if (bookData != null) {
      setState(() {
        _selectedBook = bookName;
        _currentBookData = bookData;
        _comparisonBookData = compData;
        _selectedVerseNumbers.clear();
        
        // Select specified chapter or default to chapter 1
        if (targetChapter != null) {
          _selectedChapter = bookData.chapters.firstWhere(
            (c) => c.chapterNumber == targetChapter,
            orElse: () => bookData.chapters.first,
          );
        } else {
          _selectedChapter = bookData.chapters.isNotEmpty ? bookData.chapters.first : null;
        }
      });

      if (pushHistory) {
        // Truncate forward history if we were in the middle
        if (_historyIndex < _navigationHistory.length - 1) {
          _navigationHistory.removeRange(_historyIndex + 1, _navigationHistory.length);
        }
        _navigationHistory.add({
          'book': bookName,
          'chapter': _selectedChapter?.chapterNumber ?? '1',
        });
        _historyIndex = _navigationHistory.length - 1;
      }
    }
  }

  void _selectChapter(BibleChapter chapter, {bool pushHistory = true}) {
    setState(() {
      _selectedChapter = chapter;
      _selectedVerseNumbers.clear();
    });
    if (pushHistory) {
      if (_historyIndex < _navigationHistory.length - 1) {
        _navigationHistory.removeRange(_historyIndex + 1, _navigationHistory.length);
      }
      _navigationHistory.add({
        'book': _selectedBook ?? '',
        'chapter': chapter.chapterNumber,
      });
      _historyIndex = _navigationHistory.length - 1;
    }
  }

  void _navigateHistory(bool forward) {
    if (forward && _historyIndex < _navigationHistory.length - 1) {
      _historyIndex++;
      final state = _navigationHistory[_historyIndex];
      _selectBook(state['book']!, pushHistory: false, targetChapter: state['chapter']);
    } else if (!forward && _historyIndex > 0) {
      _historyIndex--;
      final state = _navigationHistory[_historyIndex];
      _selectBook(state['book']!, pushHistory: false, targetChapter: state['chapter']);
    }
  }

  void _toggleVerseSelection(String verseNum) {
    setState(() {
      if (_selectedVerseNumbers.contains(verseNum)) {
        _selectedVerseNumbers.remove(verseNum);
      } else {
        _selectedVerseNumbers.add(verseNum);
      }
    });
  }

  void _selectAllVerses() {
    if (_selectedChapter == null) return;
    setState(() {
      if (_selectedVerseNumbers.length == _selectedChapter!.verses.length) {
        _selectedVerseNumbers.clear();
      } else {
        _selectedVerseNumbers.clear();
        for (final v in _selectedChapter!.verses) {
          _selectedVerseNumbers.add(v.verseNumber);
        }
      }
    });
  }

  void _presentSpecificVerse(BibleVerse v) {
    if (_selectedChapter == null || _selectedBook == null) return;
    setState(() {
      _selectedVerseNumbers.clear();
      _selectedVerseNumbers.add(v.verseNumber);
    });
    final settings = AppSettings.instance;
    final List<String> segments = settings.bibleAutoSplit
        ? _splitVerseText(v.text, settings.bibleMaxChars, settings.bibleMaxLines)
        : [v.text];

    final List<SlideData> slides = [];
    for (int i = 0; i < segments.length; i++) {
      final id = DateTime.now().microsecondsSinceEpoch.toString() + '_$i';
      final letterSuffix = segments.length > 1 ? String.fromCharCode(97 + i) : ''; // 97 is ASCII code for 'a'
      slides.add(SlideData(
        id: id,
        title: '${_selectedBook} ${_selectedChapter!.chapterNumber}:${v.verseNumber}$letterSuffix',
        subtitle: segments[i],
        imageUrl: '',
        opacity: 0.0,
        isBold: settings.bibleIsBold,
        isItalic: settings.bibleIsItalic,
        titleFontSize: settings.bibleFontSize,
        subtitleFontSize: settings.bibleFontSize * 0.8,
        bgColorValue: settings.bibleBgColor,
        textColorValue: settings.bibleTextColor,
      ));
    }

    final isMultiScreen = DisplayManager.instance.displays.length > 1 || DisplayManager.instance.simulateAudience;

    settings.updateActiveSlides(slides);
    settings.activeSlideIndex = 0;

    PresentationController.instance.updateSlides(slides);
    PresentationController.instance.goTo(0);
    PresentationController.instance.setMode(PresentationMode.live);
    PresentationController.instance.spawnAudienceWindow();

    if (!isMultiScreen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const FullscreenPresenterPage(),
        ),
      );
    }
  }

  // Keyboard navigation helper to move to next or previous verse and handle chapter overflows
  void _navigateVerses(bool next) async {
    if (_selectedChapter == null || _selectedBook == null || _currentBookData == null) return;
    final verses = _selectedChapter!.verses;
    if (verses.isEmpty) return;

    // Determine current focused verse index (default to first verse or currently highlighted one)
    int currentIdx = -1;
    if (_selectedVerseNumbers.isNotEmpty) {
      final currentSelected = _selectedVerseNumbers.first;
      currentIdx = verses.indexWhere((v) => v.verseNumber == currentSelected);
    }

    BibleVerse? targetVerse;

    if (next) {
      if (currentIdx == -1) {
        // Highlight first verse if none was selected
        setState(() {
          _selectedVerseNumbers.clear();
          _selectedVerseNumbers.add(verses.first.verseNumber);
        });
        targetVerse = verses.first;
      } else if (currentIdx < verses.length - 1) {
        // Go to next verse in current chapter
        setState(() {
          _selectedVerseNumbers.clear();
          _selectedVerseNumbers.add(verses[currentIdx + 1].verseNumber);
        });
        targetVerse = verses[currentIdx + 1];
      } else {
        // Exhausted chapter! Move to next chapter
        final chapters = _currentBookData!.chapters;
        final chapIdx = chapters.indexWhere((c) => c.chapterNumber == _selectedChapter!.chapterNumber);
        if (chapIdx != -1 && chapIdx < chapters.length - 1) {
          final nextChap = chapters[chapIdx + 1];
          _selectChapter(nextChap);
          if (nextChap.verses.isNotEmpty) {
            setState(() {
              _selectedVerseNumbers.add(nextChap.verses.first.verseNumber);
            });
            targetVerse = nextChap.verses.first;
          }
        } else {
          // Exhausted book! Move to next book in bible list
          final bookIdx = _books.indexOf(_selectedBook!);
          if (bookIdx != -1 && bookIdx < _books.length - 1) {
            await _selectBook(_books[bookIdx + 1]);
            if (_selectedChapter != null && _selectedChapter!.verses.isNotEmpty) {
              setState(() {
                _selectedVerseNumbers.add(_selectedChapter!.verses.first.verseNumber);
              });
              targetVerse = _selectedChapter!.verses.first;
            }
          }
        }
      }
    } else {
      // Prev navigation
      if (currentIdx == -1) {
        setState(() {
          _selectedVerseNumbers.clear();
          _selectedVerseNumbers.add(verses.last.verseNumber);
        });
        targetVerse = verses.last;
      } else if (currentIdx > 0) {
        setState(() {
          _selectedVerseNumbers.clear();
          _selectedVerseNumbers.add(verses[currentIdx - 1].verseNumber);
        });
        targetVerse = verses[currentIdx - 1];
      } else {
        // Go to previous chapter's last verse
        final chapters = _currentBookData!.chapters;
        final chapIdx = chapters.indexWhere((c) => c.chapterNumber == _selectedChapter!.chapterNumber);
        if (chapIdx > 0) {
          final prevChap = chapters[chapIdx - 1];
          _selectChapter(prevChap);
          if (prevChap.verses.isNotEmpty) {
            setState(() {
              _selectedVerseNumbers.add(prevChap.verses.last.verseNumber);
            });
            targetVerse = prevChap.verses.last;
          }
        } else {
          // Go to previous book's last chapter's last verse
          final bookIdx = _books.indexOf(_selectedBook!);
          if (bookIdx > 0) {
            await _selectBook(_books[bookIdx - 1]);
            if (_currentBookData != null && _currentBookData!.chapters.isNotEmpty) {
              final lastChap = _currentBookData!.chapters.last;
              _selectChapter(lastChap);
              if (lastChap.verses.isNotEmpty) {
                setState(() {
                  _selectedVerseNumbers.add(lastChap.verses.last.verseNumber);
                });
                targetVerse = lastChap.verses.last;
              }
            }
          }
        }
      }
    }

    // Automatically present the verse we just navigated to
    if (targetVerse != null) {
      _presentSpecificVerse(targetVerse);
    }
  }

  void _copySelectedToClipboard() {
    if (_selectedVerseNumbers.isEmpty || _selectedChapter == null) return;
    final buffer = StringBuffer();
    buffer.write('${_selectedBook} ${_selectedChapter!.chapterNumber}:');
    final sortedVerses = _selectedChapter!.verses
        .where((v) => _selectedVerseNumbers.contains(v.verseNumber))
        .toList();
    
    for (int i = 0; i < sortedVerses.length; i++) {
      buffer.write('${sortedVerses[i].verseNumber} ${sortedVerses[i].text}');
      if (i < sortedVerses.length - 1) buffer.write(' ');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied selected verses to clipboard'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

  void _addSelectedToPresentation() {
    if (_selectedVerseNumbers.isEmpty || _selectedChapter == null) return;
    final sortedVerses = _selectedChapter!.verses
        .where((v) => _selectedVerseNumbers.contains(v.verseNumber))
        .toList();

    final settings = AppSettings.instance;
    setState(() {
      for (final v in sortedVerses) {
        final List<String> segments = settings.bibleAutoSplit
            ? _splitVerseText(v.text, settings.bibleMaxChars, settings.bibleMaxLines)
            : [v.text];

        for (int i = 0; i < segments.length; i++) {
          final id = DateTime.now().microsecondsSinceEpoch.toString() + v.verseNumber + '_$i';
          final letterSuffix = segments.length > 1 ? String.fromCharCode(97 + i) : ''; // 97 is ASCII code for 'a'
          final slide = SlideData(
            id: id,
            title: '${_selectedBook} ${_selectedChapter!.chapterNumber}:${v.verseNumber}$letterSuffix',
            subtitle: segments[i],
            imageUrl: '',
            opacity: 0.0,
            isBold: settings.bibleIsBold,
            isItalic: settings.bibleIsItalic,
            titleFontSize: settings.bibleFontSize,
            subtitleFontSize: settings.bibleFontSize * 0.8,
            bgColorValue: settings.bibleBgColor,
            textColorValue: settings.bibleTextColor,
          );
          _presentationQueue.add(slide);
        }
      }
      _selectedVerseNumbers.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${sortedVerses.length} verses to presentation queue'),
        backgroundColor: SacredColors.primary,
      ),
    );
  }

  void _sendQueueToPreview() {
    if (_presentationQueue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presentation queue is empty')),
      );
      return;
    }

    final presentationId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPage(
          presentationId: presentationId,
          outlineText: _presentationQueue.map((s) => '${s.title}\n${s.subtitle}').join('\n\n'),
          initialSlides: List.from(_presentationQueue),
          initialSections: [],
          selectedTheme: 'Minimal',
          isBiblePassage: true,
        ),
      ),
    );
  }
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
        _currentParsedRef = null;
        _autoCompleteSuggestion = '';
      });
      return;
    }

    final results = <Map<String, dynamic>>[];
    final parsed = await BibleService.instance.parseReference(_selectedTranslation, query);

    setState(() {
      _currentParsedRef = parsed;
      _isSearching = true;
    });

    // Handle autocompletion suggestions
    String suggestion = '';
    if (parsed.isValid && parsed.book != null) {
      if (parsed.chapter != null) {
        if (parsed.verses.isNotEmpty) {
          // If range/list is parsed, show it
          suggestion = parsed.normalizedReference ?? '';
        } else {
          // Chapter only
          suggestion = '${parsed.book} ${parsed.chapter}:';
        }
      } else {
        // Book only
        suggestion = '${parsed.book} 1';
      }
    } else {
      // Try to find a book suggestion matching prefix fuzzy search
      final queryLower = query.toLowerCase();
      final booksList = await BibleService.instance.getBooks(_selectedTranslation);
      final matchedBook = booksList.firstWhere(
        (b) => b.toLowerCase().startsWith(queryLower) ||
               (BibleService.instance.abbreviations[queryLower] != null &&
                b.toLowerCase() == BibleService.instance.abbreviations[queryLower]!.toLowerCase()),
        orElse: () => '',
      );
      if (matchedBook.isNotEmpty) {
        suggestion = '$matchedBook ';
      }
    }

    setState(() {
      _autoCompleteSuggestion = suggestion;
    });

    // Fetch matches from BibleService searchVerses
    final textResults = await BibleService.instance.searchVerses(_selectedTranslation, query);
    results.addAll(textResults);

    setState(() {
      _searchResults = results;
      _isSearching = query.isNotEmpty;
    });
  }

  // Open passage target directly when Enter is pressed
  Future<void> _openParsedReference() async {
    final parsed = _currentParsedRef;
    if (parsed == null || !parsed.isValid || parsed.book == null) return;

    await _selectBook(parsed.book!, targetChapter: parsed.chapter?.toString() ?? '1');
    setState(() {
      _selectedVerseNumbers.clear();
      if (parsed.verses.isNotEmpty) {
        for (final v in parsed.verses) {
          _selectedVerseNumbers.add(v.toString());
        }
      }
      // Clear search box to restore chapter detail view
      _searchController.clear();
      _isSearching = false;
      _currentParsedRef = null;
      _autoCompleteSuggestion = '';
    });
  }

  // --- Category Color Helper ---
  Color _getBookCategoryColor(String book) {
    // 66 books category division
    final pentateuch = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'];
    final historical = [
      'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
      '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther'
    ];
    final poetry = ['Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Song Of Solomon'];
    final majorProphets = ['Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel'];
    final minorProphets = [
      'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
      'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi'
    ];
    final gospels = ['Matthew', 'Mark', 'Luke', 'John'];
    final acts = ['Acts'];
    final pauline = [
      'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
      'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
      '1 Timothy', '2 Timothy', 'Titus', 'Philemon'
    ];
    final general = ['Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude'];
    final revelation = ['Revelation'];

    if (pentateuch.contains(book)) return const Color(0xFFF97316); // warm orange
    if (historical.contains(book)) return const Color(0xFFF59E0B); // amber
    if (poetry.contains(book)) return const Color(0xFFEF4444); // red
    if (majorProphets.contains(book)) return const Color(0xFFA855F7); // purple
    if (minorProphets.contains(book)) return const Color(0xFF8B5CF6); // violet
    if (gospels.contains(book)) return const Color(0xFF3B82F6); // blue
    if (acts.contains(book)) return const Color(0xFF14B8A6); // teal
    if (pauline.contains(book)) return const Color(0xFF10B981); // green
    if (general.contains(book)) return const Color(0xFF059669); // emerald
    if (revelation.contains(book)) return const Color(0xFF84CC16); // lime

    return Colors.grey;
  }

  String _getBookAbbreviation(String book) {
    final map = {
      'Genesis': 'Gn', 'Exodus': 'Ex', 'Leviticus': 'Lv', 'Numbers': 'Nm', 'Deuteronomy': 'Dt',
      'Joshua': 'Jos', 'Judges': 'Jg', 'Ruth': 'Ru', '1 Samuel': '1Sm', '2 Samuel': '2Sm',
      '1 Kings': '1Ki', '2 Kings': '2Ki', '1 Chronicles': '1Ch', '2 Chronicles': '2Ch',
      'Ezra': 'Ezr', 'Nehemiah': 'Ne', 'Esther': 'Es', 'Job': 'Jb', 'Psalms': 'Ps',
      'Proverbs': 'Pr', 'Ecclesiastes': 'Ec', 'Song of Solomon': 'So', 'Song Of Solomon': 'So',
      'Isaiah': 'Is', 'Jeremiah': 'Jr', 'Lamentations': 'La', 'Ezekiel': 'Eze', 'Daniel': 'Dn',
      'Hosea': 'Ho', 'Joel': 'Jl', 'Amos': 'Am', 'Obadiah': 'Ob', 'Jonah': 'Jon',
      'Micah': 'Mic', 'Nahum': 'Na', 'Habakkuk': 'Hab', 'Zephaniah': 'Zp', 'Haggai': 'Hg',
      'Zechariah': 'Zc', 'Malachi': 'Ml', 'Matthew': 'Mt', 'Mark': 'Mk', 'Luke': 'Lk',
      'John': 'Jn', 'Acts': 'Ac', 'Romans': 'Rm', '1 Corinthians': '1Co', '2 Corinthians': '2Co',
      'Galatians': 'Ga', 'Ephesians': 'Eph', 'Philippians': 'Php', 'Colossians': 'Col',
      '1 Thessalonians': '1Th', '2 Thessalonians': '2Th', '1 Timothy': '1Ti', '2 Timothy': '2Ti',
      'Titus': 'Tit', 'Philemon': 'Phm', 'Hebrews': 'Heb', 'James': 'Jm', '1 Peter': '1Pe',
      '2 Peter': '2Pe', '1 John': '1Jo', '2 John': '2Jo', '3 John': '3Jo', 'Jude': 'Jud',
      'Revelation': 'Rev'
    };
    return map[book] ?? book.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

    return Focus(
      focusNode: _pageFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !_searchFocusNode.hasFocus) {
          // Present highlighted verse on Enter key press
          if (event.logicalKey == LogicalKeyboardKey.enter && _selectedVerseNumbers.isNotEmpty && _selectedChapter != null) {
            final activeVerseNum = _selectedVerseNumbers.first;
            final match = _selectedChapter!.verses.firstWhere((v) => v.verseNumber == activeVerseNum, orElse: () => BibleVerse(verseNumber: '', text: ''));
            if (match.verseNumber.isNotEmpty) {
              _presentSpecificVerse(match);
              return KeyEventResult.handled;
            }
          }

          // Navigate verses on ArrowUp / ArrowDown keypress
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _navigateVerses(true);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _navigateVerses(false);
            return KeyEventResult.handled;
          }

          // Bind Ctrl+G or slash (/) shortcut focus keys
          final isCtrlG = (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyG);
          final isSlash = (event.logicalKey == LogicalKeyboardKey.slash);

          if (isCtrlG || isSlash) {
            _searchFocusNode.requestFocus();
            _searchController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _searchController.text.length,
            );
            return KeyEventResult.handled;
          }

          final character = event.character;
          if (character != null && character.isNotEmpty) {
            // Check if it is a printable alphanumeric key or punctuation
            final codeUnit = character.codeUnitAt(0);
            final isAlphanumeric = (codeUnit >= 48 && codeUnit <= 57) || // 0-9
                                   (codeUnit >= 65 && codeUnit <= 90) || // A-Z
                                   (codeUnit >= 97 && codeUnit <= 122) || // a-z
                                   (codeUnit == 32) || // space
                                   (codeUnit == 58); // colon

            if (isAlphanumeric) {
              _searchFocusNode.requestFocus();
              _searchController.text = _searchController.text + character;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: _searchController.text.length),
              );
              _performSearch();
              return KeyEventResult.handled;
            }
          }
        } else if (event is KeyDownEvent && _searchFocusNode.hasFocus) {
          // Clear and exit search mode on Escape keypress
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _searchController.clear();
            _performSearch();
            _pageFocusNode.requestFocus();
            PresentationController.instance.closeAudienceWindow();
            return KeyEventResult.handled;
          }
        } else if (event is KeyDownEvent && !_searchFocusNode.hasFocus) {
          // Close audience window on Escape if not searching
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            PresentationController.instance.closeAudienceWindow();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: SacredColors.background,
        child: Column(
          children: [
            // Top Toolbar
            _buildTopToolbar(context),
            Divider(height: 1, color: SacredColors.outlineVariant),
            
            Expanded(
              child: Row(
                children: [
                  // Left Panel: Collapsible Scripture Explorer
                  if (!_isSidebarCollapsed) ...[
                    _buildLeftSidebar(context),
                    _buildVerticalResizer(context),
                  ],
                  
                  // Middle Panel: Grid navigation + Verse detail
                  Expanded(
                    child: _buildMiddlePanel(context),
                  ),
                  
                  VerticalDivider(width: 1, color: SacredColors.outlineVariant),
                  
                  // Right Panel: Presentation Queue
                  if (isDesktop)
                    _buildRightQueuePanel(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Toolbar Widget ---
  Widget _buildTopToolbar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: SacredColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isSidebarCollapsed ? Icons.menu : Icons.menu_open),
            onPressed: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
            },
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              'Scripture Studio',
              overflow: TextOverflow.ellipsis,
              style: SacredTypography.headlineMd(context).copyWith(
                fontWeight: FontWeight.bold,
                color: SacredColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // History Navigation
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _historyIndex > 0 ? () => _navigateHistory(false) : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _historyIndex < _navigationHistory.length - 1 ? () => _navigateHistory(true) : null,
          ),
          
          const Spacer(),
          
          // Selection Indicator
          if (_selectedVerseNumbers.isNotEmpty)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SacredColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SacredColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: SacredColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_selectedVerseNumbers.length} Selected',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: SacredColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

           IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Bible Presentation Settings',
            onPressed: () => _showBibleSettingsDialog(context),
          ),
          const SizedBox(width: 8),

          // Display Target Selector synced with DisplayManager
          AnimatedBuilder(
            animation: DisplayManager.instance,
            builder: (context, child) {
              final dm = DisplayManager.instance;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 38,
                decoration: BoxDecoration(
                  color: SacredColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SacredColors.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Present To: ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: SacredColors.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: DropdownButton<String>(
                        value: dm.selectedDisplay?.id,
                        dropdownColor: SacredColors.surfaceContainer,
                        underline: const SizedBox(),
                        isExpanded: false,
                        icon: Icon(Icons.arrow_drop_down, size: 16, color: SacredColors.onSurfaceVariant),
                        style: GoogleFonts.inter(color: SacredColors.onSurface, fontSize: 12),
                        onChanged: (val) {
                          if (val != null) {
                            dm.selectDisplay(val);
                          }
                        },
                        items: dm.displays.map((disp) {
                          return DropdownMenuItem<String>(
                            value: disp.id,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                disp.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 14, color: SacredColors.onSurfaceVariant),
                      tooltip: 'Refresh Displays',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await dm.refreshDisplays();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SacredColors.primary,
              foregroundColor: SacredColors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.slideshow_rounded, size: 18),
            label: const Text('Present Now'),
            onPressed: _sendQueueToPreview,
          ),
        ],
      ),
    );
  }

  // --- Left Panel Widget: Scripture Explorer ---
  Widget _buildLeftSidebar(BuildContext context) {
    return Container(
      width: _sidebarWidth,
      color: SacredColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Translation selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedTranslation,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: SacredColors.surface,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'KJV', child: Text('KJV (King James)')),
                      DropdownMenuItem(value: 'NIV', child: Text('NIV (New Int. Version)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTranslation = val;
                          _loadInitialData();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    _openParsedReference();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.tab && _autoCompleteSuggestion.isNotEmpty) {
                    setState(() {
                      _searchController.text = _autoCompleteSuggestion;
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _autoCompleteSuggestion.length),
                      );
                    });
                    _performSearch();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Hint Auto-complete suggestion layout background
                  if (_searchController.text.isNotEmpty &&
                      _autoCompleteSuggestion.isNotEmpty &&
                      _autoCompleteSuggestion.toLowerCase().startsWith(_searchController.text.toLowerCase()))
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 2),
                      child: Text(
                        _autoCompleteSuggestion,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  
                  // Primary input field with green/red status color borders
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search scriptures...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _searchController.text.isEmpty
                              ? SacredColors.outline
                              : (_currentParsedRef?.isValid == true ? Colors.green : Colors.red),
                          width: _searchController.text.isEmpty ? 1.0 : 1.8,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _searchController.text.isEmpty
                              ? SacredColors.primary
                              : (_currentParsedRef?.isValid == true ? Colors.green : Colors.red),
                          width: 2.0,
                        ),
                      ),
                    ),
                    onChanged: (_) => _performSearch(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scrollable content
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildChapterVersesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterVersesList() {
    if (_selectedChapter == null) {
      return const Center(child: Text('Select a book and chapter'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _selectedChapter!.verses.length,
      itemBuilder: (context, index) {
        final verse = _selectedChapter!.verses[index];
        final isSelected = _selectedVerseNumbers.contains(verse.verseNumber);

        return Card(
          color: isSelected ? SacredColors.primary.withValues(alpha: 0.1) : SacredColors.surface,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? SacredColors.primary : SacredColors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _toggleVerseSelection(verse.verseNumber),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: Text(
                      verse.verseNumber,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? SacredColors.primary : SacredColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      verse.text,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: SacredColors.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text('No matching verses found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final res = _searchResults[index];
        final ref = '${res['book']} ${res['chapter']}:${res['verse']}';
        
        return Card(
          color: SacredColors.surface,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: SacredColors.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              // Navigate to the book/chapter/verse
              await _selectBook(res['book']!, targetChapter: res['chapter']!);
              setState(() {
                _searchController.clear();
                _isSearching = false;
                _selectedVerseNumbers.clear();
                if (res['verse'] != null) {
                  _selectedVerseNumbers.add(res['verse']!);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: SacredColors.primary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    res['text']!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: SacredColors.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Middle Panel Widget: Books Grid, Chapters Grid, Verse Presentation Workspace ---
  Widget _buildMiddlePanel(BuildContext context) {
    final hasChapters = _currentBookData != null;
    final double booksHeight = (hasChapters ? _booksSectionHeight - 110.0 : _booksSectionHeight).clamp(100.0, 500.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Book Grid Panel
        Container(
          height: booksHeight,
          color: SacredColors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Books of the Bible',
                style: SacredTypography.labelLg(context).copyWith(
                  color: SacredColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _books.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.45,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _books.length,
                        itemBuilder: (context, index) {
                          final book = _books[index];
                          final isSelected = _selectedBook == book;
                          final catColor = _getBookCategoryColor(book);

                          return Material(
                            color: isSelected ? catColor : catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _selectBook(book),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : catColor.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getBookAbbreviation(book),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected ? Colors.white : catColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      book,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white.withValues(alpha: 0.9) : SacredColors.onSurface.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        
        Divider(height: 1, color: SacredColors.outlineVariant),
        
        // Chapters Panel
        if (_currentBookData != null)
          Container(
            height: 110,
            color: SacredColors.surfaceContainerLowest,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chapters',
                  style: SacredTypography.labelSm(context).copyWith(
                    color: SacredColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _currentBookData!.chapters.length,
                    itemBuilder: (context, index) {
                      final chap = _currentBookData!.chapters[index];
                      final isSelected = _selectedChapter?.chapterNumber == chap.chapterNumber;
                      final themeColor = _getBookCategoryColor(_selectedBook ?? '');

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Material(
                            color: isSelected ? themeColor : SacredColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _selectChapter(chap),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : themeColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  chap.chapterNumber,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isSelected ? Colors.white : themeColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
        _buildHorizontalResizer(context),
        
        // Main Verse presentation/reading display workspace
        Expanded(
          child: Container(
            color: SacredColors.background,
            padding: const EdgeInsets.all(24),
            child: _selectedChapter == null
                ? const Center(child: Text('Select a book and chapter to view.'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header reference
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${_selectedBook} ${_selectedChapter!.chapterNumber}',
                              overflow: TextOverflow.ellipsis,
                              style: SacredTypography.headlineMd(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: SacredColors.onSurface,
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(_isComparing ? Icons.compare : Icons.compare_arrows, color: _isComparing ? SacredColors.primary : SacredColors.outline),
                            tooltip: 'Compare translations',
                            onPressed: () async {
                              final nextCompare = !_isComparing;
                              BibleBook? compData;
                              if (nextCompare && _selectedBook != null) {
                                compData = await BibleService.instance.loadBook(_comparisonTranslation, _selectedBook!);
                              }
                              setState(() {
                                _isComparing = nextCompare;
                                _comparisonBookData = compData;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: Icon(Icons.select_all, color: SacredColors.primary),
                            label: const Text('Select All'),
                            onPressed: _selectAllVerses,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copy selected verses',
                            onPressed: _selectedVerseNumbers.isNotEmpty ? _copySelectedToClipboard : null,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add to Queue'),
                            onPressed: _selectedVerseNumbers.isNotEmpty ? _addSelectedToPresentation : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Verse Text display
                      Expanded(
                        child: _isComparing
                            ? Row(
                                children: [
                                  // Left Column: Selected Translation
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: SacredColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: SacredColors.outlineVariant),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text('Translation: $_selectedTranslation', style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold, color: SacredColors.primary)),
                                          ),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              physics: const BouncingScrollPhysics(),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: _selectedChapter!.verses.map((v) {
                                                  final isSelected = _selectedVerseNumbers.contains(v.verseNumber);
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                    child: Text('${v.verseNumber} ${v.text}', style: GoogleFonts.inter(fontSize: 15, color: isSelected ? SacredColors.primary : SacredColors.onSurface)),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Right Column: Comparison Translation
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: SacredColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: SacredColors.outlineVariant),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text('Comparison: $_comparisonTranslation', style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold, color: SacredColors.primary)),
                                          ),
                                          Expanded(
                                            child: SingleChildScrollView(
                                              physics: const BouncingScrollPhysics(),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: (_comparisonBookData != null &&
                                                        _comparisonBookData!.chapters.any((c) => c.chapterNumber == _selectedChapter!.chapterNumber))
                                                    ? _comparisonBookData!.chapters.firstWhere((c) => c.chapterNumber == _selectedChapter!.chapterNumber).verses.map((v) {
                                                        final isSelected = _selectedVerseNumbers.contains(v.verseNumber);
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                          child: Text('${v.verseNumber} ${v.text}', style: GoogleFonts.inter(fontSize: 15, color: isSelected ? SacredColors.primary : SacredColors.onSurface)),
                                                        );
                                                      }).toList()
                                                    : [const Text('No comparison version text loaded.')],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: SacredColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: SacredColors.outlineVariant),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _selectedChapter!.verses.map((v) {
                                      final isSelected = _selectedVerseNumbers.contains(v.verseNumber);
                                      final themeColor = _getBookCategoryColor(_selectedBook ?? '');

                                      // Use a StatefulWidget helper class to manage hover state cleanly without throwing build cycle exceptions
                                      return VerseRowItem(
                                        verse: v,
                                        isSelected: isSelected,
                                        themeColor: themeColor,
                                        onTap: () => _toggleVerseSelection(v.verseNumber),
                                        onDoubleTap: () => _presentSpecificVerse(v),
                                        onPresent: () => _presentSpecificVerse(v),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- Right Panel Widget: Presentation Queue Sidebar ---
  Widget _buildRightQueuePanel(BuildContext context) {
    return Container(
      width: 280,
      color: SacredColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Presentation Queue',
                  style: SacredTypography.labelLg(context).copyWith(
                    fontWeight: FontWeight.bold,
                    color: SacredColors.onSurface,
                  ),
                ),
                const Spacer(),
                if (_presentationQueue.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _presentationQueue.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: _presentationQueue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_play_next, size: 48, color: SacredColors.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Queue is empty',
                          style: TextStyle(color: SacredColors.onSurfaceVariant.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Add verses from explorer',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _presentationQueue.length,
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final slide = _presentationQueue.removeAt(oldIdx);
                        _presentationQueue.insert(newIdx, slide);
                      });
                    },
                    itemBuilder: (context, index) {
                      final slide = _presentationQueue[index];
                      return Card(
                        key: ValueKey(slide.id),
                        color: SacredColors.surface,
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: SacredColors.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                          title: Text(
                            slide.title,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: SacredColors.primary),
                          ),
                          subtitle: Text(
                            slide.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, color: SacredColors.onSurface),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _presentationQueue.removeAt(index);
                                  });
                                },
                              ),
                              const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          if (_presentationQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SacredColors.primary,
                  foregroundColor: SacredColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _sendQueueToPreview,
                child: const Text('Export Deck to Preview'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerticalResizer(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _sidebarWidth = (_sidebarWidth + details.delta.dx).clamp(240.0, 500.0);
          });
        },
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: SacredColors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalResizer(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          setState(() {
            _booksSectionHeight = (_booksSectionHeight + details.delta.dy).clamp(180.0, 550.0);
          });
        },
        child: Container(
          height: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              height: 1,
              color: SacredColors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _showBibleSettingsDialog(BuildContext context) {
    final settings = AppSettings.instance;
    final themeColor = _getBookCategoryColor(_selectedBook ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.tune, color: SacredColors.primary),
                  const SizedBox(width: 12),
                  const Text('Bible Presentation Styles'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Background Color Selection
                    const Text('Background Style', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _bgColorOption(setDialogState, 'Deep Purple', 0xFF2E0052),
                        _bgColorOption(setDialogState, 'Dark Charcoal', 0xFF121212),
                        _bgColorOption(setDialogState, 'Deep Blue', 0xFF0D1B2A),
                        _bgColorOption(setDialogState, 'Sacred Red', 0xFF3D0C11),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Text Color Selection
                    const Text('Text Style', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _textColorOption(setDialogState, 'White', 0xFFFFFFFF),
                        _textColorOption(setDialogState, 'Cream', 0xFFFDF0D5),
                        _textColorOption(setDialogState, 'Soft Yellow', 0xFFFFF275),
                        _textColorOption(setDialogState, 'Gold', 0xFFFFD700),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Font Size Slider
                    Row(
                      children: [
                        const Text('Font Size: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${settings.bibleFontSize.toInt()} px'),
                      ],
                    ),
                    Slider(
                      value: settings.bibleFontSize,
                      min: 24.0,
                      max: 72.0,
                      activeColor: themeColor,
                      onChanged: (val) {
                        setDialogState(() {
                          settings.bibleFontSize = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bold & Italic Switches
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bold Text', style: TextStyle(fontWeight: FontWeight.w600)),
                        Switch(
                          value: settings.bibleIsBold,
                          activeColor: themeColor,
                          onChanged: (val) {
                            setDialogState(() {
                              settings.bibleIsBold = val;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Italic Text', style: TextStyle(fontWeight: FontWeight.w600)),
                        Switch(
                          value: settings.bibleIsItalic,
                          activeColor: themeColor,
                          onChanged: (val) {
                            setDialogState(() {
                              settings.bibleIsItalic = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bgColorOption(StateSetter setDialogState, String label, int hexValue) {
    final settings = AppSettings.instance;
    final isSelected = settings.bibleBgColor == hexValue;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          settings.bibleBgColor = hexValue;
        });
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Color(hexValue),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey.withOpacity(0.5),
            width: isSelected ? 3.0 : 1.5,
          ),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)] : null,
        ),
        child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }

  List<String> _splitVerseText(String text, int maxChars, int maxLines) {
    if (text.length <= maxChars && text.split('\n').length <= maxLines) {
      return [text];
    }

    final List<String> segments = [];
    final RegExp sentenceEnd = RegExp(r'(?<=[.!?])\s+');
    final RegExp punctuationEnd = RegExp(r'(?<=[,;:])\s+');

    // Helper to estimate if lines fit
    bool fits(String block) {
      if (block.length > maxChars) return false;
      // rough line estimation by width or character count
      final linesCount = (block.length / (maxChars / maxLines).clamp(30, 80)).ceil();
      return linesCount <= maxLines;
    }

    // Try splitting by sentence first
    final sentences = text.split(sentenceEnd);
    String currentBlock = '';

    for (final s in sentences) {
      final candidate = currentBlock.isEmpty ? s : '$currentBlock $s';
      if (fits(candidate)) {
        currentBlock = candidate;
      } else {
        if (currentBlock.isNotEmpty) {
          segments.add(currentBlock.trim());
          currentBlock = s;
        } else {
          // A single sentence is too long! Try splitting by punctuation
          final clauses = s.split(punctuationEnd);
          for (final c in clauses) {
            final subCandidate = currentBlock.isEmpty ? c : '$currentBlock $c';
            if (fits(subCandidate)) {
              currentBlock = subCandidate;
            } else {
              if (currentBlock.isNotEmpty) {
                segments.add(currentBlock.trim());
                currentBlock = c;
              } else {
                // A single clause is too long! Split by word
                final words = c.split(' ');
                for (final w in words) {
                  final wordCandidate = currentBlock.isEmpty ? w : '$currentBlock $w';
                  if (fits(wordCandidate)) {
                    currentBlock = wordCandidate;
                  } else {
                    if (currentBlock.isNotEmpty) {
                      segments.add(currentBlock.trim());
                    }
                    currentBlock = w;
                  }
                }
              }
            }
          }
        }
      }
    }

    if (currentBlock.isNotEmpty) {
      segments.add(currentBlock.trim());
    }

    return segments;
  }

  Widget _textColorOption(StateSetter setDialogState, String label, int hexValue) {
    final settings = AppSettings.instance;
    final isSelected = settings.bibleTextColor == hexValue;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          settings.bibleTextColor = hexValue;
        });
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Color(hexValue) : Colors.grey.withOpacity(0.5),
            width: isSelected ? 3.0 : 1.5,
          ),
        ),
        child: Center(
          child: Text(
            'Aa',
            style: TextStyle(
              color: Color(hexValue),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class VerseRowItem extends StatefulWidget {
  final BibleVerse verse;
  final bool isSelected;
  final Color themeColor;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onPresent;

  const VerseRowItem({
    super.key,
    required this.verse,
    required this.isSelected,
    required this.themeColor,
    required this.onTap,
    required this.onDoubleTap,
    required this.onPresent,
  });

  @override
  State<VerseRowItem> createState() => _VerseRowItemState();
}

class _VerseRowItemState extends State<VerseRowItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected ? widget.themeColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${widget.verse.verseNumber} ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: widget.isSelected ? widget.themeColor : SacredColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: widget.verse.text,
                        style: GoogleFonts.inter(
                          color: widget.isSelected ? widget.themeColor : SacredColors.onSurface,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: _isHovering ? 1.0 : 0.0,
                child: IconButton(
                  icon: Icon(Icons.play_circle_fill, color: widget.themeColor, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Present this verse instantly',
                  onPressed: widget.onPresent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

