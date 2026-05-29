import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'preview_page.dart';
import 'settings_state.dart';
import 'connectivity_badge.dart';
import 'settings_page.dart';
import 'create_presentation_page.dart';
import 'templates_page.dart';
import 'fullscreen_presenter_page.dart';
import 'library_page.dart';


/// Exact Material 3 custom color system derived from the design tailwind config.
class SacredColors {
  static Color get surfaceContainer => AppSettings.instance.isDarkMode ? const Color(0xFF16203A) : const Color(0xFFE7EEFE);
  static Color get primaryFixed => const Color(0xFFF0DBFF);
  static Color get surfaceContainerHigh => AppSettings.instance.isDarkMode ? const Color(0xFF1D2A4C) : const Color(0xFFE2E8F8);
  static Color get onTertiary => const Color(0xFFFFFFFF);
  static Color get surfaceContainerHighest => AppSettings.instance.isDarkMode ? const Color(0xFF25355E) : const Color(0xFFDCE2F3);
  static Color get primary {
    final baseColor = AppSettings.instance.primaryColor;
    if (AppSettings.instance.isDarkMode) {
      if (baseColor.value == 0xFF2E0052) {
        return const Color(0xFFDDB7FF); // Gorgeous pastel lavender for dark mode
      }
      final hsl = HSLColor.fromColor(baseColor);
      return hsl.withLightness((hsl.lightness + 0.35).clamp(0.65, 0.85)).toColor();
    }
    return baseColor;
  }
  static Color get tertiaryContainer => const Color(0xFF2D00A0);
  static Color get onError => const Color(0xFFFFFFFF);
  static Color get outlineVariant => AppSettings.instance.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFCEC3D3);
  static Color get secondaryContainer => const Color(0xFFFED65B);
  static Color get primaryFixedDim => const Color(0xFFDDB7FF);
  static Color get onSecondaryFixed => const Color(0xFF241A00);
  static Color get onErrorContainer => const Color(0xFF93000A);
  static Color get surface => AppSettings.instance.isDarkMode ? const Color(0xFF0A0F1D) : const Color(0xFFF9F9FF);
  static Color get secondaryFixed => const Color(0xFFFFE088);
  static Color get errorContainer => const Color(0xFFFFDAD6);
  static Color get onBackground => AppSettings.instance.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF151C27);
  static Color get secondary => const Color(0xFF735C00);
  static Color get surfaceVariant => AppSettings.instance.isDarkMode ? const Color(0xFF16203A) : const Color(0xFFDCE2F3);
  static Color get onPrimaryFixedVariant => const Color(0xFF622599);
  static Color get inverseOnSurface => const Color(0xFFEBF1FF);
  static Color get onTertiaryFixedVariant => const Color(0xFF442BB5);
  static Color get surfaceBright => AppSettings.instance.isDarkMode ? const Color(0xFF0A0F1D) : const Color(0xFFF9F9FF);
  static Color get onPrimary => const Color(0xFFFFFFFF);
  static Color get inverseSurface => const Color(0xFF2A313D);
  static Color get background => AppSettings.instance.isDarkMode ? const Color(0xFF0A0F1D) : const Color(0xFFF9F9FF);
  static Color get surfaceContainerLowest => AppSettings.instance.isDarkMode ? const Color(0xFF050811) : const Color(0xFFFFFFFF);
  static Color get outline => AppSettings.instance.isDarkMode ? const Color(0xFF475569) : const Color(0xFF7D7483);
  static Color get onPrimaryFixed => const Color(0xFF2C0050);
  static Color get onSecondaryContainer => const Color(0xFF745C00);
  static Color get tertiary => const Color(0xFF1A0066);
  static Color get onSecondary => const Color(0xFFFFFFFF);
  static Color get onTertiaryFixed => const Color(0xFF190064);
  static Color get onTertiaryContainer => const Color(0xFF9989FF);
  static Color get surfaceTint => const Color(0xFF7B41B3);
  static Color get onPrimaryContainer => const Color(0xFFBA7EF4);
  static Color get onSurfaceVariant => AppSettings.instance.isDarkMode ? const Color(0xFF8FA0BA) : const Color(0xFF4C4451);
  static Color get onSurface => AppSettings.instance.isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF151C27);
  static Color get inversePrimary => const Color(0xFFDDB7FF);
  static Color get onSecondaryFixedVariant => const Color(0xFF574500);
  static Color get error => const Color(0xFFBA1A1A);
  static Color get tertiaryFixed => const Color(0xFFE5DEFF);
  static Color get surfaceContainerLow => AppSettings.instance.isDarkMode ? const Color(0xFF0F1629) : const Color(0xFFF0F3FF);
  static Color get surfaceDim => AppSettings.instance.isDarkMode ? const Color(0xFF080C16) : const Color(0xFFD3DAEA);
  static Color get tertiaryFixedDim => const Color(0xFFC8BFFF);
  static Color get secondaryFixedDim => const Color(0xFFE9C349);
  static Color get primaryContainer => const Color(0xFF4B0082);
}

