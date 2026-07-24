// lib/outline_view.dart
// Song Outline View — primary lyrics editing interface
// PowerPoint-inspired collapsible section view with inline editing

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart'; // SacredColors, SacredTypography

/// Callback signature for when a section's raw lyrics change.
typedef SectionLyricsChangedCallback = void Function(String sectionId, String newLyrics);

/// Callback signature for section operations.
typedef SectionCallback = void Function(String sectionId);

/// The main Song Outline View widget — a full-height panel for editing
/// lyrics as a continuous document organized into collapsible sections.
class SongOutlineView extends StatefulWidget {
  final List<SlideSection> sections;
  final List<SlideData> slides;
  final int activeSlideIndex;
  final String? selectedSectionId;

  // Callbacks
  final SectionLyricsChangedCallback onSectionLyricsChanged;
  final ValueChanged<String?> onSelectedSectionChanged;
  final ValueChanged<int> onSlideSelected;
  final Function(String name) onAddSection;
  final Function(String id, String newName) onRenameSection;
  final SectionCallback onDeleteSection;
  final Function(int fromIndex, int toIndex) onMoveSection;
  final Function(String id)? onDuplicateSection;
  final Function(String sectionId, bool locked) onLockChanged;
  final Function(String sectionId, String? notes) onNotesChanged;
  final Function(String sectionId, int? colorValue) onColorChanged;
  final Function(String sectionId, bool collapsed) onCollapseChanged;

  const SongOutlineView({
    super.key,
    required this.sections,
    required this.slides,
    required this.activeSlideIndex,
    required this.selectedSectionId,
    required this.onSectionLyricsChanged,
    required this.onSelectedSectionChanged,
    required this.onSlideSelected,
    required this.onAddSection,
    required this.onRenameSection,
    required this.onDeleteSection,
    required this.onMoveSection,
    this.onDuplicateSection,
    required this.onLockChanged,
    required this.onNotesChanged,
    required this.onColorChanged,
    required this.onCollapseChanged,
  });

  @override
  State<SongOutlineView> createState() => _SongOutlineViewState();
}

