import 'package:flutter/material.dart';
import 'display_manager.dart';
import 'presentation_controller.dart';
import 'dashboard_page.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Developer Diagnostics', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF151528),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Rescan Monitors',
            onPressed: () async {
              await DisplayManager.instance.refreshDisplays();
            },
          ),
        ],
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: DisplayManager.instance,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: PresentationController.instance,
            builder: (context, _) {
              final dm = DisplayManager.instance;
              final pc = PresentationController.instance;

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Displays & Control
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'DISPLAYS DETECTED'),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: dm.displays.length,
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final disp = dm.displays[index];
                                final isSelected = dm.selectedDisplay?.id == disp.id;
                                return Card(
                                  color: isSelected ? const Color(0xFF25254A) : const Color(0xFF1A1A2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected ? Colors.green : Colors.white10,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      disp.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      '${disp.resolution} • ${disp.refreshRate}Hz • ${disp.isPrimary ? "Primary Display" : "Secondary Display"}',
                                      style: const TextStyle(color: Colors.white60),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : TextButton(
                                            onPressed: () => dm.selectDisplay(disp.id),
                                            child: const Text('Select Target'),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'SIMULATION CONTROLS'),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Simulate Audience Display', style: TextStyle(color: Colors.white)),
                            subtitle: const TextStyle(color: Colors.white60) != null
                                ? const Text('Creates a floating preview window on primary display', style: TextStyle(color: Colors.white60))
                                : null,
                            value: dm.simulateAudience,
                            onChanged: (val) => dm.setSimulateAudience(val),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  dm.simulateConnect(DisplayInfo(
                                    id: 'disp_${DateTime.now().millisecondsSinceEpoch}',
                                    name: 'External Projector/TV',
                                    width: 1920,
                                    height: 1080,
                                    isPrimary: false,
                                    refreshRate: 60,
                                  ));
                                },
                                child: const Text('Simulate Display Connect'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                onPressed: () {
                                  if (dm.displays.length > 1) {
                                    dm.simulateDisconnect(dm.displays.last.id);
                                  }
                                },
                                child: const Text('Simulate Disconnect'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Column: State & Logs
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'CURRENT PRESENTATION TARGET'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildStateRow('Presenter Window', 'Display 1 (Primary)'),
                                const Divider(color: Colors.white12),
                                _buildStateRow('Audience Window', dm.simulateAudience ? 'Simulated Preview' : dm.selectedDisplay?.name ?? 'Not Connected'),
                                const Divider(color: Colors.white12),
                                _buildStateRow('Current Slide', 'Index ${pc.presenterIndex + 1} of ${pc.slides.length}'),
                                const Divider(color: Colors.white12),
                                _buildStateRow('Audience Live Slide', 'Index ${pc.liveIndex + 1} of ${pc.slides.length}'),
                                const Divider(color: Colors.white12),
                                _buildStateRow('Sync State', pc.mode == PresentationMode.rehearsal ? 'REHEARSAL (FROZEN)' : 'CONNECTED (LIVE)'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle(context, 'OPERATION LOGS'),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ListView.builder(
                                itemCount: dm.logs.length,
                                itemBuilder: (context, index) {
                                  // Show latest logs first
                                  final log = dm.logs[dm.logs.length - 1 - index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Text(
                                      log,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