/// Precision-mapped typographic presets according to design requirements.
class SacredTypography {
  static TextStyle getTextStyle(String fontFamily, {required double fontSize, required FontWeight fontWeight, double? height, double? letterSpacing}) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      // Fallback to Inter if the font name is unrecognised
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }

  static TextStyle displayLg(BuildContext context) => getTextStyle(
        AppSettings.instance.fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 56 / 48,
        letterSpacing: -0.02,
      );

  static TextStyle headlineLg(BuildContext context) => getTextStyle(
        AppSettings.instance.fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 40 / 32,
      );

  static TextStyle headlineMd(BuildContext context) => getTextStyle(
        AppSettings.instance.fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 32 / 24,
      );

  static TextStyle bodyLg(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
      );

  static TextStyle bodyMd(BuildContext context) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );

  static TextStyle labelLg(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.05,
      );

  static TextStyle labelSm(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );
}


/// Custom premium shadows.
class SacredShadows {
  static List<BoxShadow> get sacred => [
        BoxShadow(
          color: SacredColors.primary.withValues(alpha: 0.05),
          offset: const Offset(0, 4),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];
}

class DashboardPage extends StatefulWidget {
  final String initialTab;
  const DashboardPage({super.key, this.initialTab = 'Dashboard'});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  void _onTabSelected(String tabName) {
    setState(() {
      _activeTab = tabName;
    });
    // Auto-close drawer on narrow screens if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
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
        key: _scaffoldKey,
        drawer: !isDesktop
            ? Drawer(
                width: 280,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: SacredSidebar(
                  activeTab: _activeTab,
                  onTabSelected: _onTabSelected,
                  isDrawer: true,
                ),
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop)
                SacredSidebar(
                  activeTab: _activeTab,
                  onTabSelected: _onTabSelected,
                  isDrawer: false,
                ),
              Expanded(
                child: _activeTab == 'Settings'
                    ? SettingsPage(scaffoldKey: _scaffoldKey)
                    : (_activeTab == 'Templates'
                        ? TemplatesPage(scaffoldKey: _scaffoldKey)
                        : (_activeTab == 'Library'
                            ? LibraryPage(scaffoldKey: _scaffoldKey)
                            : Column(
                            children: [
                              TopNavBar(
                                scaffoldKey: _scaffoldKey,
                                showMenuButton: !isDesktop,
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth > 768 ? 40.0 : 16.0,
                                      vertical: 24.0,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 1400),
                                        child: MainCanvasContent(
                                          screenWidth: screenWidth,
                                          onViewAll: () => _onTabSelected('Library'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom responsive sidebar with high-fidelity glassmorphic backdrop.
class SacredSidebar extends StatelessWidget {
  final String activeTab;
  final ValueChanged<String> onTabSelected;
  final bool isDrawer;

  const SacredSidebar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    required this.isDrawer,
  });

  void _showGoLiveDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _GoLivePresentationPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: SacredColors.outlineVariant,
                  width: 1.0,
                ),
              ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Brand Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Deck',
                        style: SacredTypography.headlineMd(context).copyWith(
                          color: SacredColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Creative Ministry',
                        style: SacredTypography.labelSm(context).copyWith(
                          color: SacredColors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40),

                // Navigation Items
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView(
                      children: [
                        _SidebarNavigationItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          isActive: activeTab == 'Dashboard',
                          onTap: () => onTabSelected('Dashboard'),
                        ),
                        SizedBox(height: 8),
                        _SidebarNavigationItem(
                          icon: Icons.library_books_outlined,
                          activeIcon: Icons.library_books,
                          label: 'Library',
                          isActive: activeTab == 'Library',
                          onTap: () => onTabSelected('Library'),
                        ),
                        SizedBox(height: 8),
                        _SidebarNavigationItem(
                          icon: Icons.layers_outlined,
                          activeIcon: Icons.layers,
                          label: 'Templates',
                          isActive: activeTab == 'Templates',
                          onTap: () => onTabSelected('Templates'),
                        ),
                        SizedBox(height: 8),
                        _SidebarNavigationItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: 'Settings',
                          isActive: activeTab == 'Settings',
                          onTap: () => onTabSelected('Settings'),
                        ),
                      ],
                    ),
                  ),
                ),

                // Go Live Action Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: _HoverScaleButton(
                    onPressed: () => _showGoLiveDialog(context),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: SacredColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: SacredShadows.sacred,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sensors,
                            color: SacredColors.onSecondaryContainer,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Go Live',
                            style: SacredTypography.labelLg(context).copyWith(
                              color: SacredColors.onSecondaryContainer,
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

/// Presentation picker dialog shown when user taps "Go Live".
class _GoLivePresentationPicker extends StatefulWidget {
  const _GoLivePresentationPicker();

  @override
  State<_GoLivePresentationPicker> createState() => _GoLivePresentationPickerState();
}

class _GoLivePresentationPickerState extends State<_GoLivePresentationPicker>
    with SingleTickerProviderStateMixin {
  PresentationRecord? _selected;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goLive(BuildContext context) {
    if (_selected == null) return;
    // Load the chosen presentation slides into AppSettings
    AppSettings.instance.updateActiveSlides(_selected!.slides);
    AppSettings.instance.activeSlideIndex = 0;
    Navigator.of(context).pop(); // close dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FullscreenPresenterPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PresentationRecord> defaults = [
      PresentationRecord(
        id: 'default_p1',
        title: 'Sunday Morning Service Outline',
        slideCount: 4,
        thumbnailUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCniRs1Ld_w4si47CthTlMWPs9oRIBhnBg8r14brIYLmzm-BycsqRBBSAa5ClNrCU8RtNAwk6rwmFZegQcWRe5y0dlGib11tkH4obKwQ-_4AYo4wgTRSlq0e-sV4irdcUi-xweItlUWQu4-yMIG75WKoS5HApIF2yAc9QuRAzHaNYwMS_CI4gxp45msnSVkbuPINnONgWbzItsjsZaUxo0Y6vIjzYnY1PMavyQbz7NPSsynWrkin2eZGH5C4CS08ALHQMCQWS7PyfoU',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        outlineText: '[Welcome Home]\nPeace be with you as we enter this sacred space.\n\n[Worship Set 1]\nSing praises to the King, lift up holy hands.\n\n[Sermon Notes]\nExploring the deep roots of our faith and community.\n\n[Closing Prayer]\nGo forth in grace, spread peace and wisdom.',
        slides: [
          SlideData(
            id: '01',
            title: 'Welcome Home',
            subtitle: '"Peace be with you as we enter this sacred space."',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAkigYecE0CmKCuZFuBavKgN8DzoLC7W6Sk1f-88TsL65rI2VnvQzMWzMBXlbn8NSWWMj3iuMzd11L6JwDZ2c8g0xtJ2u0GEE_8MBPBgHYWSh0YLC1YOuFntl9RJBWsp_VN3nRZxNGLDsJHoY5mYOytCHGZhxtVaiBfRrxImcruugnP5uLvBWeSb5hVCEijqYRd-ALjE3KK6juaQxJCITKZ5jv7tLDBMLKDJmX1snESiJYg_J9JA4PfxwbF4qYm65btRgUVbPErgMhD',
            opacity: 0.85,
            blur: 12.0,
          ),
          SlideData(
            id: '02',
            title: 'Worship Set 1',
            subtitle: '"Sing praises to the King, lift up holy hands."',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBfTxPcvdVGtfS9lB7z9X1sbdQv7Ilwyi2_gIR8q6qyd9VBoA89wAD1lUuPKcv-bTKvDQfFzhBP6D7Wmk9GXpxYRw7FAL7uNi_tcvc3eygW39xLOHnW1sTQPIVorDBZlUEyEzmhNPNBCDJjA2Ij6dXwIx3KehHleNrkVpRci9akO3-G-MmNbU2NkBiLJ8yIjB5aE0YBidFgvYrgL8hM7H6EzeujgWZY61dJJ3HW-o51FReWjE5GK3bd7aYCLoO6ydFHTSxp8PoX38Pr',
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
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBOy_uRm4spX4LG8doBchZNGyiO4lrxmQssiqyI1iBFyFONgeUCM5HyR_WsacGWJatGTaSzstvh3A7zkFM5td3MFYD-xSJa-ueTFJcUUCoIQqVNxm4-ij-iXs9bAGSuinsPa60GOYvzioSwl6ir3hv4gYp9koJQW3t9iNwMMd_0DUn2GN8_JD5pN31SbQYpl2Os2GzmPm7YG8Dsyc4RSXi64168o8knrfH0rilaDoh7w60YpEiQEIcyE0LjRoPA0C6KrEhbju4CVP4f',
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
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuC7vrdf0-1MvJXE356j2QWAdqpVFRk3iunfVAlO_TA1nQeR2qaAk5aQbTiQ7x4o41c8QKHp0WjP_U0ZZ_TynH_Qj7LxQUjwbVylQIqSgYPdkhsy-2gOEjVYnnsbP5aEwkSlo7v4TvZwP-TgpmFPGT-Dm4H254TZk2sMH_A9jiSsreTqRqwsMd_ORqBdEm5kA6iG1yBUgpPJ28OD9zSa1v0wfl0mj4Cg3lcsoA2w5BUSKkS-ZXLZ_fB_BwPKYOW0DUcuWNXievN0BCOG',
            opacity: 0.80,
            blur: 8.0,
          ),
        ],
      ),
      PresentationRecord(
        id: 'default_p2',
        title: 'Midweek Prayer Gathering',
        slideCount: 3,
        thumbnailUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAzj4bKIV4_XGsi0AAopVxbvmgDB7F6Gg7ENjFdX_qTkJmPz5xvpEdtsLncOZAbwfu7WYJocYrg4uHA1Fre-HMvMTQDsxBWC7c-3O6DP25T_zLzV45J6Z7EkGOlVTMe31XIOIkp-mbKlC9S3UnEBzzbE248cyQdlRML540kBxkTTH-R-4N0aks53Xs62c8Wuy73UApERXBWp8aMZBhHR4iH-rjtQPyChsedbsyCLsuCeQUAeh8BA4WJMDf9etg9Cq7801xQwX9Wya2T',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        outlineText: '[Welcome & Opening]\nGathering in communion and shared presence.\n\n[Prayer Request Session]\nLifting up each other and our wider community.\n\n[Doxology]\nPraise God from whom all blessings flow.',
        slides: [
          SlideData(
            id: '01',
            title: 'Welcome & Opening',
            subtitle: 'Gathering in communion and shared presence.',
            imageUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80',
          ),
          SlideData(
            id: '02',
            title: 'Prayer Requests',
            subtitle: 'Lifting up each other and our wider community.',
            imageUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80',
          ),
          SlideData(
            id: '03',
            title: 'Doxology',
            subtitle: 'Praise God from whom all blessings flow.',
            imageUrl: 'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?w=1280&q=80',
          ),
        ],
      ),
    ];

    final customPres = AppSettings.instance.recentPresentations;
    final List<PresentationRecord> presentations = [...customPres];
    for (final d in defaults) {
      if (!presentations.any((p) => p.title == d.title)) {
        presentations.add(d);
      }
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: SacredColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: SacredColors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SacredColors.primary.withValues(alpha: 0.12),
                        blurRadius: 60,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(28, 28, 20, 20),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: SacredColors.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: SacredColors.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sensors,
                                color: SacredColors.onSecondaryContainer,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Go Live',
                                    style: SacredTypography.headlineMd(context).copyWith(
                                      color: SacredColors.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Select a presentation to begin',
                                    style: SacredTypography.labelSm(context).copyWith(
                                      color: SacredColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: SacredColors.onSurfaceVariant, size: 22),
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Cancel',
                            ),
                          ],
                        ),
                      ),

                      // ── Presentation List ────────────────────────────────────
                      if (presentations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
                          child: Column(
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                color: SacredColors.onSurfaceVariant.withValues(alpha: 0.4),
                                size: 56,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No presentations saved yet.',
                                style: SacredTypography.bodyMd(context).copyWith(
                                  color: SacredColors.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a new project first, then come back to go live.',
                                style: SacredTypography.labelSm(context).copyWith(
                                  color: SacredColors.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            itemCount: presentations.length,
                            separatorBuilder: (_, i2) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final pres = presentations[i];
                              final isSelected = _selected?.id == pres.id;
                              return _GoLivePresentationTile(
                                record: pres,
                                isSelected: isSelected,
                                onTap: () => setState(() => _selected = pres),
                              );
                            },
                          ),
                        ),

                      // ── Footer Buttons ───────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: SacredColors.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: SacredColors.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: SacredTypography.labelLg(context).copyWith(
                                  color: SacredColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedOpacity(
                              opacity: _selected != null ? 1.0 : 0.4,
                              duration: const Duration(milliseconds: 200),
                              child: _HoverScaleButton(
                                onPressed: _selected != null ? () => _goLive(context) : () {},
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selected != null
                                        ? SacredColors.secondaryContainer
                                        : SacredColors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: _selected != null ? SacredShadows.sacred : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sensors,
                                        color: _selected != null
                                            ? SacredColors.onSecondaryContainer
                                            : SacredColors.onSurfaceVariant,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Start Presenting',
                                        style: SacredTypography.labelLg(context).copyWith(
                                          color: _selected != null
                                              ? SacredColors.onSecondaryContainer
                                              : SacredColors.onSurfaceVariant,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single selectable tile inside the Go Live picker.
class _GoLivePresentationTile extends StatefulWidget {
  final PresentationRecord record;
  final bool isSelected;
  final VoidCallback onTap;

  const _GoLivePresentationTile({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_GoLivePresentationTile> createState() => _GoLivePresentationTileState();
}

class _GoLivePresentationTileState extends State<_GoLivePresentationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.record.thumbnailUrl.isNotEmpty
        ? widget.record.thumbnailUrl
        : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? SacredColors.primary.withValues(alpha: 0.08)
                : (_isHovered
                    ? SacredColors.surfaceContainerHigh
                    : SacredColors.surfaceContainerLow),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? SacredColors.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 52,
                  child: imageUrl.isNotEmpty
                      ? (imageUrl.startsWith('data:')
                          ? Image.memory(
                              Uri.parse(imageUrl).data!.contentAsBytes(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => _thumbnailPlaceholder(),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => _thumbnailPlaceholder(),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : _thumbnailPlaceholder(),
                            ))
                      : _thumbnailPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.title,
                      style: SacredTypography.bodyMd(context).copyWith(
                        color: SacredColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          size: 12,
                          color: SacredColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.record.slideCount} slides',
                          style: SacredTypography.labelSm(context).copyWith(
                            color: SacredColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time_outlined,
                          size: 12,
                          color: SacredColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.record.relativeTime,
                            style: SacredTypography.labelSm(context).copyWith(
                              color: SacredColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? SacredColors.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? SacredColors.primary
                        : SacredColors.outline.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: SacredColors.surfaceContainerHighest,
      child: Icon(
        Icons.slideshow,
        color: SacredColors.primary.withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }
}

/// Dynamic navigation item that handles hover configurations.
class _SidebarNavigationItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SidebarNavigationItem> createState() => _SidebarNavigationItemState();
}

class _SidebarNavigationItemState extends State<_SidebarNavigationItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? SacredColors.primaryFixedDim.withValues(alpha: 0.2)
                : (_isHovered
                    ? SacredColors.primaryFixedDim.withValues(alpha: 0.1)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                color: widget.isActive ? SacredColors.primary : SacredColors.onSurfaceVariant,
                size: 24,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: SacredTypography.labelLg(context).copyWith(
                    color: widget.isActive ? SacredColors.primary : SacredColors.onSurfaceVariant,
                    fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.isActive)
                Container(
                  width: 2,
                  height: 20,
                  decoration: BoxDecoration(
                    color: SacredColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// sticky top menu bar containing search and quick widgets.
class TopNavBar extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showMenuButton;

  const TopNavBar({
    super.key,
    required this.scaffoldKey,
    required this.showMenuButton,
  });

  @override
  State<TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends State<TopNavBar> {

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
        children: [
          if (widget.showMenuButton) ...[
            IconButton(
              icon: Icon(Icons.menu, color: SacredColors.onSurface),
              onPressed: () => widget.scaffoldKey.currentState?.openDrawer(),
            ),
            SizedBox(width: 8),
          ],

          // Search Field Widget
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _SearchInputWidget(),
              ),
            ),
          ),

          // Utility badging and alerts
          Row(
            children: [
              // Online / Offline Status Badge — animated
              ConnectivityBadge(),
              SizedBox(width: 16),

              // Notifications Bell
              IconButton(
                icon: Icon(
                  Icons.notifications_none_outlined,
                  color: SacredColors.onSurfaceVariant,
                ),
                hoverColor: SacredColors.primary.withValues(alpha: 0.05),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No new notifications.'),
                      backgroundColor: SacredColors.primary,
                    ),
                  );
                },
              ),
              SizedBox(width: 16),

              // Action button
              _HoverScaleButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreatePresentationPage()),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: SacredColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'New Project',
                    style: SacredTypography.labelLg(context).copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // User Profile Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SacredColors.outlineVariant,
                    width: 1.0,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBwh3vonid1ngAi51NslYCK98ch_Ru6XAmw8Jxa4IWPRoat5H6ZbIJUiBont_TIFbOZgF6OJ53PIGZ0_NHSrYOM5EFIYzJXflm5Q5NL8Zyh5qu-OWVeuFWl_XxCfM5VBQWQFvDSHGOh0zJOwfLf-4OcxJfvwU-5SXB1NLgphx6a-3Xc3rR0YhQm2I5gMzPXIzZB_OVDoSEMJMANwl8tbhcWKDSBAFacGr1butev-yNpdl1k5vcXjSNsj249FSUfb79QVrbCpn_p9vZy',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: SacredColors.primaryFixed,
                        child: Icon(
                          Icons.person,
                          color: SacredColors.primary,
                          size: 18,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: SacredColors.surfaceContainerHigh,
                        child: Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: SacredColors.primary,
                            ),
                          ),
                        ),
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

/// Custom Search TextField with focus animation
class _SearchInputWidget extends StatefulWidget {
  @override
  State<_SearchInputWidget> createState() => _SearchInputWidgetState();
}

class _SearchInputWidgetState extends State<_SearchInputWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _isFocused ? SacredColors.primary : SacredColors.outlineVariant,
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
      ),
      child: TextField(
        focusNode: _focusNode,
        style: SacredTypography.bodyMd(context),
        decoration: InputDecoration(
          hintText: 'Search presentations...',
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
          contentPadding: EdgeInsets.symmetric(vertical: 12.0),
        ),
      ),
    );
  }
}

class MainCanvasContent extends StatelessWidget {
  final double screenWidth;
  final VoidCallback onViewAll;

  const MainCanvasContent({
    super.key,
    required this.screenWidth,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final bool useVerticalHero = screenWidth < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Section Layout
        if (useVerticalHero) ...[
          const CreateNewPresentationCard(),
          SizedBox(height: 24),
          const StorageWidget(),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 2,
                child: CreateNewPresentationCard(),
              ),
              SizedBox(width: 24),
              const Expanded(
                flex: 1,
                child: StorageWidget(),
              ),
            ],
          ),
        ],
        SizedBox(height: 48),

        // Recent Presentations Section Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Presentations',
              style: SacredTypography.headlineLg(context).copyWith(
                color: SacredColors.primary,
              ),
            ),
            _ViewAllButton(onTap: onViewAll),
          ],
        ),
        SizedBox(height: 24),

        // Recent Presentations Grid Layout
        RecentPresentationsGrid(screenWidth: screenWidth),
      ],
    );
  }
}

