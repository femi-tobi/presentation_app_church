import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dashboard_page.dart'; // Reuse SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'create_presentation_page.dart';
import 'connectivity_badge.dart';

class SettingsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const SettingsPage({super.key, this.scaffoldKey});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local page state
  late bool _isDarkMode;
  late bool _isOffline;
  late Color _selectedPrimary;
  late String _selectedFont;
  late String _churchName;
  late String _churchEmail;
  
  String? _logoUrl;
  IconData? _logoIcon;
  Uint8List? _logoBytes; // local file bytes

  // List of preset colors
  final List<Color> _presetColors = const [
    Color(0xFF2E0052), // default primary
    Color(0xFF1A0066),
    Color(0xFF735C00),
    Color(0xFFBA1A1A),
  ];

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    // Initialize local state from global AppSettings
    final settings = AppSettings.instance;
    _isDarkMode = settings.isDarkMode;
    _isOffline = settings.isOffline;
    _selectedPrimary = settings.primaryColor;
    _selectedFont = settings.fontFamily;
    _churchName = settings.churchName;
    _churchEmail = settings.churchEmail;
    _logoUrl = settings.logoUrl;

    _nameController = TextEditingController(text: _churchName);
    _emailController = TextEditingController(text: _churchEmail);
    _hexController = TextEditingController(
      text: '#${_selectedPrimary.value.toRadixString(16).substring(2).toUpperCase()}'
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _saveAllChanges() {
    final settings = AppSettings.instance;
    settings.isDarkMode = _isDarkMode;
    settings.isOffline = _isOffline;
    settings.primaryColor = _selectedPrimary;
    settings.fontFamily = _selectedFont;
    settings.churchName = _nameController.text;
    settings.churchEmail = _emailController.text;
    settings.logoUrl = _logoUrl;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Settings saved successfully and applied globally!'),
          ],
        ),
        backgroundColor: _selectedPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickLogo() async {
    // Show options: pick file from system OR choose icon
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => _LogoPickerDialog(
        selectedPrimary: _selectedPrimary,
        currentLogoUrl: _logoUrl,
        onFilePickRequest: () async {
          Navigator.of(ctx).pop();
          await _pickLogoFromSystem();
        },
        onIconPick: (icon) {
          setState(() {
            _logoIcon = icon;
            _logoUrl = null;
            _logoBytes = null;
          });
          Navigator.of(ctx).pop();
        },
        onUrlApply: (url) {
          setState(() {
            _logoUrl = url;
            _logoIcon = null;
            _logoBytes = null;
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _pickLogoFromSystem() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp', 'gif'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final extension = result.files.single.extension ?? 'png';
        final base64String = base64Encode(bytes);
        setState(() {
          _logoUrl = 'data:image/$extension;base64,$base64String';
          _logoBytes = bytes;
          _logoIcon = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: SacredColors.error,
          ),
        );
      }
    }
  }

  // (legacy helper removed - now handled by _LogoPickerDialog)

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SacredColors.background,
        colorScheme: ColorScheme(
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          primary: _selectedPrimary,
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
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  _TopNavBar(
                    scaffoldKey: widget.scaffoldKey,
                    isDarkMode: _isDarkMode,
                    onDarkToggle: (v) => setState(() => _isDarkMode = v),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: _SettingsContent(
                            isDarkMode: _isDarkMode,
                            onDarkToggle: (v) => setState(() => _isDarkMode = v),
                            isOffline: _isOffline,
                            onOfflineToggle: (v) => setState(() => _isOffline = v),
                            selectedPrimary: _selectedPrimary,
                            onColorSelect: (c) {
                              setState(() {
                                _selectedPrimary = c;
                                _hexController.text = '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
                              });
                            },
                            presetColors: _presetColors,
                             logoUrl: _logoUrl,
                             logoIcon: _logoIcon,
                             logoBytes: _logoBytes,
                             onUpload: _pickLogo,
                            onClearCache: () => AppSettings.instance.clearCache(),
                            nameController: _nameController,
                            emailController: _emailController,
                            hexController: _hexController,
                            selectedFont: _selectedFont,
                            onFontSelect: (f) => setState(() => _selectedFont = f),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 32,
              right: 32,
              child: FloatingActionButton.extended(
                backgroundColor: _selectedPrimary,
                hoverElevation: 12,
                elevation: 6,
                onPressed: _saveAllChanges,
                icon: Icon(Icons.save, color: Colors.white),
                label: Text(
                  'Save All Changes',
                  style: SacredTypography.labelLg(context).copyWith(color: Colors.white),
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
  final bool isDarkMode;
  final ValueChanged<bool> onDarkToggle;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const _TopNavBar({
    required this.isDarkMode,
    required this.onDarkToggle,
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
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: SacredColors.outline, size: 20),
                    hintText: 'Search settings...',
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
              Switch(
                value: isDarkMode,
                onChanged: onDarkToggle,
                activeThumbColor: SacredColors.primary,
              ),
              SizedBox(width: 12),
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
              CircleAvatar(
                radius: 18,
                backgroundColor: SacredColors.outlineVariant,
                backgroundImage: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBwh3vonid1ngAi51NslYCK98ch_Ru6XAmw8Jxa4IWPRoat5H6ZbIJUiBont_TIFbOZgF6OJ53PIGZ0_NHSrYOM5EFIYzJXflm5Q5NL8Zyh5qu-OWVeuFWl_XxCfM5VBQWQFvDSHGOh0zJOwfLf-4OcxJfvwU-5SXB1NLgphx6a-3Xc3rR0YhQm2I5gMzPXIzZB_OVDoSEMJMANwl8tbhcWKDSBAFacGr1butev-yNpdl1k5vcXjSNsj249FSUfb79QVrbCpn_p9vZy'
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------ Settings Content ------------------------
class _SettingsContent extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkToggle;
  final bool isOffline;
  final ValueChanged<bool> onOfflineToggle;
  final Color selectedPrimary;
  final ValueChanged<Color> onColorSelect;
  final List<Color> presetColors;
  final String? logoUrl;
  final IconData? logoIcon;
  final Uint8List? logoBytes;
  final VoidCallback onUpload;
  final VoidCallback onClearCache;

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController hexController;

  final String selectedFont;
  final ValueChanged<String> onFontSelect;

  const _SettingsContent({
    required this.isDarkMode,
    required this.onDarkToggle,
    required this.isOffline,
    required this.onOfflineToggle,
    required this.selectedPrimary,
    required this.onColorSelect,
    required this.presetColors,
    required this.logoUrl,
    required this.logoIcon,
    required this.logoBytes,
    required this.onUpload,
    required this.onClearCache,
    required this.nameController,
    required this.emailController,
    required this.hexController,
    required this.selectedFont,
    required this.onFontSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header
        Text('Settings', style: SacredTypography.displayLg(context).copyWith(color: selectedPrimary)),
        SizedBox(height: 8),
        Text(
          "Manage your ministry's visual identity and application preferences.",
          style: SacredTypography.bodyLg(context).copyWith(color: SacredColors.onSurfaceVariant),
        ),
        SizedBox(height: 40),

        // Church Identity Section
        Row(
          children: [
            Icon(Icons.church, color: selectedPrimary),
            SizedBox(width: 12),
            Text('Church Identity', style: SacredTypography.headlineLg(context)),
          ],
        ),
        SizedBox(height: 8),
        Divider(color: SacredColors.outlineVariant),
        SizedBox(height: 24),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onUpload,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: SacredColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SacredColors.outlineVariant, width: 2),
                      ),
                      child: Center(
                        child: _LogoPreview(
                          logoIcon: logoIcon,
                          logoUrl: logoUrl,
                          logoBytes: logoBytes,
                          selectedPrimary: selectedPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _LabeledField(label: 'Church Name', controller: nameController, hint: 'Grace Community Chapel'),
                  SizedBox(height: 20),
                  _LabeledField(label: 'Organization Email', controller: emailController, hint: 'media@gracecommunity.org'),
                  SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location Reference', style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurfaceVariant)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: SacredColors.outline),
                          SizedBox(width: 8),
                          Text('Nashville, TN', style: SacredTypography.bodyLg(context)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 48),

        // Default Styling Section
        Row(
          children: [
            Icon(Icons.palette, color: selectedPrimary),
            SizedBox(width: 12),
            Text('Default Styling', style: SacredTypography.headlineLg(context)),
          ],
        ),
        SizedBox(height: 8),
        Divider(color: SacredColors.outlineVariant),
        SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Typography selection
            Expanded(
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Typography', style: SacredTypography.labelLg(context).copyWith(color: selectedPrimary)),
                    SizedBox(height: 4),
                    Text('Choose a typeface for titles & body text', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant)),
                    SizedBox(height: 16),
                    // ── Serif ──────────────────────────────────────────────
                    _FontGroupLabel(label: 'Serif  —  Reverent & Traditional'),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Libre Caslon Text', description: 'Classic & Reverent', isSelected: selectedFont == 'Libre Caslon Text', onSelect: () => onFontSelect('Libre Caslon Text'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Playfair Display', description: 'Elegant & Bold', isSelected: selectedFont == 'Playfair Display', onSelect: () => onFontSelect('Playfair Display'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Lora', description: 'Warm & Literary', isSelected: selectedFont == 'Lora', onSelect: () => onFontSelect('Lora'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Merriweather', description: 'Readable & Sturdy', isSelected: selectedFont == 'Merriweather', onSelect: () => onFontSelect('Merriweather'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 16),
                    // ── Sans-Serif ─────────────────────────────────────────
                    _FontGroupLabel(label: 'Sans-Serif  —  Modern & Clean'),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Inter', description: 'Modern & Clean', isSelected: selectedFont == 'Inter', onSelect: () => onFontSelect('Inter'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Nunito', description: 'Friendly & Rounded', isSelected: selectedFont == 'Nunito', onSelect: () => onFontSelect('Nunito'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Poppins', description: 'Geometric & Contemporary', isSelected: selectedFont == 'Poppins', onSelect: () => onFontSelect('Poppins'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Raleway', description: 'Stylish & Elegant', isSelected: selectedFont == 'Raleway', onSelect: () => onFontSelect('Raleway'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 16),
                    // ── Display ───────────────────────────────────────────
                    _FontGroupLabel(label: 'Display  —  Expressive & Bold'),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Cinzel', description: 'Majestic & Sacred', isSelected: selectedFont == 'Cinzel', onSelect: () => onFontSelect('Cinzel'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Cormorant Garamond', description: 'Refined & Spiritual', isSelected: selectedFont == 'Cormorant Garamond', onSelect: () => onFontSelect('Cormorant Garamond'), selectedPrimary: selectedPrimary),
                    SizedBox(height: 8),
                    _FontCard(fontName: 'Oswald', description: 'Strong & Impactful', isSelected: selectedFont == 'Oswald', onSelect: () => onFontSelect('Oswald'), selectedPrimary: selectedPrimary),
                  ],
                ),
              ),
            ),
            SizedBox(width: 32),
            // Primary color selection
            Expanded(
              child: _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Primary Brand Color', style: SacredTypography.labelLg(context).copyWith(color: selectedPrimary)),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...presetColors.map((c) {
                          final bool isSelected = c.value == selectedPrimary.value;
                          return GestureDetector(
                            onTap: () => onColorSelect(c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: isSelected ? 8 : 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                            ),
                          );
                        }),
                        // Custom plus button color option
                        GestureDetector(
                          onTap: onUpload, // just open dialog or picker
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: SacredColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                              border: Border.all(color: SacredColors.outlineVariant),
                            ),
                            child: Icon(Icons.add, color: SacredColors.outline),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selectedPrimary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SacredColors.outlineVariant),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: hexController,
                            style: GoogleFonts.firaCode(),
                            decoration: InputDecoration(
                              labelText: 'Hex Code',
                              border: UnderlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 4),
                            ),
                            onSubmitted: (val) {
                              try {
                                final cleanHex = val.replaceAll('#', '').trim();
                                final color = Color(int.parse('0xFF$cleanHex'));
                                onColorSelect(color);
                              } catch (_) {}
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 48),

        // Application Section
        Row(
          children: [
            Icon(Icons.settings_suggest, color: selectedPrimary),
            SizedBox(width: 12),
            Text('Application', style: SacredTypography.headlineLg(context)),
          ],
        ),
        SizedBox(height: 8),
        Divider(color: SacredColors.outlineVariant),
        SizedBox(height: 24),

        _GlassCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dark_mode, color: SacredColors.outline),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dark Mode', style: SacredTypography.labelLg(context)),
                          SizedBox(height: 2),
                          Text('Switch to a dark interface to reduce eye strain.', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: isDarkMode,
                    onChanged: onDarkToggle,
                    activeThumbColor: selectedPrimary,
                  ),
                ],
              ),
              Divider(height: 32, color: SacredColors.outlineVariant),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_off, color: SacredColors.outline),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Offline Mode', style: SacredTypography.labelLg(context)),
                          SizedBox(height: 2),
                          Text('Pre-download presentation assets automatically.', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: isOffline,
                    onChanged: onOfflineToggle,
                    activeThumbColor: selectedPrimary,
                  ),
                ],
              ),
              Divider(height: 32, color: SacredColors.outlineVariant),
              // ── Storage: live reactive read from AppSettings ──────────────
              ListenableBuilder(
                listenable: AppSettings.instance,
                builder: (context, _) {
                  final settings = AppSettings.instance;
                  final usedLabel = settings.storageUsedLabel;
                  final totalLabel = settings.storageTotalLabel;
                  final fraction = settings.storageFraction;
                  final count = settings.recentPresentations.length;
                  final Color barColor = fraction < 0.6
                      ? selectedPrimary
                      : (fraction < 0.85 ? const Color(0xFFD97706) : const Color(0xFFDC2626));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage, color: SacredColors.outline),
                              SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Local Storage', style: SacredTypography.labelLg(context)),
                                  Text(
                                    '$count presentation${count == 1 ? '' : 's'} saved',
                                    style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '$usedLabel of $totalLabel',
                            style: SacredTypography.labelLg(context).copyWith(color: barColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: fraction),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (_, value, child2) => LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          backgroundColor: SacredColors.outlineVariant.withValues(alpha: 0.3),
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 8,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Calculated from JSON size of all saved presentations',
                        style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant, fontStyle: FontStyle.italic),
                      ),
                      SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: onClearCache,
                          icon: Icon(Icons.delete_sweep_outlined, size: 16, color: SacredColors.error),
                          label: Text('Clear All Presentations', style: TextStyle(color: SacredColors.error, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 100),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurfaceVariant)),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          style: SacredTypography.bodyLg(context),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
          ),
        ),
      ],
    );
  }
}

