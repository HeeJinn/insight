import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_state_provider.dart';
import '../ui/insight_ui.dart';

/// What Insight does with faces and attendance. During onboarding it ends
/// with Accept & Return, which reports acceptance back to onboarding.
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingDoneProvider);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: insightPushedBar(title: 'Privacy Policy'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    children: [
                      Center(
                        child: SymbolBadge(
                          CupertinoIcons.lock_shield_fill,
                          InsightColors.accent.resolveFrom(context),
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Privacy & Security First',
                        textAlign: TextAlign.center,
                        style: InsightText.title1.copyWith(
                          color: InsightColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Insight works entirely on this device. Faces and '
                          'attendance records are processed and stored here, '
                          'never uploaded.',
                          textAlign: TextAlign.center,
                          style: InsightText.body.copyWith(color: secondary),
                        ),
                      ),
                      InsightListSection(
                        header: 'By continuing, you agree to',
                        children: [
                          _PolicyRow(
                            icon: CupertinoIcons.person_crop_circle_fill,
                            color: CupertinoColors.systemBlue,
                            title: 'Local Student Profiles',
                            detail:
                                'Face profiles (numeric embeddings, not photos) '
                                'and names are saved in this device\'s storage.',
                          ),
                          _PolicyRow(
                            icon: CupertinoIcons.checkmark_seal_fill,
                            color: CupertinoColors.systemGreen,
                            title: 'Local Attendance Logs',
                            detail:
                                'Check-ins stay on this device. An admin can '
                                'export them as a CSV file.',
                          ),
                          _PolicyRow(
                            icon: CupertinoIcons.camera_fill,
                            color: CupertinoColors.systemOrange,
                            title: 'On-Device Camera Access',
                            detail:
                                'The camera feed is analyzed in real time and '
                                'discarded. Enrollment photos are deleted once '
                                'the face profile is made.',
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
                        child: Text(
                          'Delete a student in Students, or erase records and '
                          'all data in Settings, at any time.',
                          style: InsightText.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!onboardingDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      sizeStyle: CupertinoButtonSize.large,
                      borderRadius: BorderRadius.circular(InsightRadii.capsule),
                      onPressed: () => context.pop(true),
                      child: const Text('Accept & Return'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final CupertinoDynamicColor color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SymbolBadge(icon, color.resolveFrom(context)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: InsightText.headline.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: InsightText.subheadline.copyWith(
                    color: InsightColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
