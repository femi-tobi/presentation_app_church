import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'settings_state.dart';
import 'dashboard_page.dart'; // SacredColors, SacredTypography, TopNavBar
import 'presentation_controller.dart';

class TimerPage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const TimerPage({super.key, required this.scaffoldKey});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = AppSettings.instance;
    _minutesController.text = (settings.timerDurationSeconds ~/ 60).toString();
    _secondsController.text = (settings.timerDurationSeconds % 60).toString();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _applyDuration() {
    final mins = int.tryParse(_minutesController.text) ?? 0;
    final secs = int.tryParse(_secondsController.text) ?? 0;
    final totalSecs = (mins * 60) + secs;
    if (totalSecs > 0) {
      AppSettings.instance.timerDurationSeconds = totalSecs;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timer set to $mins minutes and $secs seconds'),
          backgroundColor: SacredColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;

    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        final int remaining = settings.timerRemainingSeconds;
        final String minutes = (remaining ~/ 60).floor().toString().padLeft(2, '0');
        final String seconds = (remaining % 60).toString().padLeft(2, '0');

        return Column(
          children: [
            TopNavBar(
              scaffoldKey: widget.scaffoldKey,
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
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Countdown Control Deck',
                            style: SacredTypography.headlineLg(context).copyWith(
                              fontWeight: FontWeight.bold,
                              color: SacredColors.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Configure, adjust, and present live timers to your audience display.',
                            style: SacredTypography.bodyMd(context).copyWith(
                              color: SacredColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Configurations & Controls
                              Expanded(
                                flex: 3,
                                child: Card(
                                  color: SacredColors.surfaceContainerLow,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: SacredColors.outlineVariant),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Large Timer Display
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: SacredColors.outlineVariant),
                                            ),
                                            child: Text(
                                              '$minutes:$seconds',
                                              style: GoogleFonts.firaCode(
                                                fontSize: 72,
                                                fontWeight: FontWeight.bold,
                                                color: settings.isTimerRunning ? Colors.orangeAccent : SacredColors.onBackground,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),

                                        // Edit Duration
                                        Text('Set Timer Duration', style: SacredTypography.labelLg(context)),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _minutesController,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: 'Minutes',
                                                  filled: true,
                                                  fillColor: SacredColors.surface,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: TextField(
                                                controller: _secondsController,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: 'Seconds',
                                                  filled: true,
                                                  fillColor: SacredColors.surface,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: SacredColors.primary,
                                                foregroundColor: SacredColors.onPrimary,
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: _applyDuration,
                                              child: const Text('Apply'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 32),

                                        // Play/Pause/Reset Controls
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _controlButton(
                                              icon: settings.isTimerRunning ? Icons.pause : Icons.play_arrow,
                                              label: settings.isTimerRunning ? 'Pause' : 'Start',
                                              color: settings.isTimerRunning ? Colors.amber : Colors.green,
                                              onPressed: () {
                                                if (settings.isTimerRunning) {
                                                  settings.stopCountdown();
                                                } else {
                                                  settings.startCountdown();
                                                }
                                              },
                                            ),
                                            _controlButton(
                                              icon: Icons.replay,
                                              label: 'Reset',
                                              color: Colors.blue,
                                              onPressed: settings.resetCountdown,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 32),
                                        Divider(color: SacredColors.outlineVariant),
                                        const SizedBox(height: 16),

                                        // PIP Overlay Switch & Sizers
                                        SwitchListTile(
                                          title: Text(
                                            'Show Timer Overlay on Screen',
                                            style: SacredTypography.labelLg(context),
                                          ),
                                          subtitle: const Text('Overlay timer PIP on live display'),
                                          value: settings.showTimerOnAudience,
                                          onChanged: (val) {
                                            settings.showTimerOnAudience = val;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        Text('Timer PIP Size Adjustments', style: SacredTypography.labelLg(context)),
                                        const SizedBox(height: 16),
                                        _sliderRow(
                                          label: 'Width',
                                          value: settings.timerOverlayWidth,
                                          min: 120.0,
                                          max: 400.0,
                                          onChanged: (val) => settings.timerOverlayWidth = val,
                                        ),
                                        _sliderRow(
                                          label: 'Height',
                                          value: settings.timerOverlayHeight,
                                          min: 50.0,
                                          max: 200.0,
                                          onChanged: (val) => settings.timerOverlayHeight = val,
                                        ),
                                        _sliderRow(
                                          label: 'Font Size',
                                          value: settings.timerOverlayFontSize,
                                          min: 14.0,
                                          max: 64.0,
                                          onChanged: (val) => settings.timerOverlayFontSize = val,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),

                              // Right Column: Live Presentation View Overlay Preview
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Screen Overlay Preview',
                                      style: SacredTypography.labelLg(context),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 300,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: SacredColors.outlineVariant, width: 2),
                                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Simulated Active Presenting Slide Content
                                          ListenableBuilder(
                                            listenable: PresentationController.instance,
                                            builder: (context, _) {
                                              final pc = PresentationController.instance;
                                              if (pc.slides.isNotEmpty && pc.liveIndex < pc.slides.length) {
                                                final slide = pc.slides[pc.liveIndex];
                                                return Center(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(24.0),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          slide.title,
                                                          textAlign: TextAlign.center,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white70,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 12),
                                                        Text(
                                                          slide.subtitle,
                                                          textAlign: TextAlign.center,
                                                          maxLines: 4,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 18,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Center(
                                                child: Text(
                                                  'Simulated Audience Screen\n(No Active Slide)',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.white38),
                                                ),
                                              );
                                            },
                                          ),

                                          // Simulated Timer PIP Overlay
                                          if (settings.showTimerOnAudience && settings.isTimerRunning && settings.timerRemainingSeconds > 0)
                                            Positioned(
                                              right: 16,
                                              top: 16,
                                              child: Container(
                                                width: settings.timerOverlayWidth * 0.7,
                                                height: settings.timerOverlayHeight * 0.7,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.85),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.white24),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.timer, color: Colors.orangeAccent, size: settings.timerOverlayFontSize * 0.6),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$minutes:$seconds',
                                                      style: GoogleFonts.firaCode(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: settings.timerOverlayFontSize * 0.7,
                                                        color: Colors.orangeAccent,
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onPressed,
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              value.toStringAsFixed(0),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
