class SystemState {
  String mode = 'manual';
  bool isSystemRunning = false;
  // <<< AJOUTS ICI >>>
  bool isManualSweepActive = false;
  bool isTemperatureAlert = false;
  // <<< FIN DES AJOUTS >>>
  bool isMiniPump1On = false;
  bool isMiniPump2On = false;
  bool isMainPumpOn = false;
  int servoPan1Angle = 90;
  int servoPan2Angle = 90;
  int servoTilt1Angle = 90;
  int servoTilt2Angle = 90;
  double? temperature;
  double? humidity;
}
