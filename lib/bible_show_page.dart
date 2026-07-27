import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bible_service.dart';
import 'dashboard_page.dart'; // SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'preview_page.dart';
import 'presentation_controller.dart';

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
  
  // Selection
  final Set<String> _selectedVerseNumbers = {};
  final List<SlideData> _presentationQueue = [];

  // Collapsible sidebar
  bool _isSidebarCollapsed = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Undo/Redo queues for navigation
  final List<Map<String, String>> _navigationHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
    if (bookData != null) {
      setState(() {
        _selectedBook = bookName;
        _currentBookData = bookData;
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

    setState(() {
      for (final v in sortedVerses) {
        final id = DateTime.now().microsecondsSinceEpoch.toString() + v.verseNumber;
        final slide = SlideData(
          id: id,
          title: '${_selectedBook} ${_selectedChapter!.chapterNumber}:${v.verseNumber}',
          subtitle: v.text,
          imageUrl: '',
          opacity: 0.0,
          isBold: false,
          isItalic: false,
          titleFontSize: 32,
          subtitleFontSize: 24,
        );
        _presentationQueue.add(slide);
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
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = <Map<String, dynamic>>[];

    // Check if query is a Bible reference lookup, e.g. "John 3" or "John 3:16" or "1 Samuel 3"
    final refRegex = RegExp(r'^(\d?\s*[a-zA-Z\s]+?)\s+(\d+)(?:\s*:\s*(\d+))?$');
    final match = refRegex.firstMatch(query);
    if (match != null) {
      final inputBook = match.group(1)?.trim() ?? '';
      final chapterStr = match.group(2) ?? '';
      final verseStr = match.group(3);

      // Find closest book name
      final matchedBook = _books.firstWhere(
        (b) => b.replaceAll(' ', '').toLowerCase() == inputBook.replaceAll(' ', '').toLowerCase(),
        orElse: () => '',
      );

      if (matchedBook.isNotEmpty) {
        results.add({
          'isReference': true,
          'book': matchedBook,
          'chapter': chapterStr,
          'verse': verseStr,
          'text': 'Go to $matchedBook $chapterStr${verseStr != null ? ':$verseStr' : ''}',
        });
      }
    }

    // Also fetch keyword search results
    final textResults = await BibleService.instance.searchVerses(_selectedTranslation, query);
    results.addAll(textResults);

    setState(() {
      _searchResults = results;
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

    return Container(
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
                if (!_isSidebarCollapsed)
                  _buildLeftSidebar(context),
                
                VerticalDivider(width: 1, color: SacredColors.outlineVariant),
                
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
          Text(
            'Scripture Studio',
            style: SacredTypography.headlineMd(context).copyWith(
              fontWeight: FontWeight.bold,
              color: SacredColors.primary,
            ),
          ),
          const SizedBox(width: 32),
          
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
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SacredColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: SacredColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: SacredColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${_selectedVerseNumbers.length} Selected',
                      style: TextStyle(color: SacredColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

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
      width: 320,
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
            child: TextField(
              controller: _searchController,
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => _performSearch(),
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
        final isRef = res['isReference'] == true;
        final ref = isRef ? 'Passage Lookup' : '${res['book']} ${res['chapter']}:${res['verse']}';
        
        return Card(
          color: isRef ? SacredColors.primary.withValues(alpha: 0.1) : SacredColors.surface,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isRef ? SacredColors.primary : SacredColors.outlineVariant),
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
                  Row(
                    children: [
                      if (isRef)
                        Icon(Icons.menu_book, size: 14, color: SacredColors.primary),
                      if (isRef) const SizedBox(width: 6),
                      Text(
                        ref,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: SacredColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    res['text']!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isRef ? FontWeight.w600 : FontWeight.normal,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Book Grid Panel
        Container(
          height: 260,
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
          
        Divider(height: 1, color: SacredColors.outlineVariant),
        
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
                          Text(
                            '${_selectedBook} ${_selectedChapter!.chapterNumber}',
                            style: SacredTypography.headlineMd(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: SacredColors.onSurface,
                            ),
                          ),
                          const Spacer(),
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: SacredColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SacredColors.outlineVariant),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: RichText(
                              text: TextSpan(
                                children: _selectedChapter!.verses.map((v) {
                                  final isSelected = _selectedVerseNumbers.contains(v.verseNumber);
                                  final themeColor = _getBookCategoryColor(_selectedBook ?? '');

                                  return WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () => _toggleVerseSelection(v.verseNumber),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? themeColor.withValues(alpha: 0.15) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '${v.verseNumber} ',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected ? themeColor : SacredColors.primary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              TextSpan(
                                                text: '${v.text}  ',
                                                style: GoogleFonts.inter(
                                                  color: isSelected ? themeColor : SacredColors.onSurface,
                                                  fontSize: 16,
                                                  height: 1.6,
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
}
