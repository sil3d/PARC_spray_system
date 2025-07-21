import 'package:flutter/material.dart';

class TemperatureGauge extends StatelessWidget {
  final bool isAlert; // Ajouter ce paramètre
  final double? temperature;
  final double? humidity;

  const TemperatureGauge({
    super.key,
    this.temperature,
    this.humidity,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isAlert ? const Color.fromARGB(255, 175, 4, 21) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGaugeItem(
              icon: Icons.thermostat,
              value: temperature,
              unit: '°C',
              color: Colors.orangeAccent,
              label: 'Temperature',
            ),
            // Un séparateur vertical
            Container(height: 50, width: 1, color: Colors.grey.shade300),
            _buildGaugeItem(
              icon: Icons.water_drop_outlined,
              value: humidity,
              unit: '%',
              color: Colors.blueAccent,
              label: 'Humidity',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeItem({
    required IconData icon,
    required double? value,
    required String unit,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value != null ? '${value.toStringAsFixed(1)} $unit' : 'N/A',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}