class _SongOutlineViewState extends State<SongOutlineView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showSearch = false;

  // Track which section's lyrics editor has focus
  String? _focusedSectionId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (_showSearch) {
        _searchFocusNode.requestFocus();
      } else {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  bool _sectionMatchesSearch(SlideSection section) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    if (section.name.toLowerCase().contains(query)) return true;
    if (section.rawLyrics?.toLowerCase().contains(query) ?? false) return true;
    if (section.notes?.toLowerCase().contains(query) ?? false) return true;
    return false;
  }

  void _handleSectionReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    widget.onMoveSection(oldIndex, newIndex);
  }

  void _addNewSection(String type) {
    final typeNames = {
      'verse': 'VERSE ${_countSectionType(SectionType.verse) + 1}',
      'chorus': 'CHORUS',
      'bridge': 'BRIDGE',
      'pre_chorus': 'PRE-CHORUS',
      'intro': 'INTRO',
      'outro': 'OUTRO',
      'coda': 'CODA',
      'medley': 'MEDLEY',
      'tag': 'TAG',
    };
    widget.onAddSection(typeNames[type] ?? 'VERSE ${_countSectionType(SectionType.verse) + 1}');
  }

  int _countSectionType(SectionType type) {
    return widget.sections.where((s) => s.sectionType == type).length;
  }

  /// Get the section that the current active slide belongs to
  String? _getActiveSlideSectionId() {
    if (widget.slides.isEmpty || widget.activeSlideIndex >= widget.slides.length) return null;
    final activeSlide = widget.slides[widget.activeSlideIndex];
    return activeSlide.sectionId;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSlideSectionId = _getActiveSlideSectionId();

    // Filter sections by search
    final filteredSections = widget.sections.where(_sectionMatchesSearch).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : SacredColors.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : SacredColors.outlineVariant,
          ),
        ),
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // Ctrl+F to toggle search
            if (event.logicalKey == LogicalKeyboardKey.keyF &&
                HardwareKeyboard.instance.isControlPressed) {
              _toggleSearch();
              return KeyEventResult.handled;
            }
            // Ctrl+Shift+V — new verse
            if (event.logicalKey == LogicalKeyboardKey.keyV &&
                HardwareKeyboard.instance.isControlPressed &&
                HardwareKeyboard.instance.isShiftPressed) {
              _addNewSection('verse');
              return KeyEventResult.handled;
            }
            // Ctrl+Shift+C — new chorus
            if (event.logicalKey == LogicalKeyboardKey.keyC &&
                HardwareKeyboard.instance.isControlPressed &&
                HardwareKeyboard.instance.isShiftPressed) {
              _addNewSection('chorus');
              return KeyEventResult.handled;
            }
            // Ctrl+Shift+B — new bridge
            if (event.logicalKey == LogicalKeyboardKey.keyB &&
                HardwareKeyboard.instance.isControlPressed &&
                HardwareKeyboard.instance.isShiftPressed) {
              _addNewSection('bridge');
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Search Bar
            if (_showSearch) _buildSearchBar(isDark),

            // Section List
            Expanded(
              child: filteredSections.isEmpty
                  ? _buildEmptyState(isDark)
                  : ReorderableListView.builder(
                      scrollController: _scrollController,
                      buildDefaultDragHandles: false,
                      itemCount: filteredSections.length,
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final elevation = lerpDouble(0, 8, animation.value) ?? 0;
                            return Material(
                              elevation: elevation,
                              color: Colors.transparent,
                              shadowColor: Colors.black26,
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      onReorder: _handleSectionReorder,
                      itemBuilder: (context, index) {
                        final section = filteredSections[index];
                        final isActive = section.id == widget.selectedSectionId ||
                            section.id == activeSlideSectionId;

                        return _OutlineSectionCard(
                          key: ValueKey(section.id),
                          section: section,
                          slides: widget.slides.where((s) => section.slideIds.contains(s.id)).toList(),
                          isActive: isActive,
                          isFocused: _focusedSectionId == section.id,
                          searchQuery: _searchQuery,
                          sectionIndex: widget.sections.indexOf(section),
                          totalSections: widget.sections.length,
                          onLyricsChanged: (newLyrics) {
                            widget.onSectionLyricsChanged(section.id, newLyrics);
                          },
                          onTap: () {
                            widget.onSelectedSectionChanged(section.id);
                            // Select the first slide in this section
                            if (section.slideIds.isNotEmpty) {
                              final firstSlideIdx = widget.slides.indexWhere(
                                (s) => s.id == section.slideIds.first,
                              );
                              if (firstSlideIdx >= 0) {
                                widget.onSlideSelected(firstSlideIdx);
                              }
                            }
                          },
                          onFocusChanged: (focused) {
                            setState(() {
                              _focusedSectionId = focused ? section.id : null;
                            });
                          },
                          onRename: (newName) => widget.onRenameSection(section.id, newName),
                          onDelete: () => widget.onDeleteSection(section.id),
                          onDuplicate: widget.onDuplicateSection != null
                              ? () => widget.onDuplicateSection!(section.id)
                              : null,
                          onMoveUp: index > 0
                              ? () => widget.onMoveSection(
                                    widget.sections.indexOf(section),
                                    widget.sections.indexOf(section) - 1,
                                  )
                              : null,
                          onMoveDown: index < filteredSections.length - 1
                              ? () => widget.onMoveSection(
                                    widget.sections.indexOf(section),
                                    widget.sections.indexOf(section) + 2,
                                  )
                              : null,
                          onLockChanged: (locked) => widget.onLockChanged(section.id, locked),
                          onNotesChanged: (notes) => widget.onNotesChanged(section.id, notes),
                          onColorChanged: (color) => widget.onColorChanged(section.id, color),
                          onCollapseChanged: (collapsed) =>
                              widget.onCollapseChanged(section.id, collapsed),
                          dragIndex: index,
                        );
                      },
                    ),
            ),

            // Bottom Action Bar
            _buildBottomBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : SacredColors.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 18,
            color: isDark ? Colors.white70 : SacredColors.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Song Outline',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? Colors.white : SacredColors.onSurface,
                letterSpacing: 0.3,
              ),
            ),
          ),
          _HeaderIconButton(
            icon: Icons.search,
            tooltip: 'Search (Ctrl+F)',
            isActive: _showSearch,
            onPressed: _toggleSearch,
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.unfold_less,
            tooltip: 'Collapse All',
            onPressed: () {
              for (final s in widget.sections) {
                widget.onCollapseChanged(s.id, true);
              }
            },
            isDark: isDark,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            icon: Icons.unfold_more,
            tooltip: 'Expand All',
            onPressed: () {
              for (final s in widget.sections) {
                widget.onCollapseChanged(s.id, false);
              }
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A45) : const Color(0xFFF5F5F8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : SacredColors.outlineVariant,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white : SacredColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search lyrics, sections, notes...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E30) : Colors.white,
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
          // Auto-expand sections that match
          if (val.isNotEmpty) {
            for (final section in widget.sections) {
              if (_sectionMatchesSearch(section) && section.isCollapsed) {
                widget.onCollapseChanged(section.id, false);
              }
            }
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 48,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No matching sections' : 'No sections yet',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Add a section to start writing lyrics',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252540) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.06) : SacredColors.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: _addNewSection,
              offset: const Offset(0, -200),
              itemBuilder: (context) => [
                _sectionMenuItem('verse', 'Verse', Icons.text_snippet_outlined, SectionType.verse),
                _sectionMenuItem('chorus', 'Chorus', Icons.music_note, SectionType.chorus),
                _sectionMenuItem('bridge', 'Bridge', Icons.swap_horiz, SectionType.bridge),
                _sectionMenuItem('pre_chorus', 'Pre-Chorus', Icons.fast_forward, SectionType.preChorus),
                const PopupMenuDivider(),
                _sectionMenuItem('intro', 'Intro', Icons.play_arrow, SectionType.intro),
                _sectionMenuItem('outro', 'Outro', Icons.stop, SectionType.outro),
                _sectionMenuItem('coda', 'Coda', Icons.repeat_one, SectionType.coda),
                _sectionMenuItem('medley', 'Medley', Icons.playlist_play, SectionType.medley),
                _sectionMenuItem('tag', 'Tag', Icons.label_outline, SectionType.tag),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: isDark ? Colors.white70 : SacredColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Add Section',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : SacredColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.sections.length} sections',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white30 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sectionMenuItem(
    String value,
    String label,
    IconData icon,
    SectionType type,
  ) {
    final color = getSectionColor(type, isDarkMode: Theme.of(context).brightness == Brightness.dark);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
        ],
      ),
    );
  }
}

double? lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

// ─── Header Icon Button ────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isActive;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? Colors.white.withOpacity(0.12) : SacredColors.primary.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive
                ? (isDark ? Colors.white : SacredColors.primary)
                : (isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}

// ─── Outline Section Card ──────────────────────────────────────────────────

class _OutlineSectionCard extends StatefulWidget {
  final SlideSection section;
  final List<SlideData> slides;
  final bool isActive;
  final bool isFocused;
  final String searchQuery;
  final int sectionIndex;
  final int totalSections;
  final int dragIndex;
  final ValueChanged<String> onLyricsChanged;
  final VoidCallback onTap;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<bool> onLockChanged;
  final ValueChanged<String?> onNotesChanged;
  final ValueChanged<int?> onColorChanged;
  final ValueChanged<bool> onCollapseChanged;

  const _OutlineSectionCard({
    super.key,
    required this.section,
    required this.slides,
    required this.isActive,
    required this.isFocused,
    required this.searchQuery,
    required this.sectionIndex,
    required this.totalSections,
    required this.dragIndex,
    required this.onLyricsChanged,
    required this.onTap,
    required this.onFocusChanged,
    required this.onRename,
    required this.onDelete,
    this.onDuplicate,
    this.onMoveUp,
    this.onMoveDown,
    required this.onLockChanged,
    required this.onNotesChanged,
    required this.onColorChanged,
    required this.onCollapseChanged,
  });

