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

  // Pour le throttling du joystick
  int _lastJoystickSendTime = 0;

  // Variables pour la calibration des servos
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

  // --- Fonctions de lecture et de commande ---

  Future<void> _fetchTelemetry() async {
    final response = await _apiService.fetchTelemetry();
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _systemState.mode = data['mode'] ?? 'manual';
      _systemState.isSystemRunning = data['system_running'] ?? false;
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
  }) async {
    _isConnecting = true;
    notifyListeners();

    final response = await _apiService.sendCommand(endpoint, params: params);

    _isConnecting = false;
    if (response != null && response.statusCode == 200) {
      await _fetchTelemetry();
    } else {
      notifyListeners();
    }
  }

  // --- Logique métier ---

  void changeMode(bool isAuto) {
    _executeCommand('setMode', params: {'mode': isAuto ? 'auto' : 'manual'});
  }

  void emergencyStop() {
    _executeCommand('stopSystem');
  }

  void controlPump(String pumpId, bool state) {
    if (systemState.mode == 'manual') {
      _executeCommand(
        'setPumps',
        params: {'pump': pumpId, 'state': state ? 'on' : 'off'},
      );
    }
  }

  void controlJoystick(double panX, double tiltY) {
    if (systemState.mode == 'manual') {
      // Throttling : n'envoie la commande que toutes les 100ms max
      if (DateTime.now().millisecondsSinceEpoch - _lastJoystickSendTime < 100) {
        return; // Trop tôt, on ignore
      }
      _lastJoystickSendTime = DateTime.now().millisecondsSinceEpoch;

      // Ici, le mapping sera plus simple, on envoie directement à l'ESP qui gère les deux servos.
      _executeCommand(
        'joystick',
        params: {
          'panX': panX.toStringAsFixed(2),
          'tiltY': tiltY.toStringAsFixed(2),
          // On pourrait garder panY et tiltX pour des fonctions futures
          'panY': '0.0',
          'tiltX': '0.0',
        },
      );
    }
  }

  void updatePanCalibration(RangeValues values) {
    _panMinAngle = values.start;
    _panMaxAngle = values.end;
    notifyListeners();
    // Potentiellement, envoyer ces nouvelles limites à l'ESP32 pour qu'il les respecte
    // _executeCommand('setPanLimits', params: {'min': '$_panMinAngle', 'max': '$_panMaxAngle'});
  }

  void updateTiltCalibration(RangeValues values) {
    _tiltMinAngle = values.start;
    _tiltMaxAngle = values.end;
    notifyListeners();
    // _executeCommand('setTiltLimits', params: {'min': '$_tiltMinAngle', 'max': '$_tiltMaxAngle'});
  }
}
