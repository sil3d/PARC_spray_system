import 'package:flutter/material.dart';
import '../models/system_state.dart';

class PumpControlCard extends StatelessWidget {
  final SystemState systemState;
  final bool isManualMode;
  final Function(String, bool) onPumpToggle;

  const PumpControlCard({
    super.key,
    required this.systemState,
    required this.isManualMode,
    required this.onPumpToggle,
  });

  @override
  Widget build(BuildContext context) {
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
            const Divider(),
            _buildPumpControlRow('Main Pump', systemState.isMainPumpOn, 'main'),
            _buildPumpControlRow(
              'Mini Pump 1',
              systemState.isMiniPump1On,
              'mini1',
            ),
            _buildPumpControlRow(
              'Mini Pump 2',
              systemState.isMiniPump2On,
              'mini2',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpControlRow(String label, bool isOn, String pumpId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Row(
            children: [
              // --- BOUTON ON ---
              ElevatedButton(
                onPressed: isManualMode && !isOn
                    ? () => onPumpToggle(pumpId, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOn ? Colors.green : Colors.grey.shade300,
                  foregroundColor: isOn ? Colors.white : Colors.black54,
                ),
                child: const Text('ON'),
              ),
              const SizedBox(width: 8),
              // --- BOUTON OFF ---
              ElevatedButton(
                onPressed: isManualMode && isOn
                    ? () => onPumpToggle(pumpId, false)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: !isOn
                      ? Colors.redAccent
                      : Colors.grey.shade300,
                  foregroundColor: !isOn ? Colors.white : Colors.black54,
                ),
                child: const Text('OFF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
