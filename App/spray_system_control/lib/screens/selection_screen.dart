import 'package:flutter/material.dart';
import 'home_screen.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Sprayer Model')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your system to control',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 30),
              _buildSprayerCard(
                context,
                title: 'Prototype V1',
                description: 'Single-head, servo-driven lightweight sprayer.',
                imagePath:
                    'assets/images/prototype_v1.png', // Mettez votre image ici
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildSprayerCard(
                context,
                title: 'Inspired',
                description: 'Signle-head, stepper-driven heavy-duty sprayer.',
                imagePath:
                    'assets/images/prototype_v2.png', // Mettez votre image ici
                onTap: null, // Non fonctionnel pour le moment
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSprayerCard(
    BuildContext context, {
    required String title,
    required String description,
    required String imagePath,
    required VoidCallback? onTap,
  }) {
    bool isEnabled = onTap != null;
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5,
            child: Row(
              children: [
                // Image (remplacez par un vrai `Image.asset`)
                // Image.asset(imagePath, width: 80, height: 80, fit: BoxFit.cover),
                Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade300,
                  child: Icon(Icons.precision_manufacturing),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (!isEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '(Coming Soon)',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isEnabled)
                  Icon(Icons.arrow_forward_ios, color: Colors.grey.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