  @override
  State<_OutlineSectionCard> createState() => _OutlineSectionCardState();
}

class _OutlineSectionCardState extends State<_OutlineSectionCard> {
  late TextEditingController _lyricsController;
  final FocusNode _lyricsFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _lyricsController = TextEditingController(text: widget.section.rawLyrics ?? '');
    _lyricsFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _OutlineSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update text if the section's lyrics changed externally (not while editing)
    if (!_lyricsFocusNode.hasFocus &&
        widget.section.rawLyrics != oldWidget.section.rawLyrics) {
      _lyricsController.text = widget.section.rawLyrics ?? '';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _lyricsFocusNode.removeListener(_onFocusChange);
    _lyricsFocusNode.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged(_lyricsFocusNode.hasFocus);
    if (_lyricsFocusNode.hasFocus) {
      widget.onTap();
    }
  }

  void _onLyricsChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      widget.onLyricsChanged(value);
    });
  }

  void _handleSpecialInput(String value) {
    // Check for markdown shortcuts
    final lines = value.split('\n');
    if (lines.isNotEmpty) {
      final lastLine = lines.last.trim();

      // # Header creates a new section
      if (lastLine.startsWith('# ') && lastLine.length > 2) {
        final sectionName = lastLine.substring(2).trim().toUpperCase();
        // Remove the # line from current lyrics
        lines.removeLast();
        _lyricsController.text = lines.join('\n');
        widget.onLyricsChanged(_lyricsController.text);
        // Create new section
        widget.onRename(widget.section.name); // keep current
        // This would need to call onAddSection — handled by parent
      }

      // === creates a new section break
      if (lastLine == '===') {
        lines.removeLast();
        _lyricsController.text = lines.join('\n');
        widget.onLyricsChanged(_lyricsController.text);
      }
    }

    _onLyricsChanged(value);
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(value: 'rename', child: _ContextMenuItem(icon: Icons.edit, label: 'Rename Section')),
        PopupMenuItem(value: 'move_up', enabled: widget.onMoveUp != null, child: const _ContextMenuItem(icon: Icons.arrow_upward, label: 'Move Up')),
        PopupMenuItem(value: 'move_down', enabled: widget.onMoveDown != null, child: const _ContextMenuItem(icon: Icons.arrow_downward, label: 'Move Down')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'lock',
          child: _ContextMenuItem(
            icon: widget.section.locked ? Icons.lock_open : Icons.lock,
            label: widget.section.locked ? 'Unlock Section' : 'Lock Section',
          ),
        ),
        if (widget.onDuplicate != null)
          const PopupMenuItem(value: 'duplicate', child: _ContextMenuItem(icon: Icons.content_copy, label: 'Duplicate')),
        const PopupMenuItem(value: 'notes', child: _ContextMenuItem(icon: Icons.note_add, label: 'Edit Notes')),
        const PopupMenuItem(value: 'color', child: _ContextMenuItem(icon: Icons.palette_outlined, label: 'Section Color')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _ContextMenuItem(icon: Icons.delete_outline, label: 'Delete Section', isDestructive: true),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'rename':
          _showRenameDialog();
          break;
        case 'move_up':
          widget.onMoveUp?.call();
          break;
        case 'move_down':
          widget.onMoveDown?.call();
          break;
        case 'lock':
          widget.onLockChanged(!widget.section.locked);
          break;
        case 'duplicate':
          widget.onDuplicate?.call();
          break;
        case 'notes':
          _showNotesDialog();
          break;
        case 'color':
          _showColorDialog();
          break;
        case 'delete':
          widget.onDelete();
          break;
      }
    });
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.section.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Section name'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              widget.onRename(val.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.onRename(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog() {
    final controller = TextEditingController(text: widget.section.notes ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notes — ${widget.section.name}'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Add notes for this section...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.onNotesChanged(controller.text.isEmpty ? null : controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorDialog() {
    final colors = [
      Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
      Colors.indigo, Colors.blue, Colors.cyan, Colors.teal,
      Colors.green, Colors.orange, Colors.deepOrange, Colors.brown,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Section Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Clear color option
            GestureDetector(
              onTap: () {
                widget.onColorChanged(null);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(Icons.clear, size: 16, color: Colors.grey),
              ),
            ),
            ...colors.map((c) => GestureDetector(
                  onTap: () {
                    widget.onColorChanged(c.value);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: widget.section.colorValue == c.value
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionType = widget.section.sectionType;
    final accentColor = widget.section.colorValue != null && widget.section.colorValue != 0
        ? Color(widget.section.colorValue!)
        : getSectionColor(sectionType, isDarkMode: isDark);

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: widget.isActive
              ? (isDark ? accentColor.withOpacity(0.08) : accentColor.withOpacity(0.04))
              : (isDark ? const Color(0xFF252540) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isActive
                ? accentColor.withOpacity(0.4)
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.15)),
            width: widget.isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Header
            _buildSectionHeader(isDark, accentColor),

            // Lyrics Editor (when expanded)
            if (!widget.section.isCollapsed)
              _buildLyricsEditor(isDark, accentColor),

            // Slide count indicator
            if (!widget.section.isCollapsed && widget.slides.isNotEmpty)
              _buildSlideIndicator(isDark, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, Color accentColor) {
    return ReorderableDragStartListener(
      index: widget.dragIndex,
      child: InkWell(
        onTap: () {
          widget.onCollapseChanged(!widget.section.isCollapsed);
        },
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(isDark ? 0.12 : 0.06),
            borderRadius: widget.section.isCollapsed
                ? BorderRadius.circular(8)
                : const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              // Color indicator bar
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              // Collapse/Expand icon
              AnimatedRotation(
                turns: widget.section.isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 6),
              // Section name
              Expanded(
                child: Text(
                  widget.section.name,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Lock icon
              if (widget.section.locked)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.lock, size: 13, color: accentColor.withOpacity(0.6)),
                ),
              // Notes indicator
              if (widget.section.notes != null && widget.section.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.sticky_note_2_outlined, size: 13, color: accentColor.withOpacity(0.6)),
                ),
              // Slide count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.slides.length}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
              // Drag handle
              const SizedBox(width: 4),
              Icon(Icons.drag_indicator, size: 14, color: isDark ? Colors.white24 : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsEditor(bool isDark, Color accentColor) {
    final isLocked = widget.section.locked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _lyricsController,
        focusNode: _lyricsFocusNode,
        readOnly: isLocked,
        maxLines: null,
        minLines: 2,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          height: 1.7,
          color: isDark
              ? (isLocked ? Colors.white38 : Colors.white.withOpacity(0.85))
              : (isLocked ? Colors.grey[400] : SacredColors.onSurface),
        ),
        decoration: InputDecoration(
          hintText: isLocked ? '(Locked)' : 'Type lyrics here...',
          hintStyle: GoogleFonts.inter(
            fontSize: 12.5,
            color: isDark ? Colors.white24 : Colors.grey[400],
            fontStyle: FontStyle.italic,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: _handleSpecialInput,
      ),
    );
  }

  Widget _buildSlideIndicator(bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 12,
            color: isDark ? Colors.white30 : Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.slides.length} slide${widget.slides.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.white30 : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Context Menu Item ─────────────────────────────────────────────────────

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : null;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}
