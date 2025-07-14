import 'package:flutter/material.dart';
import 'beautiful_joystick.dart';

class JoystickControl extends StatelessWidget {
  final int panAngle;
  final int tiltAngle;
  final bool isManualMode;
  // Modifié pour un seul callback pour la simplicité du provider
  final Function(double, double) onJoystickUpdate;

  const JoystickControl({
    super.key,
    required this.panAngle,
    required this.tiltAngle,
    required this.isManualMode,
    required this.onJoystickUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Manual Servo Control',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                isManualMode
                    ? 'Joysticks are ACTIVE'
                    : 'Switch to MANUAL mode to activate',
                style: TextStyle(
                  color: isManualMode
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildJoystickColumn(
                  label: 'Pan Axis',
                  angle: panAngle,
                  isEnabled: isManualMode,
                  onUpdate: (x, y) =>
                      onJoystickUpdate(x, 0), // N'envoie que panX
                  baseColor: Colors.blueGrey.shade300,
                  stickColor: Colors.blueGrey.shade700,
                ),
                _buildJoystickColumn(
                  label: 'Tilt Axis',
                  angle: tiltAngle,
                  isEnabled: isManualMode,
                  onUpdate: (x, y) =>
                      onJoystickUpdate(0, y), // N'envoie que tiltY
                  baseColor: Colors.teal.shade200,
                  stickColor: Colors.teal.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Le reste du widget _buildJoystickColumn est identique
  Widget _buildJoystickColumn({
    required String label,
    required int angle,
    required bool isEnabled,
    required Function(double, double) onUpdate,
    required Color baseColor,
    required Color stickColor,
  }) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        BeautifulJoystick(
          size: 140,
          isEnabled: isEnabled,
          listener: onUpdate,
          baseColor: baseColor,
          stickColor: stickColor,
        ),
        const SizedBox(height: 12),
        Text(
          'Angle: $angle°',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
