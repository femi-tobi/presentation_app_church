// lib/templates_page.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Reuse SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'create_presentation_page.dart';
import 'connectivity_badge.dart';

class TemplatesPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const TemplatesPage({super.key, this.scaffoldKey});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Template items metadata
  final List<TemplateItem> _allTemplates = [
    TemplateItem(
      id: '1',
      title: 'Majesty & Grace',
      category: 'Worship',
      slidesCount: 24,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD2L84Pq8Z59RpiwrMNMK28qM3sgfruhio-_Fkw4zNUvh_NpDBd7WleYrj5ty3pZNtwfdhQFIz_A9UYHqrHumR9oCxyjrGbn2PX7pxi8-db6tTO0DRK4YHokxPs2y6NrEdb_yHChie_8Oq3surzlOeVc4Fv4gpErKWu-YD3WHeUEZL0Rw4v0JXnajt1QDfczasOvswikAOlnZVm6In7VO6SXz-ysrs5ErEwOtebhUdy_Cz3FN2OUgrusIanPqYkCwpfRyMYNnfgbYzn',
      isStarred: true,
      isLarge: true,
      imageAlt: 'Gothic cathedral interior with stained glass windows.',
    ),
    TemplateItem(
      id: '2',
      title: 'Vesper Light',
      category: 'Worship',
      slidesCount: 12,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCf-Nbj2rzl3QIjt1VvBtG0FVy2CWxawbXT4BEyB74cLe35XNYfVWsfW2k15mi0GUxj47-VLk5AN5v2Kk417mZcTAUEmgAVWLBXsqOnaXn7y6Jjas9lvUw9IrWyHfLehMVZc9vcaNTN_PUl5vdBmGLgbbR0ZTx6j9popK0L7bZwOjKOzjRC57eL3M68TdRB2OiEGJJ7W0iYyiEjfQXROrdeuHZlUt8oEi1lXE_IwZZAyel1jSg8aJZzk1cOOcajwPLsRXIko6YECagM',
      isStarred: false,
      isLarge: false,
      imageAlt: 'White candles burning peacefully.',
    ),
    TemplateItem(
      id: '3',
      title: 'Mountaintop Faith',
      category: 'Sermon',
      slidesCount: 18,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCumon3BIQr8XsjUfowXviKZtMn0KVb9EydsoiVZHonb6-GF8pl4K_RrBwC5ln8WSFxo4njMWz5T2e-BVtiB4NakOZxUkDnT90H5lMNzJsKwx9R12UqE-LSsk6_qh1BcsX2yTYqNTP_kTWZccLTPVeyZhbqzYzlShOkhRbJCXALcFiaoAaIp6dlIv0h9_9AjdaovAgK5n3Xl3VE58Sg_AmACbmdoF77qrNioe7-JdoZy8UkNFlyvceOXql9Hwiek_WPE6PwAL5Q2KnE',
      isStarred: false,
      isLarge: false,
      imageAlt: 'Mountain sunrise skyline.',
    ),
    TemplateItem(
      id: '4',
      title: 'Sacred Echoes',
      category: 'Announcements',
      slidesCount: 30,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD1bA9eQT9bajGyyO-j-hVb5m26vKrO-YP4bsYGBwq_5v5maZKYDH0SSjnSowyTBFUZJXwR8s6FGnujiXbR6ViLPNfuGcH2BzDrpzW05nHe3Qp3Ti-g9uIgikA0F4Uskb5aQn4HBYkTO4nB64P2Dfn2pNGWMnu0n9GJQmUZ67dG3M10kZ1srpXRPOObZDWMTS3FCh47Ptiv1lr3xEpPMnoNKuoLN9NnSiSv8N8Kp5ZPhGWVqreyTUht-NdkiVcIOL9jeySh3BrtL33J',
      isStarred: false,
      isLarge: false,
      imageAlt: 'Abstract light shapes gold and purple.',
    ),
    TemplateItem(
      id: '5',
      title: 'Scripture & Stone',
      category: 'Sermon',
      slidesCount: 15,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBzb8gnM0emBrWgcLhlnclxSKH9P2PON_t2313bGbnfztkWQ_E2LrX12mYUqMJfYiPqSheBnMGr5Wudsbd-42hFwFuNQcQc_FsJUGXaY9zCMRorqXtuL07SwZqi4iESgKuPQGRkXMEGV1qDxWkmz45X0Yss_Sjic7a1--ZmAtIhTMcAaCRAuGwd0aP1HDJLQSQ2iu2gqqBjaVeRo4pgGNmUA2rEhMhp4Fm_jyWvfJJmktPn7oJ3ty9zqQ3Li78EPGlFXwEZkkr2q_Lz',
      isStarred: false,
      isLarge: false,
      imageAlt: 'Minimalist layout with ancient book.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final isDarkMode = AppSettings.instance.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

    // Filtered list
    final filteredTemplates = _allTemplates.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
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
        body: Column(
          children: [
            // Top Nav bar
            _TopNavBar(
              scaffoldKey: widget.scaffoldKey,
              onSearchChanged: (query) => setState(() => _searchQuery = query),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Header and Filters
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Template Gallery',
                                    style: SacredTypography.headlineLg(context).copyWith(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 600),
                                    child: Text(
                                      'Find inspiration for your next service with our curated collection of professional church presentation designs.',
                                      style: SacredTypography.bodyMd(context).copyWith(
                                        color: SacredColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            _CategoryFilter(
                              selectedCategory: _selectedCategory,
                              onSelect: (cat) => setState(() => _selectedCategory = cat),
                              primaryColor: primaryColor,
                            ),
                          ],
                        ),
                        SizedBox(height: 40),

                        // Bento Grid
                        _BentoGrid(
                          templates: filteredTemplates,
                          isDesktop: isDesktop,
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
    );
  }
}

// ------------------------ Top Navigation ------------------------
class _TopNavBar extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const _TopNavBar({
    required this.onSearchChanged,
    this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(bottom: BorderSide(color: SacredColors.outlineVariant, width: 1)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop && scaffoldKey != null) ...[
                IconButton(
                  icon: Icon(Icons.menu, color: SacredColors.onSurface),
                  onPressed: () => scaffoldKey?.currentState?.openDrawer(),
                ),
                SizedBox(width: 8),
              ],
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: SacredColors.outline, size: 20),
                    hintText: 'Search templates...',
                    hintStyle: SacredTypography.bodyMd(context).copyWith(color: SacredColors.outline),
                    filled: true,
                    fillColor: SacredColors.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              ConnectivityBadge(),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.notifications_none, color: SacredColors.onSurfaceVariant),
                onPressed: () {},
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreatePresentationPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SacredColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('New Project'),
              ),
              SizedBox(width: 12),
              ClipOval(
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBwh3vonid1ngAi51NslYCK98ch_Ru6XAmw8Jxa4IWPRoat5H6ZbIJUiBont_TIFbOZgF6OJ53PIGZ0_NHSrYOM5EFIYzJXflm5Q5NL8Zyh5qu-OWVeuFWl_XxCfM5VBQWQFvDSHGOh0zJOwfLf-4OcxJfvwU-5SXB1NLgphx6a-3Xc3rR0YhQm2I5gMzPXIzZB_OVDoSEMJMANwl8tbhcWKDSBAFacGr1butev-yNpdl1k5vcXjSNsj249FSUfb79QVrbCpn_p9vZy',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: SacredColors.outlineVariant,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.person, size: 18),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------ Category Filter ------------------------
class _CategoryFilter extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelect;
  final Color primaryColor;

  const _CategoryFilter({
    required this.selectedCategory,
    required this.onSelect,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Worship', 'Sermon', 'Announcements'];

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SacredColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: categories.map((cat) {
          final isSelected = cat == selectedCategory;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                cat,
                style: SacredTypography.labelLg(context).copyWith(
                  color: isSelected ? primaryColor : SacredColors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ------------------------ Bento Grid Layout ------------------------
class _BentoGrid extends StatelessWidget {
  final List<TemplateItem> templates;
  final bool isDesktop;

  const _BentoGrid({
    required this.templates,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Text(
          'No templates found matching your filter.',
          style: SacredTypography.bodyLg(context).copyWith(color: SacredColors.outline),
        ),
      );
    }

    if (!isDesktop) {
      // Small screens: clean vertical stack
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: templates.length,
        separatorBuilder: (context, index) => SizedBox(height: 24),
        itemBuilder: (context, idx) {
          return _TemplateCard(item: templates[idx], isLarge: false);
        },
      );
    }

    // Desktop Bento layout
    // Majesty & Grace (Large) + Vesper Light (Small) in row 1
    // Mountaintop, Sacred Echoes, Scripture & Stone in row 2
    final largeItem = templates.firstWhere((t) => t.isLarge, orElse: () => templates.first);
    final otherItems = templates.where((t) => t.id != largeItem.id).toList();

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _TemplateCard(item: largeItem, isLarge: true),
            ),
            SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: otherItems.isNotEmpty
                  ? _TemplateCard(item: otherItems[0], isLarge: false)
                  : SizedBox(),
            ),
          ],
        ),
        if (otherItems.length > 1) ...[
          SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 1; i < otherItems.length && i < 4; i++) ...[
                Expanded(
                  child: _TemplateCard(item: otherItems[i], isLarge: false),
                ),
                if (i < otherItems.length - 1 && i < 3) SizedBox(width: 24),
              ]
            ],
          ),
        ],
      ],
    );
  }
}