/// Create New Presentation Interactive Card
class CreateNewPresentationCard extends StatefulWidget {
  const CreateNewPresentationCard({super.key});

  @override
  State<CreateNewPresentationCard> createState() => _CreateNewPresentationCardState();
}

class _CreateNewPresentationCardState extends State<CreateNewPresentationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePresentationPage()),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 256,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? SacredColors.primary.withValues(alpha: 0.5)
                  : SacredColors.outlineVariant.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: SacredShadows.sacred,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Hover Gradient Overlay
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          SacredColors.primary.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Center Widget Column
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Add Icon Background
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: 64,
                        height: 64,
                        transform: Matrix4.diagonal3Values(_isHovered ? 1.1 : 1.0, _isHovered ? 1.1 : 1.0, 1.0),
                        transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SacredColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          color: SacredColors.primary,
                          size: 36,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Create New Presentation',
                        style: SacredTypography.headlineMd(context).copyWith(
                          color: SacredColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Start with a blank canvas or a spiritual template',
                          style: SacredTypography.bodyMd(context).copyWith(
                            color: SacredColors.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
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

/// Local Storage usage card — reads real data from AppSettings.
class StorageWidget extends StatelessWidget {
  const StorageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        final fraction = settings.storageFraction;
        final usedLabel = settings.storageUsedLabel;
        final totalLabel = settings.storageTotalLabel;
        final count = settings.recentPresentations.length;

        // Color shifts: green → amber → red as usage grows
        final Color barColor = fraction < 0.6
            ? SacredColors.primary
            : (fraction < 0.85
                ? const Color(0xFFD97706) // amber
                : const Color(0xFFDC2626)); // red

        return Container(
          height: 256,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SacredColors.outlineVariant.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: SacredShadows.sacred,
          ),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SacredColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.storage_outlined,
                      color: SacredColors.primary,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SacredColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$count Presentation${count == 1 ? '' : 's'}',
                      style: SacredTypography.labelSm(context).copyWith(
                        color: SacredColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Storage Usage',
                style: SacredTypography.labelLg(context).copyWith(
                  color: SacredColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Animated progress bar driven by real fraction
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: fraction),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 8,
                        decoration: BoxDecoration(
                          color: SacredColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            usedLabel,
                            style: SacredTypography.labelSm(context).copyWith(
                              color: barColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'of $totalLabel',
                            style: SacredTypography.labelSm(context).copyWith(
                              color: SacredColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const Spacer(),
              Text(
                '* Based on presentation data saved to this device.',
                style: SacredTypography.labelSm(context).copyWith(
                  color: SacredColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// View All Interactive Icon-Text Button
class _ViewAllButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ViewAllButton({required this.onTap});

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TextButton(
        onPressed: widget.onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View All',
              style: SacredTypography.labelLg(context).copyWith(
                color: SacredColors.primary,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: _isHovered ? 8.0 : 4.0),
              child: Icon(
                Icons.chevron_right,
                color: SacredColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive Grid component generating cards.
class RecentPresentationsGrid extends StatelessWidget {
  final double screenWidth;

  const RecentPresentationsGrid({super.key, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = 1;
    if (screenWidth >= 1200) {
      crossAxisCount = 3;
    } else if (screenWidth >= 768) {
      crossAxisCount = 2;
    }

    final double childAspectRatio = screenWidth > 480 ? (16 / 14) : (16 / 15);

    final recent = AppSettings.instance.recentPresentations;

    if (recent.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No recent presentations.\nCreate a new project to get started.',
          textAlign: TextAlign.center,
          style: SacredTypography.bodyLg(context).copyWith(
            color: SacredColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: recent.map((record) => PresentationCard(record: record)).toList(),
    );
  }
}

/// Presentation Card with micro-animations.
class PresentationCard extends StatefulWidget {
  final PresentationRecord record;

  const PresentationCard({
    super.key,
    required this.record,
  });

  @override
  State<PresentationCard> createState() => _PresentationCardState();
}

class _PresentationCardState extends State<PresentationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.record.thumbnailUrl.isNotEmpty
        ? widget.record.thumbnailUrl
        : 'https://lh3.googleusercontent.com/aida-public/AB6AXuCniRs1Ld_w4si47CthTlMWPs9oRIBhnBg8r14brIYLmzm-BycsqRBBSAa5ClNrCU8RtNAwk6rwmFZegQcWRe5y0dlGib11tkH4obKwQ-_4AYo4wgTRSlq0e-sV4irdcUi-xweItlUWQu4-yMIG75WKoS5HApIF2yAc9QuRAzHaNYwMS_CI4gxp45msnSVkbuPINnONgWbzItsjsZaUxo0Y6vIjzYnY1PMavyQbz7NPSsynWrkin2eZGH5C4CS08ALHQMCQWS7PyfoU';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PreviewPage(
                presentationId: widget.record.id,
                initialSlides: widget.record.slides,
                outlineText: widget.record.outlineText,
              ),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(_isHovered ? 1.02 : 1.0, _isHovered ? 1.02 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SacredColors.outlineVariant.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: SacredShadows.sacred,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image aspect header container
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: _isHovered ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: imageUrl.startsWith('data:')
                              ? Image.memory(
                                  Uri.parse(imageUrl).data!.contentAsBytes(),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: SacredColors.surfaceContainerHighest,
                                      child: Icon(Icons.image, color: SacredColors.primary, size: 40),
                                    );
                                  },
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: SacredColors.surfaceContainerHighest,
                                      child: Icon(Icons.image, color: SacredColors.primary, size: 40),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: SacredColors.surfaceContainerHighest,
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2, color: SacredColors.primary),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      // Black/translucent hover overlay
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          color: _isHovered ? Colors.black.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.2),
                        ),
                      ),

                      // Slides Count Badge
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              color: Colors.black.withValues(alpha: 0.4),
                              child: Text(
                                '${widget.record.slideCount} Slides',
                                style: SacredTypography.labelSm(context).copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Card Labels Section
                Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.record.title,
                        style: SacredTypography.bodyLg(context).copyWith(
                          color: SacredColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.record.relativeTime,
                        style: SacredTypography.labelSm(context).copyWith(
                          color: SacredColors.onSurfaceVariant,
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

/// Generic Wrapper handling custom mouse scale animations.
class _HoverScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _HoverScaleButton({required this.child, required this.onPressed});

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(_isHovered ? 1.05 : 1.0, _isHovered ? 1.05 : 1.0, 1.0),
          transformAlignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
