import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashboard_page.dart'; // Reuse SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'preview_page.dart';
import 'fullscreen_presenter_page.dart';
import 'connectivity_badge.dart';

class LibraryPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const LibraryPage({super.key, this.scaffoldKey});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _selectedCategory = 'Presentations';
  String _searchQuery = '';
  List<LibraryItem> _hymns = [];
  bool _isLoadingHymns = false;
  late List<LibraryItem> _dynamicMockItems;

  @override
  void initState() {
    super.initState();
    _dynamicMockItems = List.from(_items);
    _loadHymns();
  }

  Future<void> _loadHymns() async {
    if (!mounted) return;
    setState(() => _isLoadingHymns = true);

    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(DefaultAssetBundle.of(context));
      final List<String> paths = manifest.listAssets()
          .where((key) => key.toLowerCase().startsWith('assets/hymns/') && key.toLowerCase().endsWith('.txt'))
          .toList();

      final List<LibraryItem> loadedHymns = [];
      for (final path in paths) {
        final fileName = Uri.decodeComponent(path.split('/').last);
        final title = fileName.replaceAll('.txt', '');
        final numMatch = RegExp(r'^(\d+)').firstMatch(title);
        final hymnNum = numMatch != null ? int.tryParse(numMatch.group(1)!) ?? 999 : 999;

        loadedHymns.add(LibraryItem(
          id: 'hymn_$hymnNum',
          title: title,
          category: 'Songs',
          metadata: 'Hymn Lyrics • Tap to view',
          imageUrl: '',
          tag: 'Hymn',
          assetPath: path,
        ));
      }

      // Sort numerically by hymn number
      loadedHymns.sort((a, b) {
        final aNumMatch = RegExp(r'^hymn_(\d+)').firstMatch(a.id);
        final bNumMatch = RegExp(r'^hymn_(\d+)').firstMatch(b.id);
        final aNum = aNumMatch != null ? int.tryParse(aNumMatch.group(1)!) ?? 999 : 999;
        final bNum = bNumMatch != null ? int.tryParse(bNumMatch.group(1)!) ?? 999 : 999;
        return aNum.compareTo(bNum);
      });

      if (mounted) {
        setState(() {
          _hymns = loadedHymns;
        });
      }
    } catch (e) {
      debugPrint('Error loading hymns: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingHymns = false);
      }
    }
  }

  // Library items mock data
  final List<LibraryItem> _items = [
    // Saved Presentations
    LibraryItem(
      id: 'p1',
      title: 'Sunday Morning Service Outline',
      category: 'Presentations',
      metadata: '12 Slides • Modified 2 hours ago',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCniRs1Ld_w4si47CthTlMWPs9oRIBhnBg8r14brIYLmzm-BycsqRBBSAa5ClNrCU8RtNAwk6rwmFZegQcWRe5y0dlGib11tkH4obKwQ-_4AYo4wgTRSlq0e-sV4irdcUi-xweItlUWQu4-yMIG75WKoS5HApIF2yAc9QuRAzHaNYwMS_CI4gxp45msnSVkbuPINnONgWbzItsjsZaUxo0Y6vIjzYnY1PMavyQbz7NPSsynWrkin2eZGH5C4CS08ALHQMCQWS7PyfoU',
      tag: 'Worship',
    ),
    LibraryItem(
      id: 'p2',
      title: 'Midweek Prayer Gathering',
      category: 'Presentations',
      metadata: '8 Slides • Modified Yesterday',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAzj4bKIV4_XGsi0AAopVxbvmgDB7F6Gg7ENjFdX_qTkJmPz5xvpEdtsLncOZAbwfu7WYJocYrg4uHA1Fre-HMvMTQDsxBWC7c-3O6DP25T_zLzV45J6Z7EkGOlVTMe31XIOIkp-mbKlC9S3UnEBzzbE248cyQdlRML540kBxkTTH-R-4N0aks53Xs62c8Wuy73UApERXBWp8aMZBhHR4iH-rjtQPyChsedbsyCLsuCeQUAeh8BA4WJMDf9etg9Cq7801xQwX9Wya2T',
      tag: 'Prayer',
    ),
    LibraryItem(
      id: 'p3',
      title: 'Youth Retreat 2024',
      category: 'Presentations',
      metadata: '24 Slides • Modified Oct 12, 2023',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCGWvZBhgCUf7Nm2xjW_H_r8-BIrOpQIlEtR-63ymzRUH-Hj4gJ0vbcuU9i3TQJua_ELdncjQ5g9AR9LDeOuBbF9hRNX6UIJaKZLgnMsMoyE5gJJBPQyffhhS8SIDyKnbB2KjmBPpYg1FvfleOPH-8ZA_KcDg6GiOrXt_DTDR2qeCRU0yRHCx_03JjXqMEStI-svW8R4WYpr2hW8SBYhdoVOkMHDyc-70jFmr96O9yBKh1BI8F1Ek0okP9S9HYzk4XWKZO7PrmCbS2C',
      tag: 'Youth',
    ),

    // Media Assets
    LibraryItem(
      id: 'm1',
      title: 'Stained Glass Cathedral Window',
      category: 'Media',
      metadata: 'PNG • 4K Resolution • 3.2 MB',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD2L84Pq8Z59RpiwrMNMK28qM3sgfruhio-_Fkw4zNUvh_NpDBd7WleYrj5ty3pZNtwfdhQFIz_A9UYHqrHumR9oCxyjrGbn2PX7pxi8-db6tTO0DRK4YHokxPs2y6NrEdb_yHChie_8Oq3surzlOeVc4Fv4gpErKWu-YD3WHeUEZL0Rw4v0JXnajt1QDfczasOvswikAOlnZVm6In7VO6SXz-ysrs5ErEwOtebhUdy_Cz3FN2OUgrusIanPqYkCwpfRyMYNnfgbYzn',
      tag: 'Background',
    ),
    LibraryItem(
      id: 'm2',
      title: 'Vesper Candles Ambient Loop',
      category: 'Media',
      metadata: 'MP4 • 1080p • 18 MB',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCf-Nbj2rzl3QIjt1VvBtG0FVy2CWxawbXT4BEyB74cLe35XNYfVWsfW2k15mi0GUxj47-VLk5AN5v2Kk417mZcTAUEmgAVWLBXsqOnaXn7y6Jjas9lvUw9IrWyHfLehMVZc9vcaNTN_PUl5vdBmGLgbbR0ZTx6j9popK0L7bZwOjKOzjRC57eL3M68TdRB2OiEGJJ7W0iYyiEjfQXROrdeuHZlUt8oEi1lXE_IwZZAyel1jSg8aJZzk1cOOcajwPLsRXIko6YECagM',
      tag: 'Loop',
    ),
    LibraryItem(
      id: 'm3',
      title: 'Mountain Sunrise Sunrise',
      category: 'Media',
      metadata: 'JPG • 4K Resolution • 2.1 MB',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCumon3BIQr8XsjUfowXviKZtMn0KVb9EydsoiVZHonb6-GF8pl4K_RrBwC5ln8WSFxo4njMWz5T2e-BVtiB4NakOZxUkDnT90H5lMNzJsKwx9R12UqE-LSsk6_qh1BcsX2yTYqNTP_kTWZccLTPVeyZhbqzYzlShOkhRbJCXALcFiaoAaIp6dlIv0h9_9AjdaovAgK5n3Xl3VE58Sg_AmACbmdoF77qrNioe7-JdoZy8UkNFlyvceOXql9Hwiek_WPE6PwAL5Q2KnE',
      tag: 'Background',
    ),

    // Lyrics & Scripture
    LibraryItem(
      id: 'l1',
      title: 'Amazing Grace (My Chains Are Gone)',
      category: 'Songs',
      metadata: 'Hymn • Chris Tomlin Arrangement',
      imageUrl: '', // Text-based preview
      tag: 'Worship',
    ),
    LibraryItem(
      id: 'l2',
      title: 'How Great Is Our God',
      category: 'Songs',
      metadata: 'Worship Song • 4 Verses',
      imageUrl: '', 
      tag: 'Worship',
    ),
    LibraryItem(
      id: 's1',
      title: 'Psalm 23: The Lord is My Shepherd',
      category: 'Songs',
      metadata: 'Scripture Passage • KJV Translation',
      imageUrl: '', 
      tag: 'Psalm',
    ),
  ];

  void _deleteItem(LibraryItem item) {
    if (item.category == 'Presentations') {
      if (AppSettings.instance.recentPresentations.any((p) => p.id == item.id)) {
        AppSettings.instance.deleteRecentPresentation(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted presentation "${item.title}"'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() {
      _dynamicMockItems.removeWhere((x) => x.id == item.id);
      _hymns.removeWhere((x) => x.id == item.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${item.title}" from library'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _renameItem(LibraryItem item, String newTitle) {
    if (newTitle.trim().isEmpty) return;

    if (item.category == 'Presentations') {
      if (AppSettings.instance.recentPresentations.any((p) => p.id == item.id)) {
        AppSettings.instance.renameRecentPresentation(item.id, newTitle);
        return;
      }
    }

    setState(() {
      final mockIdx = _dynamicMockItems.indexWhere((x) => x.id == item.id);
      if (mockIdx != -1) {
        final old = _dynamicMockItems[mockIdx];
        _dynamicMockItems[mockIdx] = LibraryItem(
          id: old.id,
          title: newTitle,
          category: old.category,
          metadata: old.metadata,
          imageUrl: old.imageUrl,
          tag: old.tag,
          assetPath: old.assetPath,
        );
      }

      final hymnIdx = _hymns.indexWhere((x) => x.id == item.id);
      if (hymnIdx != -1) {
        final old = _hymns[hymnIdx];
        _hymns[hymnIdx] = LibraryItem(
          id: old.id,
          title: newTitle,
          category: old.category,
          metadata: old.metadata,
          imageUrl: old.imageUrl,
          tag: old.tag,
          assetPath: old.assetPath,
        );
      }
    });
  }

  void _duplicateItem(LibraryItem item) {
    if (item.category == 'Presentations') {
      if (AppSettings.instance.recentPresentations.any((p) => p.id == item.id)) {
        AppSettings.instance.duplicateRecentPresentation(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicated presentation "${item.title}"'),
            backgroundColor: AppSettings.instance.primaryColor,
          ),
        );
        return;
      }
    }

    setState(() {
      final String newId = '${item.id}_copy_${DateTime.now().millisecondsSinceEpoch}';
      final String newTitle = '${item.title} (Copy)';

      final mockIdx = _dynamicMockItems.indexWhere((x) => x.id == item.id);
      if (mockIdx != -1) {
        final old = _dynamicMockItems[mockIdx];
        final duplicated = LibraryItem(
          id: newId,
          title: newTitle,
          category: old.category,
          metadata: old.metadata,
          imageUrl: old.imageUrl,
          tag: old.tag,
          assetPath: old.assetPath,
        );
        _dynamicMockItems.insert(mockIdx + 1, duplicated);
      }

      final hymnIdx = _hymns.indexWhere((x) => x.id == item.id);
      if (hymnIdx != -1) {
        final old = _hymns[hymnIdx];
        final duplicated = LibraryItem(
          id: newId,
          title: newTitle,
          category: old.category,
          metadata: old.metadata,
          imageUrl: old.imageUrl,
          tag: old.tag,
          assetPath: old.assetPath,
        );
        _hymns.insert(hymnIdx + 1, duplicated);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final isDarkMode = AppSettings.instance.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;

    // Build combined list of items
    final List<LibraryItem> combinedItems = [];
    if (_selectedCategory == 'Presentations') {
      final realPres = AppSettings.instance.recentPresentations.map((pres) {
        return LibraryItem(
          id: pres.id,
          title: pres.title,
          category: 'Presentations',
          metadata: '${pres.slideCount} Slides • ${pres.relativeTime}',
          imageUrl: pres.thumbnailUrl,
          tag: 'Saved',
        );
      }).toList();
      combinedItems.addAll(realPres);
    } else if (_selectedCategory == 'Songs') {
      combinedItems.addAll(_hymns);
    }

    // Add mock items that don't duplicate titles already loaded
    for (final mockItem in _dynamicMockItems) {
      if (mockItem.category == _selectedCategory) {
        if (!combinedItems.any((item) => item.title == mockItem.title)) {
          combinedItems.add(mockItem);
        }
      }
    }

    // Filter combined items
    final filteredItems = combinedItems.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.tag.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

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
        body: SafeArea(
          child: Column(
            children: [
              // Top Header Bar
              _LibraryHeader(
                scaffoldKey: widget.scaffoldKey,
                searchQuery: _searchQuery,
                onSearchChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),

              // Categories selection bar
              _CategorySelectionBar(
                selectedCategory: _selectedCategory,
                categories: const ['Presentations', 'Media', 'Songs'],
                onCategorySelect: (cat) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
                primaryColor: primaryColor,
              ),

              // Dynamic grid representation
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 768 ? 40.0 : 16.0,
                    vertical: 24.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Subtitle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedCategory == 'Presentations'
                                    ? 'Church Slide decks'
                                    : (_selectedCategory == 'Media' ? 'Shared Background Assets' : 'Scriptures & Liturgies'),
                                style: SacredTypography.headlineMd(context).copyWith(
                                  color: SacredColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Importing new item into $_selectedCategory...'),
                                      backgroundColor: primaryColor,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                                label: Text(
                                  _selectedCategory == 'Presentations' ? 'Import Deck' : 'Upload File',
                                  style: SacredTypography.labelSm(context).copyWith(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Library Items Grid
                          if (_isLoadingHymns && _selectedCategory == 'Songs')
                            Container(
                              height: 300,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(color: primaryColor),
                            )
                          else if (filteredItems.isEmpty)
                            Container(
                              height: 300,
                              alignment: Alignment.center,
                              child: Text(
                                'No items found matching your filters.',
                                style: SacredTypography.bodyLg(context).copyWith(color: SacredColors.outline),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredItems.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: screenWidth >= 1200
                                    ? 3
                                    : (screenWidth >= 768 ? 2 : 1),
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                                childAspectRatio: _selectedCategory == 'Songs' ? 1.8 : 1.3,
                              ),
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _LibraryCard(
                                  item: item,
                                  primaryColor: primaryColor,
                                  onDelete: () => _deleteItem(item),
                                  onRename: (newTitle) => _renameItem(item, newTitle),
                                  onDuplicate: () => _duplicateItem(item),
                                );
                              },
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
    );
  }
}

class LibraryItem {
  final String id;
  final String title;
  final String category;
  final String metadata;
  final String imageUrl;
  final String tag;
  final String? assetPath;

  LibraryItem({
    required this.id,
    required this.title,
    required this.category,
    required this.metadata,
    required this.imageUrl,
    required this.tag,
    this.assetPath,
  });
}

// ------------------------ Library Header ------------------------
class _LibraryHeader extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const _LibraryHeader({
    required this.searchQuery,
    required this.onSearchChanged,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

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
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          if (!isDesktop && scaffoldKey != null) ...[
            IconButton(
              icon: Icon(Icons.menu, color: SacredColors.onSurface),
              onPressed: () => scaffoldKey?.currentState?.openDrawer(),
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: SacredColors.outlineVariant,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: SacredTypography.bodyMd(context),
                    decoration: InputDecoration(
                      hintText: 'Search Library...',
                      hintStyle: SacredTypography.bodyMd(context).copyWith(
                        color: SacredColors.outline,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: SacredColors.outline,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ConnectivityBadge(),
          const SizedBox(width: 16),
          Text(
            'Church Archive',
            style: SacredTypography.labelLg(context).copyWith(
              color: SacredColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------ Category Selection Bar ------------------------
class _CategorySelectionBar extends StatelessWidget {
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onCategorySelect;
  final Color primaryColor;

  const _CategorySelectionBar({
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelect,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surfaceContainerLow.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(
            color: SacredColors.outlineVariant,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: categories.map((cat) {
          final isSelected = cat == selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: () => onCategorySelect(cat),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                  ),
                ),
                child: Text(
                  cat,
                  style: SacredTypography.labelLg(context).copyWith(
                    color: isSelected ? primaryColor : SacredColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ------------------------ Library Card ------------------------
class _LibraryCard extends StatefulWidget {
  final LibraryItem item;
  final Color primaryColor;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRename;
  final VoidCallback? onDuplicate;

  const _LibraryCard({
    required this.item,
    required this.primaryColor,
    this.onDelete,
    this.onRename,
    this.onDuplicate,
  });

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  bool _isHovered = false;

  List<SlideData> parseHymnToSlides(String content, String title) {
    final rawStanzas = content.split(RegExp(r'(?:\r?\n){2,}'));
    
    final List<List<String>> versesChunks = [];
    List<String>? chorusChunks;
    
    for (final rawStanza in rawStanzas) {
      final lines = rawStanza.split('\n');
      final trimmedLines = lines.map((l) => l.trimRight()).toList();
      if (trimmedLines.every((l) => l.trim().isEmpty)) continue;
      
      final bool isIndented = lines.any((l) => l.startsWith(' ') || l.startsWith('\t'));
      final cleanedLines = trimmedLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      if (cleanedLines.isEmpty) continue;
      
      // Split this stanza's lines into 2-line chunks
      final List<String> chunks = [];
      for (int i = 0; i < cleanedLines.length; i += 2) {
        final end = (i + 2 < cleanedLines.length) ? i + 2 : cleanedLines.length;
        chunks.add(cleanedLines.sublist(i, end).join('\n'));
      }
      
      if (isIndented) {
        chorusChunks = chunks;
      } else {
        versesChunks.add(chunks);
      }
    }
    
    final List<SlideData> slides = [];
    const String sharedBg = '';
    
    // Default font sizes for hymns (titles like 'Verse 1' smaller, lyrics larger)
    const double hymnTitleFontSize = 24.0;
    const double hymnSubtitleFontSize = 48.0;
    
    for (int i = 0; i < versesChunks.length; i++) {
      final verseNum = i + 1;
      final chunks = versesChunks[i];
      for (final chunk in chunks) {
        slides.add(SlideData(
          id: '${slides.length + 1}'.padLeft(2, '0'),
          title: 'Verse $verseNum',
          subtitle: chunk,
          imageUrl: sharedBg,
          opacity: 0.80,
          blur: 8.0,
          titleFontSize: hymnTitleFontSize,
          subtitleFontSize: hymnSubtitleFontSize,
        ));
      }
      
      if (chorusChunks != null) {
        for (final chunk in chorusChunks) {
          slides.add(SlideData(
            id: '${slides.length + 1}'.padLeft(2, '0'),
            title: 'Chorus',
            subtitle: chunk,
            imageUrl: sharedBg,
            opacity: 0.80,
            blur: 8.0,
            titleFontSize: hymnTitleFontSize,
            subtitleFontSize: hymnSubtitleFontSize,
          ));
        }
      }
    }
    
    if (slides.isEmpty) {
      slides.add(SlideData(
        id: '01',
        title: title,
        subtitle: content.trim(),
        imageUrl: sharedBg,
        opacity: 0.80,
        blur: 8.0,
        titleFontSize: hymnTitleFontSize,
        subtitleFontSize: hymnSubtitleFontSize,
      ));
    }
    
    return slides;
  }

  Future<void> _playHymn(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final content = await DefaultAssetBundle.of(context).loadString(widget.item.assetPath!);
      final slides = parseHymnToSlides(content, widget.item.title);
      
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      AppSettings.instance.updateActiveSlides(slides);
      AppSettings.instance.activeSlideIndex = 0;
      
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FullscreenPresenterPage()),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hymn: $e'), backgroundColor: SacredColors.error),
        );
      }
    }
  }

  Future<void> _editHymn(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final content = await DefaultAssetBundle.of(context).loadString(widget.item.assetPath!);
      final slides = parseHymnToSlides(content, widget.item.title);
      
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      final String presentationId = widget.item.id;
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPage(
              presentationId: presentationId,
              initialSlides: slides,
              outlineText: content,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading hymn: $e'), backgroundColor: SacredColors.error),
        );
      }
    }
  }

  Future<void> _showContextMenu(BuildContext context, Offset globalPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final isSong = widget.item.category == 'Songs';
    final isMedia = widget.item.category == 'Media';
    final isPresentation = widget.item.category == 'Presentations';

    final result = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        if (isPresentation || isSong) ...[
          const PopupMenuItem<String>(
            value: 'play',
            child: Row(
              children: [
                Icon(Icons.play_arrow, size: 20),
                SizedBox(width: 8),
                Text('Go Live (Play)'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
        ],
        if (isMedia) ...[
          const PopupMenuItem<String>(
            value: 'preview',
            child: Row(
              children: [
                Icon(Icons.visibility, size: 20),
                SizedBox(width: 8),
                Text('Preview Media'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'copy_link',
            child: Row(
              children: [
                Icon(Icons.link, size: 20),
                SizedBox(width: 8),
                Text('Copy URL / Path'),
              ],
            ),
          ),
        ],
        if (isSong) ...[
          const PopupMenuItem<String>(
            value: 'copy_lyrics',
            child: Row(
              children: [
                Icon(Icons.copy, size: 20),
                SizedBox(width: 8),
                Text('Copy Lyrics'),
              ],
            ),
          ),
        ],
        if (isPresentation) ...[
          const PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.drive_file_rename_outline, size: 20),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'duplicate',
            child: Row(
              children: [
                Icon(Icons.copy, size: 20),
                SizedBox(width: 8),
                Text('Duplicate'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: SacredColors.error),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: SacredColors.error),
              ),
            ],
          ),
        ),
      ],
    );

    if (result == null) return;
    if (mounted) {
      _handleMenuAction(context, result);
    }
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'play':
        if (widget.item.category == 'Presentations') {
          final matches = AppSettings.instance.recentPresentations.where((p) => p.id == widget.item.id);
          if (matches.isNotEmpty) {
            final realPres = matches.first;
            AppSettings.instance.updateActiveSlides(realPres.slides);
            AppSettings.instance.activeSlideIndex = 0;
          } else {
            AppSettings.instance.updateActiveSlides(AppSettings.instance.activeSlides);
            AppSettings.instance.activeSlideIndex = 0;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FullscreenPresenterPage()),
          );
        } else if (widget.item.category == 'Songs' && widget.item.assetPath != null) {
          _playHymn(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FullscreenPresenterPage()),
          );
        }
        break;
      case 'edit':
        if (widget.item.category == 'Presentations') {
          final matches = AppSettings.instance.recentPresentations.where((p) => p.id == widget.item.id);
          if (matches.isNotEmpty) {
            final realPres = matches.first;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PreviewPage(
                  presentationId: realPres.id,
                  initialSlides: realPres.slides,
                  outlineText: realPres.outlineText,
                ),
              ),
            );
          } else {
            final String fallbackId = DateTime.now().millisecondsSinceEpoch.toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PreviewPage(
                  presentationId: fallbackId,
                ),
              ),
            );
          }
        } else if (widget.item.category == 'Songs' && widget.item.assetPath != null) {
          _editHymn(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Editing ${widget.item.title}...'),
              backgroundColor: widget.primaryColor,
            ),
          );
        }
        break;
      case 'rename':
        _showRenameDialog(context);
        break;
      case 'duplicate':
        if (widget.onDuplicate != null) {
          widget.onDuplicate!();
        }
        break;
      case 'delete':
        _showDeleteConfirmDialog(context);
        break;
      case 'preview':
        _showMediaPreview(context);
        break;
      case 'copy_link':
        _copyLink(context);
        break;
      case 'copy_lyrics':
        _copyLyrics(context);
        break;
    }
  }

  Future<void> _showDeleteConfirmDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${widget.item.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SacredColors.error,
              foregroundColor: SacredColors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      widget.onDelete!();
    }
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final textController = TextEditingController(text: widget.item.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Presentation'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty && widget.onRename != null) {
      widget.onRename!(newTitle.trim());
    }
  }

  void _showMediaPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: SacredColors.surface,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: SacredTypography.headlineMd(context).copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    color: Colors.black12,
                    child: widget.item.imageUrl.isNotEmpty
                        ? Image.network(
                            widget.item.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.item.metadata,
                    style: SacredTypography.bodyMd(context).copyWith(color: SacredColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    final link = widget.item.imageUrl.isNotEmpty ? widget.item.imageUrl : widget.item.assetPath ?? '';
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Asset path/URL copied to clipboard!'),
          backgroundColor: widget.primaryColor,
        ),
      );
    }
  }

  Future<void> _copyLyrics(BuildContext context) async {
    String lyrics = '';
    if (widget.item.assetPath != null) {
      try {
        lyrics = await DefaultAssetBundle.of(context).loadString(widget.item.assetPath!);
      } catch (e) {
        lyrics = 'Error loading lyrics: $e';
      }
    } else {
      if (widget.item.title.contains('Amazing Grace')) {
        lyrics = '''Amazing Grace, how sweet the sound,
That saved a wretch like me.
I once was lost, but now am found,
Was blind, but now I see.

'Twas grace that taught my heart to fear,
And grace my fears relieved.
How precious did that grace appear,
The hour I first believed.''';
      } else if (widget.item.title.contains('How Great Is Our God')) {
        lyrics = '''The splendor of the King, clothed in majesty,
Let all the earth rejoice, all the earth rejoice.
He wraps Himself in light, and darkness tries to hide,
And trembles at His voice, trembles at His voice.

How great is our God, sing with me,
How great is our God, all will see,
How great, how great is our God.''';
      } else {
        lyrics = '${widget.item.title}\nLyrics / scripture passage copy placeholder.';
      }
    }

    await Clipboard.setData(ClipboardData(text: lyrics));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lyrics copied to clipboard!'),
          backgroundColor: widget.primaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTextItem = widget.item.imageUrl.isEmpty;
    final bool isSong = widget.item.category == 'Songs';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
        onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSong ? Colors.black : SacredColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? widget.primaryColor.withValues(alpha: 0.5)
                : (isSong ? Colors.white24 : SacredColors.outlineVariant.withValues(alpha: 0.5)),
            width: 1.0,
          ),
          boxShadow: _isHovered ? SacredShadows.sacred : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Box
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isTextItem
                          ? Container(
                              color: isSong ? const Color(0xFF0F0F14) : SacredColors.surfaceContainerLow,
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.description_outlined, size: 40, color: isSong ? Colors.white60 : widget.primaryColor.withValues(alpha: 0.7)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'SCRIPTURE/SONG',
                                    style: SacredTypography.labelSm(context).copyWith(
                                      color: isSong ? Colors.white54 : SacredColors.outline,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: SacredColors.surfaceContainerLow),
                            ),
                    ),

                    // Hover Button Actions overlay
                    AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit presentation/lyrics
                              CircleAvatar(
                                backgroundColor: Colors.white,
                                child: IconButton(
                                  icon: Icon(Icons.edit, color: widget.primaryColor),
                                  onPressed: () {
                                    if (widget.item.category == 'Presentations') {
                                      final matches = AppSettings.instance.recentPresentations.where((p) => p.id == widget.item.id);
                                      if (matches.isNotEmpty) {
                                        final realPres = matches.first;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PreviewPage(
                                              presentationId: realPres.id,
                                              initialSlides: realPres.slides,
                                              outlineText: realPres.outlineText,
                                            ),
                                          ),
                                        );
                                      } else {
                                        final String fallbackId = DateTime.now().millisecondsSinceEpoch.toString();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PreviewPage(
                                              presentationId: fallbackId,
                                            ),
                                          ),
                                        );
                                      }
                                    } else if (widget.item.category == 'Songs' && widget.item.assetPath != null) {
                                      _editHymn(context);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Editing ${widget.item.title}...'),
                                          backgroundColor: widget.primaryColor,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Go Live / Project Fullscreen Presenter
                              CircleAvatar(
                                backgroundColor: SacredColors.secondaryContainer,
                                child: IconButton(
                                  icon: Icon(Icons.play_arrow, color: SacredColors.onSecondaryContainer),
                                  onPressed: () {
                                    if (widget.item.category == 'Presentations') {
                                      final matches = AppSettings.instance.recentPresentations.where((p) => p.id == widget.item.id);
                                      if (matches.isNotEmpty) {
                                        final realPres = matches.first;
                                        AppSettings.instance.updateActiveSlides(realPres.slides);
                                        AppSettings.instance.activeSlideIndex = 0;
                                      } else {
                                        // Default template
                                        AppSettings.instance.updateActiveSlides(AppSettings.instance.activeSlides);
                                        AppSettings.instance.activeSlideIndex = 0;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const FullscreenPresenterPage()),
                                      );
                                    } else if (widget.item.category == 'Songs' && widget.item.assetPath != null) {
                                      _playHymn(context);
                                    } else {
                                      // Fallback for mock items
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const FullscreenPresenterPage()),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tag Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.tag,
                          style: SacredTypography.labelSm(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Title and metadata Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: SacredTypography.bodyMd(context).copyWith(
                        color: isSong ? Colors.white : SacredColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.metadata,
                      style: SacredTypography.labelSm(context).copyWith(
                        color: isSong ? Colors.white70 : SacredColors.onSurfaceVariant,
                      ),
                    ),
                  ],
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
