// lib/create_presentation_page.dart
import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // Reuse SacredColors, SacredTypography, SacredShadows
import 'settings_state.dart';
import 'preview_page.dart';
import 'connectivity_badge.dart';

class CreatePresentationPage extends StatefulWidget {
  const CreatePresentationPage({super.key});

  @override
  State<CreatePresentationPage> createState() => _CreatePresentationPageState();
}

class _CreatePresentationPageState extends State<CreatePresentationPage> {
  String _selectedTheme = 'Minimal';
  final TextEditingController _outlineController = TextEditingController(
    text: "[Prelude]\nMajesty (Hymn 124)\n\n[Call to Worship]\nPsalm 100:1-5\n\n[Sermon Title]\nThe Grace of Stillness\n\n[Scripture Reading]\nExodus 14:14\n\n[Benediction]"
  );

  bool _isGenerating = false;

  final List<ThemeCardData> _themes = [
    ThemeCardData(
      name: 'Minimal',
      description: 'Focus on typography and whitespace.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCEWjSclaMncei2id-Y44WOKnyCAaJ8NktRGpXAAJLPlSPYiUnxsteBJVpESDYvZUuJfVN-tsN_zuuo6yBwpA9J6Xzo6YAYMJUByiGiYTByFcVzDUCvrSJozDAUzEY2hdGeOSFGj2502EOtIVusHV-NczxSwrGF62NezExKx0fZlmjSVoq0uCITnG_lfGhdmjO-wSBeXQJTRgJhOED4J3rjat-VYxteMy8zASr7c7h6VldbZkYqek86KpdqoG2Dj7azZhNeyk2T6t1B',
      imageAlt: 'Serene white minimalist room with lamp.',
    ),
    ThemeCardData(
      name: 'Classic',
      description: 'Timeless aesthetics and traditional layouts.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDp98SZFBGhLfYlx9v4i26hRErWLgwcMqkUZYltDSZ5yD5RmpJAMbJKuGvdg7cW204TXmv1GKDgSMz17NfZLP8T_GEZrfqqVNv0382q1MQJOIS76AfW1JsEmD_6MxPzXlyWAWQHW484hXBwzUaQuSRu87CSnMJkL6FRmFPjKzURkHkO_dD-Yn21QAPUC75C1D-vnoSE3MC-K5levl1YIrxxzqD2S0f6IcFHbV0MV01C-XHFGATAiKkpoDy3Q8tq2jj10_hMetGL8LSJ',
      imageAlt: 'Cathedral ceiling with filtering sunlight.',
    ),
    ThemeCardData(
      name: 'Modern',
      description: 'Dynamic gradients and bold visual elements.',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBABTUucvzRgmNABWoWKIEZJTZWiPaPoZpiu5__6Bl2NBgVlmc7rPDu8BqANyWLkgIUwfXU-8p9vbd4WQ9i8IDvEFosKzzIJrsdfKfdfS9T7BAKpZhv-DfRfwLqa5AJ9_e_E_F-okP-jPWvNOWYmPZAjE5RB1vpOv5ivGlUGFN1xQ7lz_GoaDU-9vDzXmMV_uu4NtSf9ItOMHyItbEqVqc2_-GYAIoaRXuNEr-jbRTC09UXRnIibGyyD1W7H06FIhVU_V59wRIbJTTq',
      imageAlt: 'Deep purple and blue electric gradient trails.',
    ),
  ];

  @override
  void dispose() {
    _outlineController.dispose();
    super.dispose();
  }

