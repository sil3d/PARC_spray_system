import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late RangeValues _panRange;
  late RangeValues _tiltRange;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialise les valeurs des sliders avec celles du provider
    final provider = context.read<DashboardProvider>();
    _panRange = RangeValues(provider.panMinAngle, provider.panMaxAngle);
    _tiltRange = RangeValues(provider.tiltMinAngle, provider.tiltMaxAngle);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Calibration')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Servo Calibration'),
          // Pan Axis Calibration
          Text(
            'Pan Axis Range (${_panRange.start.round()}° - ${_panRange.end.round()}°)',
          ),
          RangeSlider(
            values: _panRange,
            min: 0,
            max: 180,
            divisions: 180,
            labels: RangeLabels(
              _panRange.start.round().toString(),
              _panRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _panRange = values);
            },
            onChangeEnd: (values) {
              // Applique la calibration quand l'utilisateur a fini de glisser
              provider.updatePanCalibration(values);
            },
          ),
          const SizedBox(height: 20),
          // Tilt Axis Calibration
          Text(
            'Tilt Axis Range (${_tiltRange.start.round()}° - ${_tiltRange.end.round()}°)',
          ),
          RangeSlider(
            values: _tiltRange,
            min: 0,
            max: 180,
            divisions: 180,
            labels: RangeLabels(
              _tiltRange.start.round().toString(),
              _tiltRange.end.round().toString(),
            ),
            onChanged: (values) {
              setState(() => _tiltRange = values);
            },
            onChangeEnd: (values) {
              provider.updateTiltCalibration(values);
            },
          ),
          const Divider(height: 40),
          _buildSectionHeader('System Information'),
          ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('WiFi Configuration'),
            subtitle: const Text('Tap to view ESP32 hotspot info'),
            onTap: () => _showInfoDialog(
              context,
              title: 'WiFi Hotspot Info',
              content:
                  'Connect your device to the following network:\n\nSSID: ESP32_Spray_Control\nPassword: votre_mot_de_passe\n\nApp IP Address: 192.168.4.1',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Spray System Control v1.0'),
            onTap: () => _showInfoDialog(
              context,
              title: 'About This App',
              content:
                  'PARC Engineer\'s League 2025\nSpray System Prototype Controller\nVersion 1.0.0',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showInfoDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
