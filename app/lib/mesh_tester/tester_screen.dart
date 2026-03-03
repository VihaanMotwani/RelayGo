import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'demo_data.dart';
import 'dummy_data.dart';
import 'instrumented_mesh_service.dart';
import 'log_service.dart';

/// Full-screen tester UI for BLE mesh validation.
///
/// Layout:
///   - Peer count indicator (top bar)
///   - Summary card (reports/messages stored + received counts)
///   - Control buttons (Preload Data, Start Mesh, Stop Mesh, Clear Log)
///   - Live scrolling log panel
class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  final InstrumentedMeshService _mesh = InstrumentedMeshService.create();
  final LogService _log = LogService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  List<LogEntry> _logEntries = [];
  bool _meshRunning = false;
  bool _dataPreloaded = false;
  String _adapterName = '...';

  StreamSubscription? _logSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    // Fetch adapter name
    _mesh.getDeviceAddress().then((name) {
      if (mounted) setState(() => _adapterName = name);
    });
    _logSub = _log.onNewEntry.listen((_) {
      setState(() {
        _logEntries = _log.entries;
      });
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    });
    _statsSub = _mesh.onStatsChanged.listen((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _statsSub?.cancel();
    _mesh.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    _log.info('Requesting BLE permissions...');

    List<Permission> permissionsToRequest = [];
    if (Platform.isIOS) {
      permissionsToRequest = [
        Permission.location,
        Permission.bluetooth, // iOS uses a single generic Bluetooth permission
      ];
    } else {
      permissionsToRequest = [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ];
    }

    Map<Permission, PermissionStatus> statuses = await permissionsToRequest
        .request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        _log.error('${permission.toString()} not granted: $status');
        allGranted = false;
      } else {
        _log.info('${permission.toString()} → granted ✅');
      }
    });

    if (!allGranted) return false;

    // Android ≤11 requires Location Services (GPS) to be ENABLED, not just
    // the permission granted. Without this, startScan() throws a
    // PlatformException("Location services are required").
    final locationEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!locationEnabled) {
      _log.error(
        '⚠️ Location Services are DISABLED. BLE scanning needs GPS on Android ≤11.',
      );
      _log.error(
        'Please enable Location (GPS) in your device Settings and try again.',
      );
      // Try to open the location settings
      await openAppSettings();
      return false;
    }
    _log.info('Location Services enabled ✅');

    return true;
  }

  Future<void> _handleSpoofedInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    _log.info('[User] "$text"');

    // Simulate LLM processing delay
    setState(() => _dataPreloaded = true); // Repurpose flag as "isProcessing"
    await Future.delayed(const Duration(milliseconds: 1500));

    final packet = DemoData.getNextPacket();
    if (packet == null) {
      _log.error(
        '[AI] Error: No more demo scenarios available. Reset DB to restart sequence.',
      );
      setState(() => _dataPreloaded = false);
      return;
    }

    final urg = packet.isReport ? packet.report!.urg : 0;
    _log.info(
      '[AI] Extracted: kind=${packet.kind} urg=$urg type=${packet.isReport ? packet.report!.type : 'broadcast'}',
    );

    // Sideload into MeshNet
    if (packet.isReport) {
      await _mesh.preloadReports([packet.report!]);
    } else if (packet.isMessage) {
      await _mesh.preloadMessages([packet.message!]);
    }

    await _mesh.refreshStoredIds();
    setState(() => _dataPreloaded = false);
  }

  Future<void> _preloadData() async {
    if (_dataPreloaded) {
      _log.info('Data already preloaded — skipping');
      return;
    }
    final reports = DummyData.generateReports();
    final messages = DummyData.generateMessages();
    await _mesh.preloadReports(reports);
    await _mesh.preloadMessages(messages);
    setState(() => _dataPreloaded = true);
    _log.info(
      '✅ Preloaded ${reports.length} reports + ${messages.length} messages',
    );
  }

  Future<void> _resetDb() async {
    await _mesh.resetDatabase();
    DemoData.reset();
    setState(() => _dataPreloaded = false);
  }

  Future<void> _startMesh() async {
    if (_meshRunning) return;

    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      _log.error('Cannot start mesh without required permissions.');
      return;
    }

    setState(() => _meshRunning = true);
    await _mesh.start();
  }

  Future<void> _stopMesh() async {
    if (!_meshRunning) return;
    await _mesh.stop();
    setState(() => _meshRunning = false);
  }

  void _clearLog() {
    _log.clear();
    setState(() => _logEntries = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RelayGo Mesh Tester',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontSize: 16,
              ),
            ),
            Text(
              'BT: $_adapterName',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
            ),
          ],
        ),
        actions: [
          // Peer count indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _meshRunning
                  ? const Color(0xFF238636).withAlpha(50)
                  : const Color(0xFF30363D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _meshRunning
                    ? const Color(0xFF238636)
                    : const Color(0xFF484F58),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _meshRunning
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  size: 16,
                  color: _meshRunning
                      ? const Color(0xFF3FB950)
                      : const Color(0xFF8B949E),
                ),
                const SizedBox(width: 6),
                Text(
                  _meshRunning ? '${_mesh.peerCount} peers' : 'Offline',
                  style: TextStyle(
                    fontSize: 13,
                    color: _meshRunning
                        ? const Color(0xFF3FB950)
                        : const Color(0xFF8B949E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary Card ──
          _buildSummaryCard(),

          // ── Control Buttons ──
          _buildControlBar(),

          // ── Log Panel ──
          Expanded(child: _buildLogPanel()),

          // ── Spoofed AI Input Bar ──
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ).copyWith(bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_dataPreloaded, // Disabled while processing
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: _dataPreloaded
                    ? 'AI is extracting context...'
                    : 'Report an emergency via AI...',
                hintStyle: const TextStyle(color: Color(0xFF8B949E)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF30363D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                ),
              ),
              onSubmitted: (_) => _handleSpoofedInput(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF238636),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _dataPreloaded
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _dataPreloaded ? null : _handleSpoofedInput,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final ids = _mesh.storedPacketIds;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SQLite: ${ids.length} packets',
                style: const TextStyle(
                  color: Color(0xFFD2A8FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'Rx: ${_mesh.receivedReports}r ${_mesh.receivedMessages}m',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ],
          ),
          if (ids.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 20,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ids.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ids[i].substring(0, 8),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFFC9D1D9),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final btnWidth = (constraints.maxWidth - 8) / 2;
          return Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: btnWidth,
                    child: _ControlButton(
                      label: 'Preload Data',
                      icon: Icons.dataset,
                      color: const Color(0xFF58A6FF),
                      enabled: !_dataPreloaded,
                      onTap: _preloadData,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: btnWidth,
                    child: _ControlButton(
                      label: _meshRunning ? 'Stop Mesh' : 'Start Mesh',
                      icon: _meshRunning
                          ? Icons.stop_circle
                          : Icons.play_circle,
                      color: _meshRunning
                          ? const Color(0xFFF85149)
                          : const Color(0xFF3FB950),
                      onTap: _meshRunning ? _stopMesh : _startMesh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: btnWidth,
                    child: _ControlButton(
                      label: 'Reset DB',
                      icon: Icons.restart_alt,
                      color: const Color(0xFFF0883E),
                      enabled: !_meshRunning,
                      onTap: _resetDb,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: btnWidth,
                    child: _ControlButton(
                      label: 'Clear Log',
                      icon: Icons.delete_sweep,
                      color: const Color(0xFF8B949E),
                      onTap: _clearLog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: btnWidth,
                    child: _ControlButton(
                      label: 'Force Sync',
                      icon: Icons.cloud_upload,
                      color: const Color(0xFF8957E5),
                      onTap: () async {
                        _log.info('Manual backend sync triggered...');
                        final status = await _mesh.forceBackendSync();
                        _log.info(status);
                        await _mesh.refreshStoredIds();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: btnWidth), // empty space for symmetry
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogPanel() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Color(0xFF8B949E)),
                const SizedBox(width: 8),
                Text(
                  'Live Log — ${_logEntries.length} entries',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _logEntries.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet — tap "Preload Data" or "Start Mesh"',
                      style: TextStyle(color: Color(0xFF484F58), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: _logEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _logEntries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          entry.formatted,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _tagColor(entry.tag),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'BLE-CENTRAL':
        return const Color(0xFF58A6FF);
      case 'BLE-PERIPH':
        return const Color(0xFF3FB950);
      case 'STORE':
        return const Color(0xFFD2A8FF);
      case 'MESH':
        return const Color(0xFFF0883E);
      case 'ERROR':
        return const Color(0xFFF85149);
      case 'INFO':
        return const Color(0xFFC9D1D9);
      default:
        return const Color(0xFF8B949E);
    }
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? color.withAlpha(25) : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? color.withAlpha(100) : const Color(0xFF30363D),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled ? color : const Color(0xFF484F58),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : const Color(0xFF484F58),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