  void _generateSlides() async {
    if (_outlineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please paste or write a service outline first.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    // Simulate brief generation delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() => _isGenerating = false);

    // Navigate to slide preview editor, passing the real outline + theme
    final String presentationId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPage(
          presentationId: presentationId,
          outlineText: _outlineController.text.trim(),
          selectedTheme: _selectedTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final isDarkMode = AppSettings.instance.isDarkMode;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

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
            // TopNavBar component
            _TopNavBar(),
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Pane: Outline Editor
                        Expanded(
                          flex: 3,
                          child: _EditorPane(
                            controller: _outlineController,
                            primaryColor: primaryColor,
                          ),
                        ),
                        Container(width: 1, color: SacredColors.outlineVariant),
                        // Right Pane: Style Selector
                        Expanded(
                          flex: 2,
                          child: _StyleSelectorPane(
                            themes: _themes,
                            selectedTheme: _selectedTheme,
                            onThemeSelect: (name) => setState(() => _selectedTheme = name),
                            onGenerate: _generateSlides,
                            isGenerating: _isGenerating,
                            primaryColor: primaryColor,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _EditorPane(
                            controller: _outlineController,
                            primaryColor: primaryColor,
                          ),
                          Divider(height: 1, color: SacredColors.outlineVariant),
                          _StyleSelectorPane(
                            themes: _themes,
                            selectedTheme: _selectedTheme,
                            onThemeSelect: (name) => setState(() => _selectedTheme = name),
                            onGenerate: _generateSlides,
                            isGenerating: _isGenerating,
                            primaryColor: primaryColor,
                          ),
                        ],
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
  @override
  Widget build(BuildContext context) {
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
              IconButton(
                icon: Icon(Icons.arrow_back, color: SacredColors.primary),
                tooltip: 'Back to Dashboard',
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              SizedBox(width: 16),
              SizedBox(
                width: 300,
                child: TextField(
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
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.notifications_none, color: SacredColors.onSurfaceVariant),
                onPressed: () {},
              ),
              SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: SacredColors.outlineVariant,
                backgroundImage: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDNfafaAK0N7FbiJhmk8n3gkX1nGpVARZocG7tESAu2-RQs_eJ2AvQXmjerkk-2Kvrb3OcjskEnqjdoSss5CZ9UM0HkbIyoY11FWDwVsBYDHNXcAKixzW9TJfCFrwbKJzF0H4F8PHFhfqmWK_uuXnIS8hZUl-c-ydOlnJIU6cdgtQfFP7AHNgtY8VEs_5zGhHv1lgA3uAYHs3OM0m6WO0-ZL8SZwSTena7ZzGaR-O-EMeNdYBrX_jc9FrctSCQzubVUuJtcUQ_KAuXh'
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------ Left: Editor Pane ------------------------
class _EditorPane extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;

  const _EditorPane({required this.controller, required this.primaryColor});

  void _importOutlineFile(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: SacredColors.surface,
          title: Text(
            'Import Service Outline File',
            style: SacredTypography.headlineMd(context).copyWith(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload a PDF, DOCX, or TXT file containing your sermon text or liturgy outline:',
                style: SacredTypography.labelLg(context),
              ),
              const SizedBox(height: 20),
              // Simulated drag & drop area
              InkWell(
                onTap: () {
                  controller.text = "[Prelude]\nPraise to the Lord, the Almighty\n\n[Scripture Reading]\nRomans 8:28-39\n\n[Sermon Outline]\n1. Called According to His Purpose\n2. Conformed to the Image of His Son\n3. More Than Conquerors\n\n[Prayer & Reflection]\nA time of silent meditation\n\n[Closing Hymn]\nAmazing Grace (Hymn 412)";
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Successfully imported "Sunday_Service_Romans8.docx"!'),
                    ),
                  );
                },
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: SacredColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SacredColors.outlineVariant, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 40, color: primaryColor),
                      const SizedBox(height: 8),
                      Text('Choose file or drag here', style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('PDF, DOCX, TXT up to 10MB', style: SacredTypography.labelSm(context).copyWith(color: SacredColors.outline)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Or select from sample documents:', style: SacredTypography.labelLg(context).copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                title: Text('Sermon_Stillness.pdf', style: SacredTypography.labelLg(context)),
                subtitle: Text('245 KB', style: SacredTypography.labelSm(context)),
                onTap: () {
                  controller.text = "[Call to Worship]\nPsalm 46:10 - \"Be still, and know that I am God\"\n\n[Sermon Title]\nThe Grace of Stillness\n\n[Scripture Exposition]\n1. Stillness in the Storm (Mark 4:39)\n2. Stillness in Service (Luke 10:41)\n3. Stillness in Sovereignty (Exodus 14:14)\n\n[Benediction]";
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully imported "Sermon_Stillness.pdf"')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Colors.blue, size: 28),
                title: Text('Worship_Order.docx', style: SacredTypography.labelLg(context)),
                subtitle: Text('180 KB', style: SacredTypography.labelSm(context)),
                onTap: () {
                  controller.text = "[Prelude]\nImmortal, Invisible, God Only Wise\n\n[Invocation]\nLead pastor opening prayer\n\n[Hymn of Praise]\nHow Great Thou Art\n\n[Benediction]";
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully imported "Worship_Order.docx"')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Presentation',
            style: SacredTypography.headlineLg(context).copyWith(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Paste your service outline below to begin generating your slides.',
            style: SacredTypography.bodyMd(context).copyWith(color: SacredColors.onSurfaceVariant),
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: SacredColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SacredColors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_list_bulleted, color: SacredColors.outline, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'SERVICE OUTLINE',
                            style: SacredTypography.labelLg(context).copyWith(
                              color: SacredColors.outline,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text('Import DOCX/PDF/TXT', style: SacredTypography.labelLg(context).copyWith(color: primaryColor)),
                        onPressed: () => _importOutlineFile(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      style: SacredTypography.bodyLg(context).copyWith(
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: '[Prelude]\nMajesty (Hymn 124)\n...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------ Right: Style Selector Pane ------------------------
class _StyleSelectorPane extends StatelessWidget {
  final List<ThemeCardData> themes;
  final String selectedTheme;
  final ValueChanged<String> onThemeSelect;
  final VoidCallback onGenerate;
  final bool isGenerating;
  final Color primaryColor;

  const _StyleSelectorPane({
    required this.themes,
    required this.selectedTheme,
    required this.onThemeSelect,
    required this.onGenerate,
    required this.isGenerating,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SacredColors.surfaceContainerLow,
      padding: EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Style Selector',
            style: SacredTypography.headlineMd(context).copyWith(
              fontWeight: FontWeight.bold,
              color: SacredColors.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Choose a visual theme for this service.',
            style: SacredTypography.labelLg(context).copyWith(color: SacredColors.onSurfaceVariant),
          ),
          SizedBox(height: 32),
          
          Expanded(
            child: ListView.separated(
              itemCount: themes.length,
              separatorBuilder: (context, index) => SizedBox(height: 16),
              itemBuilder: (context, idx) {
                final card = themes[idx];
                final isSelected = card.name == selectedTheme;
                return _ThemeSelectionCard(
                  data: card,
                  isSelected: isSelected,
                  onTap: () => onThemeSelect(card.name),
                  primaryColor: primaryColor,
                );
              },
            ),
          ),
          SizedBox(height: 24),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: isGenerating ? null : onGenerate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isGenerating)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else ...[
                  Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Generate Slides',
                    style: SacredTypography.headlineMd(context).copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              ],
            ),
          ),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Estimated time: 15-20 seconds',
              style: TextStyle(color: SacredColors.outline, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------ Theme Selection Card ------------------------
class _ThemeSelectionCard extends StatefulWidget {
  final ThemeCardData data;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const _ThemeSelectionCard({
    required this.data,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  State<_ThemeSelectionCard> createState() => _ThemeSelectionCardState();
}

class _ThemeSelectionCardState extends State<_ThemeSelectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: SacredColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? widget.primaryColor
                  : SacredColors.outlineVariant,
              width: widget.isSelected ? 2.5 : 1.0,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    )
                  ]
                : (_isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                child: SizedBox(
                  height: 120,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: _isHovered ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          child: Image.network(
                            widget.data.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: SacredColors.surfaceContainerLow,
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black38],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.name,
                      style: SacredTypography.labelLg(context).copyWith(
                        color: widget.isSelected ? widget.primaryColor : SacredColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.data.description,
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
    );
  }
}

// ------------------------ Model ------------------------
class ThemeCardData {
  final String name;
  final String description;
  final String imageUrl;
  final String imageAlt;

  ThemeCardData({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.imageAlt,
  });
}
