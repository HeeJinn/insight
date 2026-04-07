import 'package:flutter/material.dart';
import '../widgets/app_chrome.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppPanel(
              radius: 18,
              child: Text(
                'This prototype stores attendance data locally on your device. '
                'No external API is used for recognition. Captured images and embeddings '
                'are used only for biometric attendance matching in this app.\n\n'
                'By continuing, you agree to:\n'
                '- local storage of student profiles,\n'
                '- local storage of attendance logs,\n'
                '- usage of camera access for kiosk scanning.\n\n'
                'You can delete profiles at any time from the Students section.',
                style: TextStyle(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
