import 'package:flutter/material.dart';
import '../models/system_state.dart';

class StatusCard extends StatelessWidget {
  final SystemState systemState;
  final Function(bool) onModeChange;

  const StatusCard({
    super.key,
    required this.systemState,
    required this.onModeChange,
  });

  @override
  Widget build(BuildContext context) {
    bool isAuto = systemState.mode == 'auto';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Control',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode: ${systemState.mode.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      systemState.isSystemRunning
                          ? 'System is ACTIVE'
                          : 'System is IDLE',
                      style: TextStyle(
                        color: systemState.isSystemRunning
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(isAuto ? 'AUTO' : 'MANUAL'),
                    Switch(
                      value: isAuto,
                      onChanged: onModeChange,
                      activeColor: Colors.blueAccent,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
