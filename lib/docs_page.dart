import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_page.dart'; // Reuse SacredColors, SacredTypography, SacredShadows
import 'connectors/remote_control_service.dart';
import 'settings_state.dart';

class DocsPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const DocsPage({super.key, required this.scaffoldKey});

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  String _selectedSection = 'remote';

  // Available sections
  final List<Map<String, dynamic>> _sections = [
    {
      'id': 'remote',
      'title': 'Phone Remote Control',
      'icon': Icons.phone_android,
      'subtitle': 'Control slides from any phone',
    },
    {
      'id': 'obs',
      'title': 'OBS Studio Overlay',
      'icon': Icons.video_call,
      'subtitle': 'Transparent lower thirds for stream',
    },
    {
      'id': 'projection',
      'title': 'Multi-Display Setup',
      'icon': Icons.monitor,
      'subtitle': 'Manage projectors & screen routing',
    },
    {
      'id': 'bible',
      'title': 'Bible Projection',
      'icon': Icons.menu_book,
      'subtitle': 'Cast scriptures to display or OBS',
    },
    {
      'id': 'shortcuts',
      'title': 'Keyboard Shortcuts',
      'icon': Icons.keyboard,
      'subtitle': 'Speed up your live operations',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final primaryColor = SacredColors.primary;

    return Scaffold(
      backgroundColor: SacredColors.background,
      body: Column(
        children: [
          // Top Navigation Bar
          TopNavBar(
            scaffoldKey: widget.scaffoldKey,
            showMenuButton: !isDesktop,
          ),
          
          // Documentation Main Container
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Category selection list
                if (isDesktop)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: SacredColors.outlineVariant,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(24.0),
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        final section = _sections[index];
                        final isSelected = _selectedSection == section['id'];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSection = section['id'];
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withOpacity(0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.2)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    section['icon'] as IconData,
                                    color: isSelected ? primaryColor : SacredColors.onSurfaceVariant,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          section['title'] as String,
                                          style: SacredTypography.labelLg(context).copyWith(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? primaryColor : SacredColors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          section['subtitle'] as String,
                                          style: SacredTypography.labelSm(context).copyWith(
                                            color: SacredColors.onSurfaceVariant.withOpacity(0.8),
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
                      },
                    ),
                  ),

                // Right Panel: Detailed view
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 768 ? 40.0 : 16.0,
                      vertical: 24.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mobile category selector (horizontal scrolling list when not on desktop)
                            if (!isDesktop) ...[
                              SizedBox(
                                height: 50,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _sections.length,
                                  itemBuilder: (context, index) {
                                    final section = _sections[index];
                                    final isSelected = _selectedSection == section['id'];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        label: Text(section['title'] as String),
                                        selected: isSelected,
                                        onSelected: (val) {
                                          if (val) {
                                            setState(() {
                                              _selectedSection = section['id'];
                                            });
                                          }
                                        },
                                        selectedColor: primaryColor.withOpacity(0.15),
                                        checkmarkColor: primaryColor,
                                        labelStyle: TextStyle(
                                          color: isSelected ? primaryColor : SacredColors.onSurface,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Load selected guide content
                            _buildSelectedGuideContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedGuideContent() {
    switch (_selectedSection) {
      case 'remote':
        return _buildRemoteGuide();
      case 'obs':
        return _buildOBSGuide();
      case 'projection':
        return _buildProjectionGuide();
      case 'bible':
        return _buildBibleGuide();
      case 'shortcuts':
        return _buildShortcutsGuide();
      default:
        return const SizedBox.shrink();
    }
  }

  // ------------------ GUIDE CONTENTS ------------------

  Widget _buildRemoteGuide() {
    final remoteService = RemoteControlService.instance;
    final isRunning = remoteService.isRunning;
    final pairingUrl = remoteService.pairingUrl;
    final ipAddress = remoteService.ipAddress;
    final primaryColor = SacredColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Phone Remote Control',
          subtitle: 'Step-by-step setup to turn your mobile device or tablet into a wireless slide and Bible presenter.',
          icon: Icons.phone_android,
        ),
        const SizedBox(height: 24),

        // Live connection card
        _buildInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isRunning ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning ? 'Remote Server Active' : 'Remote Server Offline',
                    style: SacredTypography.labelLg(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: isRunning ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isRunning) ...[
                Text(
                  'Your phone and computer must connect to the same Wi-Fi subnet. Type this URL into your phone\'s browser:',
                  style: SacredTypography.bodyMd(context),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SacredColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SacredColors.outlineVariant),
                  ),
                  child: SelectableText(
                    pairingUrl,
                    style: GoogleFonts.firaCode(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'The remote control server is not running. To activate it, go to the Settings tab and make sure remote control options are configured, or restart the server.',
                  style: SacredTypography.bodyMd(context),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildStep(
          number: 1,
          title: 'Connect to the Same Network',
          description: 'Ensure your computer running Live-Deck and your phone or tablet are connected to the exact same local Wi-Fi router subnet.',
        ),
        _buildStep(
          number: 2,
          title: 'Access the Pairing Link',
          description: 'Open the browser on your phone and type in the Pairing URL shown above. Alternatively, go to the Settings page and scan the QR Pairing Link code using your phone\'s camera app.',
        ),
        _buildStep(
          number: 3,
          title: 'Control Your Service Live',
          description: 'Once connected, the web remote will load automatically. You can switch slides, cast Bible scriptures, configure layout targets, black out screens, or trigger transitions directly from the palm of your hand.',
        ),

        const SizedBox(height: 20),
        _buildNoteBox(
          title: 'Troubleshooting: Connection Fails?',
          content: 'If the web remote page doesn\'t load on your phone:\n'
              '1. Ensure Windows Firewall is not blocking Live-Deck (the app automatically registers firewall rules, but third-party antiviruses might block port $ipAddress).\n'
              '2. Client Isolation: Some public or office Wi-Fi networks block devices from communicating with each other. If this occurs, enable Windows Mobile Hotspot on your PC, connect your phone to that Hotspot network, and access the new pairing URL.',
        ),
      ],
    );
  }

  Widget _buildOBSGuide() {
    final remoteService = RemoteControlService.instance;
    final overlayUrl = '${remoteService.pairingUrl}/overlay';
    final primaryColor = SacredColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'OBS Studio Overlay',
          subtitle: 'Display scriptures, lyrics, and lower thirds directly on your live streams with zero-latency transparency overlays.',
          icon: Icons.video_call,
        ),
        const SizedBox(height: 24),

        _buildInfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live-Deck OBS Overlay URL:',
                style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: SacredColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SacredColors.outlineVariant),
                ),
                child: SelectableText(
                  overlayUrl,
                  style: GoogleFonts.firaCode(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This URL serves a transparent web overlay rendering live outputs in real-time.',
                style: SacredTypography.labelSm(context).copyWith(color: SacredColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildStep(
          number: 1,
          title: 'Add Browser Source in OBS',
          description: 'Open OBS Studio, click the "+" button in the "Sources" dock, and select "Browser". Name it "Live-Deck Overlay" or similar.',
        ),
        _buildStep(
          number: 2,
          title: 'Configure the Source Properties',
          description: 'Paste the Overlay URL shown above into the "URL" field. Set Width to 1920 and Height to 1080 (or matches your canvas resolution). Delete any default CSS inside the "Custom CSS" field.',
        ),
        _buildStep(
          number: 3,
          title: 'Enable Overlay Routing',
          description: 'In the Live-Deck Bible or presentation settings, ensure the target is set to "OBS Only" or "Both". When you select a scripture, it will animate beautifully on the OBS feed, but won\'t block your physical projector display if configured for different roles.',
        ),

        const SizedBox(height: 20),
        _buildNoteBox(
          title: 'Pro-Tip: Transparent Styling',
          content: 'The overlay automatically applies transparency backgrounds. Do not add keyers or chroma-keys to the browser source inside OBS. Any slide text or scripture overlay will display with professional design shadows and clean anti-aliased font rendering.',
        ),
      ],
    );
  }

  Widget _buildProjectionGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Multi-Display Setup',
          subtitle: 'Configure external monitors, TVs, or projectors to show presentations to the audience while maintaining control dashboards.',
          icon: Icons.monitor,
        ),
        const SizedBox(height: 24),

        _buildStep(
          number: 1,
          title: 'Windows Display Configuration',
          description: 'Connect your external display (projector, TV, secondary monitor) using HDMI, VGA, or DisplayPort. Press "Windows Key + P" on your keyboard and select "Extend". Do NOT choose Duplicate.',
        ),
        _buildStep(
          number: 2,
          title: 'Select Target Display in Settings',
          description: 'Navigate to Settings -> Display Settings in Live-Deck. The app will list all active monitors. Pick the external display which corresponds to your projector screen.',
        ),
        _buildStep(
          number: 3,
          title: 'Activate Live Mode',
          description: 'Choose a presentation, Bible verse, or song, and tap "Go Live". The presentation canvas will automatically load fullscreen on the projector display, while the main monitor continues to display the presenter timeline and dashboard.',
        ),

        const SizedBox(height: 20),
        _buildNoteBox(
          title: 'Simulation Option',
          content: 'If you are testing at home without an external monitor, toggle "Simulate Audience Window" in the Settings. This launches a floating, resizable window mimicking the projector display so you can preview exactly what the congregation will see.',
        ),
      ],
    );
  }

  Widget _buildBibleGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Bible Projection Features',
          subtitle: 'Search, customize, and project scripture verses dynamically with single-click styling.',
          icon: Icons.menu_book,
        ),
        const SizedBox(height: 24),

        _buildStep(
          number: 1,
          title: 'Quick Search & Cast',
          description: 'Go to the Bible tab. Use the search input or quick selectors to locate the book, chapter, and verses. Single-tap any verse card to cast it instantly to the active projection display.',
        ),
        _buildStep(
          number: 2,
          title: 'Bible Target Configuration',
          description: 'Choose where scriptures should display:\n'
              '• "Display Only": Projects verses fullscreen to the congregation.\n'
              '• "OBS Only": Projects verses only as stream graphics / lower thirds on OBS.\n'
              '• "Both": Projects to both the physical screen and stream simultaneously.',
        ),
        _buildStep(
          number: 3,
          title: 'Themes & Lower Thirds',
          description: 'Adjust text size, alignment, and toggle between full-screen slides or elegant lower thirds (overlay banner at the bottom) under settings. This lets you style scriptures to match the tone of the service.',
        ),
      ],
    );
  }

  Widget _buildShortcutsGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Keyboard Shortcuts',
          subtitle: 'Operate Live-Deck like a pro. Keyboard bindings give you split-second control over slides and media.',
          icon: Icons.keyboard,
        ),
        const SizedBox(height: 24),

        _buildShortcutRow('Right Arrow / Space', 'Go to next slide'),
        _buildShortcutRow('Left Arrow', 'Go to previous slide'),
        _buildShortcutRow('Escape', 'Exit presentation mode / close dialogs'),
        _buildShortcutRow('B / Key B', 'Toggle blackout (Blackout audience screen)'),
        _buildShortcutRow('F / Key F', 'Toggle fullscreen presenter view'),
        _buildShortcutRow('F5', 'Quick launch Go Live presentation selector'),
        
        const SizedBox(height: 20),
        _buildNoteBox(
          title: 'Keyboard Focus',
          content: 'Ensure the Live-Deck app window is focused (clicked on) for keyboard shortcuts to execute. Shortcuts are disabled while actively typing inside text inputs.',
        ),
      ],
    );
  }

  // ------------------ REUSABLE WIDGET HELPERS ------------------

  Widget _buildHeader({required String title, required String subtitle, required IconData icon}) {
    final primaryColor = SacredColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: primaryColor, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SacredTypography.headlineMd(context).copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: SacredTypography.bodyMd(context).copyWith(
                  color: SacredColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SacredColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SacredColors.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildStep({required int number, required String title, required String description}) {
    final primaryColor = SacredColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number.toString(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: SacredTypography.bodyMd(context).copyWith(
                    color: SacredColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteBox({required String title, required String content}) {
    final primaryColor = SacredColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: SacredTypography.labelLg(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: SacredTypography.bodyMd(context).copyWith(
              color: SacredColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: SacredColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SacredColors.outlineVariant),
            ),
            child: Text(
              keys,
              style: GoogleFonts.firaCode(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: SacredColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              action,
              style: SacredTypography.bodyMd(context),
            ),
          ),
        ],
      ),
    );
  }
}
