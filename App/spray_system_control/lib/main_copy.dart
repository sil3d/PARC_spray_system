import 'dart:developer'; // Use 'log' instead of 'print' for better debugging
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_joystick/flutter_joystick.dart';

// --- Base URL of the ESP32 ---
const String esp32BaseUrl = 'http://192.168.4.1';

// --- System State Management Class ---
class SystemState {
  String mode = 'manual';
  bool isSystemRunning = false;
  bool isMiniPump1On = false;
  bool isMiniPump2On = false;
  bool isMainPumpOn = false;
  int servoPan1Angle = 0;
  int servoPan2Angle = 0;
  int servoTilt1Angle = 0;
  int servoTilt2Angle = 0;
  double? temperature;
}

// --- Main Dashboard Widget ---
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key}); // Corrected: use super parameters

  @override
  State<DashboardPage> createState() => _DashboardPageState(); // Corrected: private type
}

class _DashboardPageState extends State<DashboardPage> {
  final SystemState _systemState = SystemState();
  Timer? _telemetryTimer;
  bool _isConnecting = false;

  final TextEditingController _pan1AngleController = TextEditingController(
    text: '0',
  );
  final TextEditingController _tilt1AngleController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _startTelemetryTimer();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pan1AngleController.dispose();
    _tilt1AngleController.dispose();
    super.dispose();
  }

  // --- HTTP Command and Telemetry Functions ---

  Future<void> _sendCommand(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    if (_isConnecting) return;

    if (mounted) setState(() => _isConnecting = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Uri uri = Uri.parse(
      '$esp32BaseUrl/$endpoint',
    ).replace(queryParameters: params);
    log('Sending command: $uri');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        log('Command sent successfully: $endpoint');
        await _fetchTelemetry(); // Wait for telemetry to update state
      } else {
        log('Command failed: ${response.statusCode} ${response.reasonPhrase}');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Command failed: ${response.statusCode}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      log('Error sending command: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Connection Error: Is the robot connected?'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _fetchTelemetry() async {
    Uri uri = Uri.parse('$esp32BaseUrl/telemetry');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _systemState.mode = data['mode'] ?? 'manual';
            _systemState.isSystemRunning = data['system_running'] ?? false;
            _systemState.isMiniPump1On = data['mini_pump1_on'] ?? false;
            _systemState.isMiniPump2On = data['mini_pump2_on'] ?? false;
            _systemState.isMainPumpOn = data['main_pump_on'] ?? false;
            _systemState.servoPan1Angle = data['servo_pan1_angle'] ?? 0;
            _systemState.servoPan2Angle = data['servo_pan2_angle'] ?? 0;
            _systemState.servoTilt1Angle = data['servo_tilt1_angle'] ?? 0;
            _systemState.servoTilt2Angle = data['servo_tilt2_angle'] ?? 0;
            _systemState.temperature = data['temperature']?.toDouble();
          });
        }
      }
    } catch (e) {
      log('Error fetching telemetry: $e');
    }
  }

  void _startTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnecting && mounted) {
        _fetchTelemetry();
      }
    });
  }

  // --- UI Interaction Handlers ---

  void _onModeChanged(bool isAuto) {
    _sendCommand('setMode', params: {'mode': isAuto ? 'auto' : 'manual'});
  }

  void _onPumpControl(String pumpId, bool state) {
    if (_systemState.mode == 'manual') {
      // Corrected: access state via property
      _sendCommand(
        'setPumps',
        params: {'pump': pumpId, 'state': state ? 'on' : 'off'},
      );
    }
  }

  void _onEmergencyStop() {
    _sendCommand('stopSystem');
  }

  // --- Joystick & Manual Angle Handlers ---
  void _onJoystickUpdate(double panX, double panY, double tiltX, double tiltY) {
    if (_systemState.mode == 'manual') {
      // Corrected: access state via property
      _sendCommand(
        'joystick',
        params: {
          'panX': panX.toStringAsFixed(2),
          'panY': panY.toStringAsFixed(2),
          'tiltX': tiltX.toStringAsFixed(2),
          'tiltY': tiltY.toStringAsFixed(2),
        },
      );
    }
  }

  void _setServoAngleFromInput(String servoId, String angleString) {
    if (_systemState.mode == 'manual') {
      // Corrected: access state via property
      int? angle = int.tryParse(angleString);
      if (angle != null && angle >= 0 && angle <= 180) {
        _sendCommand(
          'setServo',
          params: {'id': servoId, 'angle': angle.toString()},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid angle for $servoId: Must be 0-180.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  // --- Main UI Build Method ---
  @override
  Widget build(BuildContext context) {
    // Determine if controls should be enabled based on mode
    final bool isManualMode = _systemState.mode == 'manual';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spray System Dashboard'),
        backgroundColor: Colors.green[800],
        actions: [
          if (_isConnecting)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[200]!, Colors.grey[400]!],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildModeControlCard(),
              const SizedBox(height: 16),
              _buildPumpControlCard(isManualMode),
              const SizedBox(height: 16),
              _buildServoControlCard(isManualMode),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _onEmergencyStop,
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('EMERGENCY STOP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for UI ---

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mode: ${_systemState.mode.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _systemState.mode == 'auto'
                        ? Colors.blueAccent
                        : Colors.black87,
                  ),
                ),
                Text(
                  'Running: ${_systemState.isSystemRunning ? "YES" : "NO"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _systemState.isSystemRunning
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Temperature: ${_systemState.temperature != null ? "${_systemState.temperature?.toStringAsFixed(1)}°C" : "N/A"}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operation Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _systemState.mode == 'auto'
                      ? null
                      : () => _onModeChanged(true),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('AUTO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _systemState.mode == 'auto'
                        ? Colors.blueAccent
                        : Colors.grey[300],
                    foregroundColor: _systemState.mode == 'auto'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _systemState.mode == 'manual'
                      ? null
                      : () => _onModeChanged(false),
                  icon: const Icon(Icons.pan_tool),
                  label: const Text('MANUAL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _systemState.mode == 'manual'
                        ? Colors.blueAccent
                        : Colors.grey[300],
                    foregroundColor: _systemState.mode == 'manual'
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpControlCard(bool isManualMode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pump Control (Manual Mode)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildPumpSwitch(
              'Main Pump',
              _systemState.isMainPumpOn,
              (state) => _onPumpControl('main', state),
              enabled: isManualMode,
            ),
            _buildPumpSwitch(
              'Mini Pump 1',
              _systemState.isMiniPump1On,
              (state) => _onPumpControl('mini1', state),
              enabled: isManualMode,
            ),
            _buildPumpSwitch(
              'Mini Pump 2',
              _systemState.isMiniPump2On,
              (state) => _onPumpControl('mini2', state),
              enabled: isManualMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpSwitch(
    String label,
    bool isOn,
    ValueChanged<bool> onChanged, {
    required bool enabled,
  }) {
    return SwitchListTile(
      title: Text(label),
      value: isOn,
      onChanged: enabled ? onChanged : null,
      activeColor: Colors.green,
    );
  }

  Widget _buildServoControlCard(bool isManualMode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Servo Control (Manual Mode)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pan Joystick
                Column(
                  children: [
                    const Text('Pan Axis'),
                    const SizedBox(height: 8),
                    Joystick(
                      // Corrected: Properties passed directly to the constructor
                      base: CircleAvatar(
                        backgroundColor: isManualMode
                            ? Colors.blue[100]
                            : Colors.grey[300],
                      ),
                      stick: CircleAvatar(
                        backgroundColor: isManualMode
                            ? Colors.blue[700]
                            : Colors.grey[500],
                      ),
                      listener: (details) {
                        if (isManualMode) {
                          _onJoystickUpdate(details.x, details.y, 0, 0);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pan 1: ${_systemState.servoPan1Angle}°\nPan 2: ${_systemState.servoPan2Angle}°',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                // Tilt Joystick
                Column(
                  children: [
                    const Text('Tilt Axis'),
                    const SizedBox(height: 8),
                    Joystick(
                      // Corrected: Properties passed directly to the constructor
                      base: CircleAvatar(
                        backgroundColor: isManualMode
                            ? Colors.green[100]
                            : Colors.grey[300],
                      ),
                      stick: CircleAvatar(
                        backgroundColor: isManualMode
                            ? Colors.green[700]
                            : Colors.grey[500],
                      ),
                      listener: (details) {
                        if (isManualMode) {
                          _onJoystickUpdate(0, 0, details.x, details.y);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tilt 1: ${_systemState.servoTilt1Angle}°\nTilt 2: ${_systemState.servoTilt2Angle}°',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Set Specific Angle:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildAngleInputRow(
              'Pan 1',
              _pan1AngleController,
              'pan1',
              enabled: isManualMode,
            ),
            _buildAngleInputRow(
              'Tilt 1',
              _tilt1AngleController,
              'tilt1',
              enabled: isManualMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngleInputRow(
    String label,
    TextEditingController controller,
    String servoId, {
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$label (0-180°):')),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              enabled: enabled,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: enabled ? 'Angle' : 'Auto',
              ),
              onSubmitted: (value) => _setServoAngleFromInput(servoId, value),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: enabled
                ? () => _setServoAngleFromInput(servoId, controller.text)
                : null,
            child: const Text('SET'),
          ),
        ],
      ),
    );
  }
}

// --- Main Application Entry Point ---
class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Corrected: use super parameters

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spray System Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        // Corrected: use CardThemeData
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(const MyApp());
}