// ------------------------ Template Card ------------------------
class _TemplateCard extends StatefulWidget {
  final TemplateItem item;
  final bool isLarge;

  const _TemplateCard({
    required this.item,
    required this.isLarge,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double cardHeight = widget.isLarge ? 380.0 : 250.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected template: ${widget.item.title}'),
              backgroundColor: AppSettings.instance.primaryColor,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -6.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            color: SacredColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? AppSettings.instance.primaryColor.withValues(alpha: 0.5)
                  : SacredColors.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppSettings.instance.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image container with hover overlay
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: cardHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: _isHovered ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutQuad,
                          child: Image.network(
                            widget.item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: SacredColors.surfaceContainerLow,
                                child: Icon(Icons.broken_image, size: 48, color: SacredColors.outline),
                              );
                            },
                          ),
                        ),
                      ),

                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppSettings.instance.primaryColor.withValues(alpha: _isHovered ? 0.8 : 0.4),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Hover Button
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Center(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFED65B),
                                foregroundColor: const Color(0xFF241A00),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                elevation: 8,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Loading ${widget.item.title} into your canvas...'),
                                    backgroundColor: AppSettings.instance.primaryColor,
                                  ),
                                );
                              },
                              child: Text(
                                'Use Template',
                                style: SacredTypography.labelLg(context).copyWith(
                                  color: const Color(0xFF241A00),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title Card Details
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            style: SacredTypography.headlineMd(context).copyWith(
                              color: AppSettings.instance.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${widget.item.category} Series • ${widget.item.slidesCount} Slides',
                            style: SacredTypography.labelSm(context).copyWith(
                              color: SacredColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.item.isStarred)
                      Icon(
                        Icons.star,
                        color: AppSettings.instance.primaryColor,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------ Template Metamodel ------------------------
class TemplateItem {
  final String id;
  final String title;
  final String category;
  final int slidesCount;
  final String imageUrl;
  final bool isStarred;
  final bool isLarge;
  final String imageAlt;

  TemplateItem({
    required this.id,
    required this.title,
    required this.category,
    required this.slidesCount,
    required this.imageUrl,
    required this.isStarred,
    required this.isLarge,
    required this.imageAlt,
  });
}