class _FontCard extends StatelessWidget {
  final String fontName;
  final String description;
  final bool isSelected;
  final VoidCallback onSelect;
  final Color selectedPrimary;

  const _FontCard({
    required this.fontName,
    required this.description,
    required this.isSelected,
    required this.onSelect,
    required this.selectedPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : SacredColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.format_size, color: isSelected ? selectedPrimary : SacredColors.outline),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fontName,
                      style: GoogleFonts.getFont(fontName).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? selectedPrimary : SacredColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(description, style: SacredTypography.labelSm(context).copyWith(color: SacredColors.outline)),
                  ],
                ),
              ],
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: selectedPrimary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SacredColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SacredColors.outlineVariant.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: child,
    );
  }
}

// ── Logo Preview ─────────────────────────────────────────────────────────────
class _LogoPreview extends StatelessWidget {
  final IconData? logoIcon;
  final String? logoUrl;
  final Uint8List? logoBytes;
  final Color selectedPrimary;

  const _LogoPreview({
    required this.logoIcon,
    required this.logoUrl,
    required this.logoBytes,
    required this.selectedPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (logoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          logoBytes!,
          fit: BoxFit.contain,
          errorBuilder: (_, e, s) => Icon(Icons.broken_image, size: 64, color: selectedPrimary),
        ),
      );
    }
    if (logoIcon != null) {
      return Icon(logoIcon, size: 64, color: selectedPrimary);
    }
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: logoUrl!.startsWith('data:')
            ? Image.memory(
                decodeDataUrl(logoUrl!),
                fit: BoxFit.contain,
                errorBuilder: (_, e, s) => Icon(Icons.broken_image, size: 64, color: selectedPrimary),
              )
            : (logoUrl!.startsWith('assets/')
                ? Image.asset(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) => Icon(Icons.broken_image, size: 64, color: selectedPrimary),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, s) => Icon(Icons.broken_image, size: 64, color: selectedPrimary),
                  )),
      );
    }
    // Empty state
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file, size: 48, color: selectedPrimary.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
        Text('Upload Church Logo', style: SacredTypography.labelLg(context)),
        const SizedBox(height: 4),
        Text('PNG, JPG, SVG or WebP', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.outline)),
      ],
    );
  }
}

