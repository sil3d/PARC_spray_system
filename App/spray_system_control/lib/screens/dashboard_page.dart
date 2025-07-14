import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/joystick_control.dart';
import '../widgets/pump_control_card.dart';
import '../widgets/status_card.dart';
import '../widgets/temperature_gauge.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final state = provider.systemState;
    final isManualMode = state.mode == 'manual';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spray Control Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.power_settings_new,
              color: Colors.red.shade200,
              size: 30,
            ),
            tooltip: 'Emergency Stop',
            onPressed: provider.emergencyStop,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade100, Colors.blueGrey.shade300],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StatusCard(
                  systemState: state,
                  onModeChange: provider.changeMode,
                ),
                const SizedBox(height: 16),
                TemperatureGauge(
                  temperature: state.temperature,
                  humidity: state.humidity,
                ),
                const SizedBox(height: 16),

                // <<< CORRECTION ICI : MISE À JOUR DE L'APPEL AU WIDGET JOYSTICKCONTROL >>>
                JoystickControl(
                  panAngle: state.servoPan1Angle,
                  tiltAngle: state.servoTilt1Angle,
                  isManualMode: isManualMode,
                  onJoystickUpdate: provider
                      .controlJoystick, // Correction : on passe une seule fonction
                ),

                // <<< FIN DE LA CORRECTION >>>
                const SizedBox(height: 16),
                PumpControlCard(
                  systemState: state,
                  isManualMode: isManualMode,
                  onPumpToggle: provider.controlPump,
                ),
              ],
            ),
          ),
          if (provider.isConnecting)
            Container(
              color: Colors.black.withAlpha(128),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
