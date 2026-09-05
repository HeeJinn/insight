import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_chrome.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingDoneProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      AppPanel(
                        radius: 18,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  color: context.appColors.accentDark,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Privacy & Security First',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This app operates with a privacy-first posture. '
                              'All biometric recognition data and attendance records '
                              'are processed and stored strictly on your device.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                  ),
                            ),
                            const Divider(height: 32),
                            Text(
                              'By continuing, you agree to:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildPolicyBullet(
                              context,
                              icon: Icons.person_pin_rounded,
                              title: 'Local Student Profiles',
                              subtitle:
                                  'Facial embeddings and profiles are saved on local device storage.',
                            ),
                            const SizedBox(height: 10),
                            _buildPolicyBullet(
                              context,
                              icon: Icons.history_toggle_off_rounded,
                              title: 'Local Attendance Logs',
                              subtitle:
                                  'Kiosk scanning records stay on device with export options.',
                            ),
                            const SizedBox(height: 10),
                            _buildPolicyBullet(
                              context,
                              icon: Icons.camera_front_rounded,
                              title: 'On-Device Camera Access',
                              subtitle:
                                  'Camera feeds are processed in real time and never uploaded to any cloud.',
                            ),
                            const Divider(height: 32),
                            Text(
                              'You can delete student profiles and reset local data at any time '
                              'from the Students and Settings sections.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!onboardingDone) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop(true),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Accept & Return'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyBullet(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: context.appColors.accentDark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
