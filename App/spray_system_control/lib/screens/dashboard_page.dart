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
    // Écoute les changements du provider. L'UI se reconstruira quand `notifyListeners()` est appelé.
    final provider = context.watch<DashboardProvider>();
    final state = provider.systemState;
    final isManualMode = state.mode == 'manual';
    final isTempAlert = state.isTemperatureAlert;
    final isManualSweepActive = state.isManualSweepActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spray Control Dashboard'),
        actions: [
          // Affiche une icône d'alerte animée si la température est trop élevée
          if (isTempAlert)
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 30,
              ),
            ),

          // Bouton d'arrêt d'urgence toujours visible et accessible
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
          // Fond dégradé pour un aspect plus soigné
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blueGrey.shade100, Colors.blueGrey.shade300],
              ),
            ),
          ),
          // Contenu principal défilable
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Carte d'état et contrôle de mode
                StatusCard(
                  systemState: state,
                  onModeChange: provider.changeMode,
                ),
                const SizedBox(height: 16),

                // Jauges de Température et Humidité
                TemperatureGauge(
                  temperature: state.temperature,
                  humidity: state.humidity,
                  isAlert: isTempAlert,
                ),
                const SizedBox(height: 16),

                // --- Carte de Contrôle Manuel ---
                // Cette carte regroupe les joysticks et le bouton de balayage manuel.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Manual Control',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),

                        // L'appel à JoystickControl est maintenant correct car le widget
                        // a été défini pour accepter 'isSweepActive'.
                        JoystickControl(
                          panAngle: state.servoPan1Angle,
                          tiltAngle: state.servoTilt1Angle,
                          isManualMode: isManualMode,
                          isSweepActive:
                              isManualSweepActive, // Le paramètre est bien passé ici
                          onJoystickUpdate: provider.controlJoystick,
                        ),

                        const SizedBox(height: 24),

                        // Bouton pour lancer/arrêter le balayage en mode MANUEL
                        ElevatedButton.icon(
                          onPressed: isManualMode
                              ? () => provider.toggleManualSweep(
                                  !isManualSweepActive,
                                )
                              : null,
                          icon: Icon(
                            isManualSweepActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          label: Text(
                            isManualSweepActive ? 'STOP SWEEP' : 'START SWEEP',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isManualSweepActive
                                ? Colors.orange.shade700
                                : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(
                              double.infinity,
                              50,
                            ), // S'étend sur toute la largeur
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Carte de contrôle des pompes
                PumpControlCard(
                  systemState: state,
                  isManualMode: isManualMode,
                  onPumpToggle: provider.controlPump,
                ),
              ],
            ),
          ),

          // Indicateur de chargement/connexion (s'affiche par-dessus tout)
          if (provider.isConnecting)
            Container(
              color: Colors.black.withAlpha(128), // Fond semi-transparent
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
