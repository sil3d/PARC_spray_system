import 'package:flutter/material.dart';
import 'beautiful_joystick.dart'; // Ensure you have this custom widget

class JoystickControl extends StatelessWidget {
  final int panAngle;
  final int tiltAngle;
  final bool isManualMode;
  final bool isSweepActive;
  final Function(double, double) onJoystickUpdate;

  const JoystickControl({
    super.key,
    required this.panAngle,
    required this.tiltAngle,
    required this.isManualMode,
    required this.isSweepActive,
    required this.onJoystickUpdate,
  });

  @override
  Widget build(BuildContext context) {
    // Joysticks are enabled only if in manual mode AND manual sweep is NOT active.
    final bool areJoysticksEnabled = isManualMode && !isSweepActive;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
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
                _getHelperText(areJoysticksEnabled),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: areJoysticksEnabled
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: _buildJoystickColumn(
                    label: 'Pan Axis',
                    angle: panAngle,
                    isEnabled: areJoysticksEnabled,
                    onUpdate: (x, y) => onJoystickUpdate(x, 0),
                    baseColor: Colors.blueGrey.shade300,
                    stickColor: Colors.blueGrey.shade700,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: _buildJoystickColumn(
                    label: 'Tilt Axis',
                    angle: tiltAngle,
                    // <<< CORRECTION OF THE TYPO IS HERE >>>
                    isEnabled:
                        areJoysticksEnabled, // Corrected from areJoystacksEnabled
                    // <<< END OF CORRECTION >>>
                    onUpdate: (x, y) => onJoystickUpdate(0, y),
                    baseColor: Colors.teal.shade200,
                    stickColor: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getHelperText(bool areJoysticksEnabled) {
    if (areJoysticksEnabled) {
      return 'Joysticks are ACTIVE';
    } else if (isManualMode && isSweepActive) {
      return 'Joysticks are disabled during Manual Sweep';
    } else {
      return 'Switch to MANUAL mode to activate controls';
    }
  }

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
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 12),
        BeautifulJoystick(
          size: 140,
          isEnabled: isEnabled,
          listener: onUpdate,
          baseColor: baseColor,
          stickColor: stickColor,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(50),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Angle: $angle°',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