// ── Logo Picker Dialog ────────────────────────────────────────────────────────
class _LogoPickerDialog extends StatefulWidget {
  final Color selectedPrimary;
  final String? currentLogoUrl;
  final Future<void> Function() onFilePickRequest;
  final void Function(IconData) onIconPick;
  final void Function(String) onUrlApply;

  const _LogoPickerDialog({
    required this.selectedPrimary,
    required this.currentLogoUrl,
    required this.onFilePickRequest,
    required this.onIconPick,
    required this.onUrlApply,
  });

  @override
  State<_LogoPickerDialog> createState() => _LogoPickerDialogState();
}

class _LogoPickerDialogState extends State<_LogoPickerDialog> {
  late TextEditingController _urlController;

  final List<({IconData icon, String label})> _icons = const [
    (icon: Icons.church, label: 'Church'),
    (icon: Icons.auto_awesome, label: 'Cross'),
    (icon: Icons.wb_sunny, label: 'Sunny'),
    (icon: Icons.eco, label: 'Leaf'),
    (icon: Icons.local_florist, label: 'Flower'),
    (icon: Icons.favorite, label: 'Heart'),
    (icon: Icons.star, label: 'Star'),
    (icon: Icons.brightness_5, label: 'Light'),
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.currentLogoUrl ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: SacredColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SacredColors.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: widget.selectedPrimary.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.selectedPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.image_outlined, color: widget.selectedPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Church Logo', style: SacredTypography.headlineMd(context).copyWith(fontWeight: FontWeight.bold, color: SacredColors.onSurface)),
                          Text('Choose how to set your logo', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: SacredColors.onSurfaceVariant, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Browse from system ────────────────────────────────
                    InkWell(
                      onTap: widget.onFilePickRequest,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.selectedPrimary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: widget.selectedPrimary.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.selectedPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.folder_open_outlined, color: widget.selectedPrimary, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Browse from your computer', style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurface, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('PNG, JPG, JPEG, SVG, WebP, GIF', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: widget.selectedPrimary, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Icon picker ───────────────────────────────────────
                    Text('Or pick a ministry symbol', style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _icons.map((entry) {
                        return InkWell(
                          onTap: () => widget.onIconPick(entry.icon),
                          borderRadius: BorderRadius.circular(12),
                          child: Tooltip(
                            message: entry.label,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: SacredColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: SacredColors.outlineVariant),
                              ),
                              child: Icon(entry.icon, color: widget.selectedPrimary, size: 26),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── URL input ─────────────────────────────────────────
                    Text('Or paste an image URL', style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: SacredTypography.bodyMd(context),
                            decoration: InputDecoration(
                              hintText: 'https://example.com/logo.png',
                              hintStyle: SacredTypography.bodyMd(context).copyWith(color: SacredColors.outline),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: widget.selectedPrimary, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.selectedPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final url = _urlController.text.trim();
                            if (url.isNotEmpty) widget.onUrlApply(url);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
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

// ── Font Group Label ──────────────────────────────────────────────────────────
class _FontGroupLabel extends StatelessWidget {
  final String label;
  const _FontGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label,
        style: SacredTypography.labelSm(context).copyWith(
          color: SacredColors.onSurfaceVariant.withValues(alpha: 0.7),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
