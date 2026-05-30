import 'dart:math' as math;
import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // reuse SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'connectivity_badge.dart';
import 'pptx_generator.dart';
import 'create_presentation_page.dart';
import 'fullscreen_presenter_page.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage>
    with SingleTickerProviderStateMixin {
  // Toast slide-in animation
  late AnimationController _toastController;
  late Animation<Offset> _toastOffset;

  // Download button state machine
  _DownloadState _downloadState = _DownloadState.idle;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _toastOffset = Tween<Offset>(
      begin: const Offset(0, 3), // slide in from below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOut,
    ));

    // Trigger toast after 800ms then hide after 5s
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _toastController.forward();
    });
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) _toastController.reverse();
    });
  }

  @override
  void dispose() {
    _toastController.dispose();
    super.dispose();
  }

  void _onDownload() async {
    if (_downloadState != _DownloadState.idle) return;

    setState(() => _downloadState = _DownloadState.preparing);

    // Small delay for UX feedback
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Build slide list from AppSettings (the current active presentation)
    final activeSlides = AppSettings.instance.activeSlides;
    final slides = activeSlides
        .map((s) => (
              title: s.title,
              subtitle: s.subtitle,
              titleFontSize: s.titleFontSize,
              subtitleFontSize: s.subtitleFontSize,
              logoUrl: s.logoUrl,
              logoX: s.logoX,
              logoY: s.logoY,
              logoSize: s.logoSize,
              textX: s.textX,
              textY: s.textY,
              bgColorValue: s.bgColorValue,
            ))
        .toList();

    // Get the shared background image URL (all slides use the same one)
    final String? bgImageUrl =
        activeSlides.isNotEmpty ? activeSlides.first.imageUrl : null;

    // Generate & trigger download (save dialog on desktop, browser download on web)
    await PptxGenerator.downloadPptx(
      slides,
      'LiveDeck_Presentation',
      backgroundImageUrl: bgImageUrl,
      fontFamily: AppSettings.instance.fontFamily,
    );

    setState(() => _downloadState = _DownloadState.done);
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _downloadState = _DownloadState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

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
        body: SafeArea(
          child: Column(
            children: [
              _ExportNavBar(),
              Expanded(
                child: Row(
                  children: [
                    if (isDesktop) _ExportSidebar(),
                    Expanded(
                      child: Stack(
                        children: [
                          // Subtle dot-grid background pattern
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DotGridPainter(),
                            ),
                          ),

                          // Center Export Modal Card
                          Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(24.0),
                              child: _ExportModalCard(
                                downloadState: _downloadState,
                                onDownload: _onDownload,
                                onBackToEditor: () => Navigator.pop(context),
                              ),
                            ),
                          ),

                          // Floating animated toast notification
                          Positioned(
                            bottom: 40,
                            right: 40,
                            child: SlideTransition(
                              position: _toastOffset,
                              child: const _SuccessToast(),
                            ),
                          ),
                        ],
                      ),
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

enum _DownloadState { idle, preparing, done }

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ExportNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: SacredColors.outlineVariant, width: 1.0),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardPage(initialTab: 'Dashboard'),
                ),
                (route) => false,
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Live Deck',
                style: SacredTypography.headlineMd(context).copyWith(
                  color: SacredColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Row(
            children: [
              ConnectivityBadge(),
              IconButton(
                icon: Icon(Icons.notifications_none,
                    color: SacredColors.onSurfaceVariant),
                onPressed: () {},
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePresentationPage(),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: SacredColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'New Project',
                      style: SacredTypography.labelLg(context).copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: SacredColors.outlineVariant, width: 1),
                  image: const DecorationImage(
                    image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuDPZhVplp3MbAcTyjAvS7XRVBpniYPeKkJK8k4e-52uheaoJyHfn-MW7EWZIb6OIrb35mA2mf5zyXsoWn2PSuBoz6hK53g7gXW08dnGsHpSSEKBBIv5KiXe-NbyMjgvslUqqyHPVjyOZvy-80awanhnTQoSuvHz0T20nt2RWS1CC3Itgxe1c69ryEMMrftizT38b7UF5-0RnGMyOlSH068doHEb8OLGHqyHl973KoJOI76mD0t4k3nJ-Um9U3VG0klpKR_1MQykFI15'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar (same structure as Dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class _ExportSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.library_books_outlined, Icons.library_books, 'Library'),
      (Icons.layers_outlined, Icons.layers, 'Templates'),
      (Icons.settings_outlined, Icons.settings, 'Settings'),
    ];

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: Border(
            right: BorderSide(color: SacredColors.outlineVariant, width: 1.0)),
      ),
      child: Column(
        children: [
          SizedBox(height: 40),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: items.map((item) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardPage(initialTab: item.$3),
                          ),
                          (route) => false,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(item.$1,
                                color: SacredColors.onSurfaceVariant, size: 22),
                            SizedBox(width: 16),
                            Text(
                              item.$3,
                              style: SacredTypography.labelLg(context).copyWith(
                                  color: SacredColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: SacredColors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: SacredShadows.sacred,
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullscreenPresenterPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors,
                        color: SacredColors.onSecondaryContainer, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Go Live',
                      style: SacredTypography.labelLg(context)
                          .copyWith(color: SacredColors.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export Modal Card
// ─────────────────────────────────────────────────────────────────────────────

class _ExportModalCard extends StatelessWidget {
  final _DownloadState downloadState;
  final VoidCallback onDownload;
  final VoidCallback onBackToEditor;

  const _ExportModalCard({
    required this.downloadState,
    required this.onDownload,
    required this.onBackToEditor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = MediaQuery.of(context).size.width < 900;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          decoration: BoxDecoration(
            color: SacredColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: const Color(0xFFE5E7EB).withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  children: [
                    _PreviewPane(),
                    _ExportOptionsPane(
                      downloadState: downloadState,
                      onDownload: onDownload,
                      onBackToEditor: onBackToEditor,
                    ),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PreviewPane()),
                      Container(
                          width: 1, color: SacredColors.outlineVariant),
                      Expanded(
                        child: _ExportOptionsPane(
                          downloadState: downloadState,
                          onDownload: onDownload,
                          onBackToEditor: onBackToEditor,
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

// ─────────────────────────────────────────────────────────────────────────────
// Left pane: Slide preview + offline badge
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewPane extends StatefulWidget {
  @override
  State<_PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<_PreviewPane> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SacredColors.surfaceContainerLow,
      padding: EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 16:9 slide preview image card
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuBSqdi1qbzgFE3_74no2iSRp5dGizyN_7vRGhDm3sHeaxTFc7GP-oSx3Aj2lQGWL-8Rpw8VLQqAZdQtt8AKFs4VECAdB3DXyqre06HbeZjwoeAnrrr_JH3jxYY62csjXMwiumBOG8Qek2nCcrO0-iSkLlnERxuTtXfAHJMgQdHU7ejgMiYE47c59mHnnWRrZ0ArDhzX_loKAFjdwNpjH8X9_Gf4zFliCxjn_qqoJd8N8GlyIc6NGOvFcpYG6jTLmKtWqeGqkoQCQR1j',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: SacredColors.surfaceContainerHigh,
                          child: Icon(Icons.image,
                              size: 48, color: SacredColors.primary),
                        ),
                      ),
                    ),

                    // hover overlay
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: SacredColors.primary.withValues(alpha: 0.20),
                          alignment: Alignment.center,
                          child: Icon(Icons.visibility,
                              size: 48, color: Colors.white),
                        ),
                      ),
                    ),

                    // border overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: SacredColors.outlineVariant, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 28),

          // Offline sync badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_pin,
                  color: SacredColors.tertiary, size: 20),
              SizedBox(width: 8),
              Text(
                'Offline Sync Complete',
                style: SacredTypography.labelLg(context)
                    .copyWith(color: SacredColors.onSurfaceVariant),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Safely stored in local cache',
            style: SacredTypography.labelSm(context)
                .copyWith(color: SacredColors.outline),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right pane: Title, settings checklist, action buttons
// ─────────────────────────────────────────────────────────────────────────────

class _ExportOptionsPane extends StatelessWidget {
  final _DownloadState downloadState;
  final VoidCallback onDownload;
  final VoidCallback onBackToEditor;

  const _ExportOptionsPane({
    required this.downloadState,
    required this.onDownload,
    required this.onBackToEditor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title block
          Text(
            'Presentation Ready',
            style: GoogleFonts.getFont(
              AppSettings.instance.fontFamily,
              textStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: SacredColors.primary,
                letterSpacing: -0.5,
                height: 1.25,
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your creative ministry assets are compiled and optimized for the big screen.',
            style: SacredTypography.bodyMd(context)
                .copyWith(color: SacredColors.onSurfaceVariant),
          ),
          SizedBox(height: 32),

          // Settings checklist rows
          _SettingsCheckRow(
            icon: Icons.aspect_ratio,
            label: 'Aspect Ratio',
            value: '16:9',
          ),
          SizedBox(height: 12),
          _SettingsCheckRow(
            icon: Icons.layers_outlined,
            label: 'Editable Layers',
            value: 'Enabled',
          ),
          SizedBox(height: 12),
          _SettingsCheckRow(
            icon: Icons.hd_outlined,
            label: 'Resolution',
            value: '4K Ready',
          ),
          SizedBox(height: 12),
          _SettingsCheckRow(
            icon: Icons.animation,
            label: 'Transitions',
            value: 'Embedded',
          ),

          const Spacer(),
          SizedBox(height: 32),

          // Download PPTX Primary Button
          _DownloadButton(
            state: downloadState,
            onPressed: onDownload,
          ),
          SizedBox(height: 12),

          // Save to Library Secondary Button
          _SecondaryActionButton(
            icon: Icons.auto_awesome_motion_outlined,
            label: 'Save to Local Library',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Saved to Local Library!'),
                  backgroundColor: SacredColors.primary,
                ),
              );
            },
          ),
          SizedBox(height: 24),

          // Back to editor text link
          Center(
            child: TextButton(
              onPressed: onBackToEditor,
              style: TextButton.styleFrom(
                foregroundColor: SacredColors.outline,
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'BACK TO EDITOR',
                style: SacredTypography.labelSm(context).copyWith(
                  color: SacredColors.outline,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings check row
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCheckRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingsCheckRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SacredColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: SacredColors.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: SacredTypography.labelLg(context),
            ),
          ),
          Text(
            value,
            style: SacredTypography.bodyMd(context).copyWith(
              color: SacredColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Download Button
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadButton extends StatefulWidget {
  final _DownloadState state;
  final VoidCallback onPressed;

  const _DownloadButton({required this.state, required this.onPressed});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget leadingIcon;
    String labelText;
    Color bgTop;
    Color bgBottom;

    switch (widget.state) {
      case _DownloadState.preparing:
        leadingIcon = AnimatedBuilder(
          animation: _spinController,
          builder: (_, _) => Transform.rotate(
            angle: _spinController.value * 2 * math.pi,
            child: Icon(Icons.refresh, color: Colors.white, size: 20),
          ),
        );
        labelText = 'Preparing...';
        bgTop = SacredColors.primaryContainer;
        bgBottom = SacredColors.primaryContainer;
        break;
      case _DownloadState.done:
        leadingIcon =
            Icon(Icons.check, color: Colors.white, size: 20);
        labelText = 'Download Started';
        bgTop = SacredColors.tertiary;
        bgBottom = SacredColors.tertiary;
        break;
      case _DownloadState.idle:
        leadingIcon =
            Icon(Icons.download, color: Colors.white, size: 20);
        labelText = 'Download PPTX';
        bgTop = const Color(0xFF5D00A3);
        bgBottom = SacredColors.primaryContainer;
        break;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..translate(0.0, _isHovered && widget.state == _DownloadState.idle ? -2.0 : 0.0, 0.0),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgTop, bgBottom],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: SacredColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : SacredShadows.sacred,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leadingIcon,
                  SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      labelText,
                      key: ValueKey(labelText),
                      style: SacredTypography.labelLg(context)
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary outlined action button
// ─────────────────────────────────────────────────────────────────────────────

class _SecondaryActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_SecondaryActionButton> createState() => _SecondaryActionButtonState();
}

class _SecondaryActionButtonState extends State<_SecondaryActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: _isHovered
              ? SacredColors.surfaceContainerLow
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SacredColors.outlineVariant, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon,
                    color: SacredColors.onSurfaceVariant, size: 20),
                SizedBox(width: 10),
                Text(
                  widget.label,
                  style: SacredTypography.labelLg(context).copyWith(
                    color: SacredColors.onSurfaceVariant,
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

// ─────────────────────────────────────────────────────────────────────────────
// Floating success toast
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessToast extends StatelessWidget {
  const _SuccessToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: SacredColors.inverseSurface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: SacredColors.secondaryFixed,
            size: 20,
          ),
          SizedBox(width: 12),
          Text(
            'All assets synchronized with cloud',
            style: SacredTypography.labelLg(context).copyWith(
              color: SacredColors.inverseOnSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subtle dot grid background painter
// ─────────────────────────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 24.0;
    const double radius = 1.2;
    final Paint paint = Paint()
      ..color = SacredColors.primary.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
