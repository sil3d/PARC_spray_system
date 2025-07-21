import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/esp32_api_service.dart';
import '../models/system_state.dart';

class DashboardProvider with ChangeNotifier {
  final Esp32ApiService _apiService = Esp32ApiService();
  final SystemState _systemState = SystemState();
  Timer? _telemetryTimer;
  bool _isConnecting = false;

  int _lastJoystickSendTime = 0;
  static const int joystickThrottleInterval = 100;

  double _panMinAngle = 0;
  double _panMaxAngle = 180;
  double _tiltMinAngle = 30;
  double _tiltMaxAngle = 150;

  SystemState get systemState => _systemState;
  bool get isConnecting => _isConnecting;
  double get panMinAngle => _panMinAngle;
  double get panMaxAngle => _panMaxAngle;
  double get tiltMinAngle => _tiltMinAngle;
  double get tiltMaxAngle => _tiltMaxAngle;

  DashboardProvider() {
    _startTelemetryTimer();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTelemetry() async {
    final response = await _apiService.fetchTelemetry();
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _systemState.mode = data['mode'] ?? 'manual';
      _systemState.isSystemRunning = data['system_running'] ?? false;
      // <<< AJOUTS ICI >>>
      _systemState.isManualSweepActive = data['manual_sweep_active'] ?? false;
      _systemState.isTemperatureAlert = data['temperature_alert'] ?? false;
      // <<< FIN DES AJOUTS >>>
      _systemState.isMiniPump1On = data['mini_pump1_on'] ?? false;
      _systemState.isMiniPump2On = data['mini_pump2_on'] ?? false;
      _systemState.isMainPumpOn = data['main_pump_on'] ?? false;
      _systemState.servoPan1Angle = data['servo_pan1_angle'] ?? 90;
      _systemState.servoPan2Angle = data['servo_pan2_angle'] ?? 90;
      _systemState.servoTilt1Angle = data['servo_tilt1_angle'] ?? 90;
      _systemState.servoTilt2Angle = data['servo_tilt2_angle'] ?? 90;
      _systemState.temperature = data['temperature']?.toDouble();
      _systemState.humidity = data['humidity']?.toDouble();
      notifyListeners();
    }
  }

  void _startTelemetryTimer() {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isConnecting) {
        _fetchTelemetry();
      }
    });
  }

  Future<void> _executeCommand(
    String endpoint, {
    Map<String, String>? params,
    bool showIndicator = false,
  }) async {
    if (showIndicator) {
      _isConnecting = true;
      notifyListeners();
    }

    final response = await _apiService.sendCommand(endpoint, params: params);

    if (showIndicator) {
      _isConnecting = false;
    }

    if (response != null && response.statusCode == 200) {
      await _fetchTelemetry(); // Toujours mettre à jour l'état après une commande réussie
    } else {
      notifyListeners(); // Mettre à jour pour enlever l'indicateur même en cas d'échec
    }
  }

  void changeMode(bool isAuto) => _executeCommand(
    'setMode',
    params: {'mode': isAuto ? 'auto' : 'manual'},
    showIndicator: true,
  );
  void emergencyStop() => _executeCommand('stopSystem', showIndicator: true);

  void controlPump(String pumpId, bool state) {
    if (systemState.mode == 'manual') {
      _executeCommand(
        'setPumps',
        params: {'pump': pumpId, 'state': state ? 'on' : 'off'},
      );
    }
  }

  void controlJoystick(double panX, double tiltY) {
    if (systemState.mode == 'manual' && !systemState.isManualSweepActive) {
      if (DateTime.now().millisecondsSinceEpoch - _lastJoystickSendTime <
          joystickThrottleInterval) {
        return;
      }
      _lastJoystickSendTime = DateTime.now().millisecondsSinceEpoch;

      _executeCommand(
        'joystick',
        params: {
          'panX': panX.toStringAsFixed(2),
          'tiltY': tiltY.toStringAsFixed(2),
          'panY': '0.0',
          'tiltX': '0.0',
        },
      );
    }
  }

  void toggleManualSweep(bool enable) {
    if (systemState.mode == 'manual') {
      _executeCommand(
        'setManualSweep',
        params: {'state': enable ? 'on' : 'off'},
        showIndicator: true,
      );
    }
  }

  void updateServoLimits(
    double panMin,
    double panMax,
    double tiltMin,
    double tiltMax,
  ) {
    _panMinAngle = panMin;
    _panMaxAngle = panMax;
    _tiltMinAngle = tiltMin;
    _tiltMaxAngle = tiltMax;
    _executeCommand(
      'setServoLimits',
      params: {
        'panMin': panMin.round().toString(),
        'panMax': panMax.round().toString(),
        'tiltMin': tiltMin.round().toString(),
        'tiltMax': tiltMax.round().toString(),
      },
    );
    notifyListeners();
  }
}
