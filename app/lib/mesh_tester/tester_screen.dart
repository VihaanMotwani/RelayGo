import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/location_service.dart';
import 'ai_page.dart';
import 'demo_data.dart';
import 'dummy_data.dart';
import 'gemma_service.dart';
import 'home_page.dart';
import 'instrumented_mesh_service.dart';
import 'log_page.dart';
import 'log_service.dart';
import 'messages_page.dart';
import 'settings_page.dart';

/// Root shell for the RelayGo app.
///
/// Manages shared state and provides a 4-tab bottom navigation:
///   Home — Messages — Log — Settings
class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  final InstrumentedMeshService _mesh = InstrumentedMeshService.create();
  final LogService _log = LogService.instance;
  final ScrollController _logScrollController = ScrollController();
  final GemmaService _gemma = GemmaService();

  List<LogEntry> _logEntries = [];
  bool _meshRunning = false;
  bool _dataPreloaded = false;
  String _adapterName = '...';
  int _currentTab = 0;
  double? _lat;
  double? _lng;

  StreamSubscription? _logSub;
  StreamSubscription? _statsSub;

  @override
  void initState() {
    super.initState();
    _mesh.getDeviceAddress().then((name) {
      if (mounted) setState(() => _adapterName = name);
    });
    _logSub = _log.onNewEntry.listen((_) {
      setState(() {
        _logEntries = _log.entries;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    });
    _statsSub = _mesh.onStatsChanged.listen((_) {
      setState(() {});
    });

    // Initialize Gemma LLM
    _gemma.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _statsSub?.cancel();
    _mesh.dispose();
    _gemma.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // ─── Actions ───

  Future<bool> _requestPermissions() async {
    _log.info('Requesting BLE permissions...');

    List<Permission> permissionsToRequest = [];
    if (Platform.isIOS) {
      permissionsToRequest = [Permission.location, Permission.bluetooth];
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

    final locationEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!locationEnabled) {
      _log.error(
        '⚠️ Location Services are DISABLED. BLE scanning needs GPS on Android ≤11.',
      );
      _log.error(
        'Please enable Location (GPS) in your device Settings and try again.',
      );
      await openAppSettings();
      return false;
    }
    _log.info('Location Services enabled ✅');

    return true;
  }

  Future<void> _toggleMesh() async {
    if (_meshRunning) {
      await _mesh.stop();
      setState(() => _meshRunning = false);
    } else {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        _log.error('Cannot start mesh without required permissions.');
        return;
      }

      // Fetch real GPS coordinates before starting the mesh
      _log.info('📍 Fetching device location...');
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
        _log.info(
          '📍 Location acquired: ${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)} '
          '(accuracy: ${position.accuracy.toStringAsFixed(1)}m)',
        );
      } else {
        _log.error(
          '⚠️ Could not acquire GPS location — packets will use fallback coords.',
        );
      }

      setState(() => _meshRunning = true);
      await _mesh.start();
    }
  }

  Future<void> _preloadData() async {
    if (_dataPreloaded) {
      _log.info('Data already preloaded — skipping');
      return;
    }
    final reports = DummyData.generateReports(lat: _lat, lng: _lng);
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

  void _clearLog() {
    _log.clear();
    setState(() => _logEntries = []);
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitle(_currentTab)),
        actions: [
          if (_currentTab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _PeerBadge(
                key: ValueKey('peer-$_meshRunning'),
                isRunning: _meshRunning,
                peerCount: _mesh.peerCount,
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          HomePage(
            mesh: _mesh,
            meshRunning: _meshRunning,
            onToggleMesh: _toggleMesh,
            lat: _lat,
            lng: _lng,
          ),
          AiPage(gemma: _gemma),
          MessagesPage(mesh: _mesh),
          LogPage(
            entries: _logEntries,
            scrollController: _logScrollController,
            onClear: _clearLog,
          ),
          SettingsPage(
            adapterName: _adapterName,
            storedCount: _mesh.storedPacketIds.length,
            dataPreloaded: _dataPreloaded,
            meshRunning: _meshRunning,
            onPreloadData: _preloadData,
            onResetDb: _resetDb,
            onClearLog: _clearLog,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.cell_tower_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy_rounded),
              label: 'AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_rounded),
              label: 'Log',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return 'RelayGo';
      case 1:
        return 'Assistant';
      case 2:
        return 'Messages';
      case 3:
        return 'Log';
      case 4:
        return 'Settings';
      default:
        return 'RelayGo';
    }
  }
}

// ── Peer Badge ──

class _PeerBadge extends StatelessWidget {
  final bool isRunning;
  final int peerCount;

  const _PeerBadge({
    super.key,
    required this.isRunning,
    required this.peerCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? Colors.green.shade600 : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isRunning ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRunning
                ? Icons.bluetooth_connected_rounded
                : Icons.bluetooth_disabled_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isRunning ? '$peerCount peers' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
