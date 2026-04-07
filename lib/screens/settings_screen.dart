import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/hive_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

const String _detectionModelAsset = 'assets/models/face_detection_front.tflite';
const String _recognitionModelAsset = 'assets/models/mobile_face_net.tflite';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<Map<String, bool>> _loadModelStatus() async {
    Future<bool> exists(String path) async {
      try {
        await rootBundle.load(path);
        return true;
      } catch (_) {
        return false;
      }
    }

    return {
      'Detection model': await exists(_detectionModelAsset),
      'Recognition model': await exists(_recognitionModelAsset),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(recognitionThresholdProvider);
    final themePref = ref.watch(themePreferenceProvider);
    final animationsEnabled = ref.watch(animationsEnabledProvider);
    final soundFeedback = ref.watch(soundFeedbackProvider);
    final compactMode = ref.watch(compactModeProvider);
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => context.push('/privacy'),
            child: const Text('Privacy'),
          ),
        ],
      ),
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = AppBreakpoints.isCompact(width);
            final wide = width >= 1080;
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);

            final thresholdPanel = AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recognition threshold',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lower values are stricter. Higher values accept more matches but can increase false positives.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      AppPillTag(
                        label: threshold.toStringAsFixed(2),
                        backgroundColor: AppTheme.accentSoft,
                        foregroundColor: AppTheme.accentDark,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Applied during live kiosk recognition.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: threshold,
                    min: 0.35,
                    max: 1.20,
                    divisions: 34,
                    label: threshold.toStringAsFixed(2),
                    onChanged: (value) {
                      ref.read(recognitionThresholdProvider.notifier).state =
                          value;
                    },
                    onChangeEnd: (value) {
                      ref
                          .read(settingsControllerProvider)
                          .setRecognitionThreshold(value);
                    },
                  ),
                ],
              ),
            );

            final appearancePanel = AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Choose app theme and interface behavior.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<AppThemePreference>(
                    segments: const [
                      ButtonSegment(
                        value: AppThemePreference.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppThemePreference.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themePref},
                    onSelectionChanged: (set) {
                      ref
                          .read(settingsControllerProvider)
                          .setThemePreference(set.first);
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable animations'),
                    subtitle: const Text('Use motion effects across the interface.'),
                    value: animationsEnabled,
                    onChanged: (v) =>
                        ref.read(settingsControllerProvider).setAnimationsEnabled(v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sound feedback'),
                    subtitle: const Text('Play cues for recognition and actions.'),
                    value: soundFeedback,
                    onChanged: (v) =>
                        ref.read(settingsControllerProvider).setSoundFeedback(v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact mode'),
                    subtitle: const Text('Reduce spacing for dense layouts.'),
                    value: compactMode,
                    onChanged: (v) =>
                        ref.read(settingsControllerProvider).setCompactMode(v),
                  ),
                ],
              ),
            );

            final enginePanel = AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recognition engine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The app prefers bundled TFLite models and falls back to offline image-feature embeddings if model execution fails.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  const _InfoTile(
                    color: AppTheme.accent,
                    icon: Icons.cloud_off_outlined,
                    title: 'Offline first',
                    subtitle:
                        'Student data and recognition stay on the device.',
                  ),
                  const SizedBox(height: 12),
                  const _InfoTile(
                    color: AppTheme.blue,
                    icon: Icons.shield_outlined,
                    title: 'Fallback protection',
                    subtitle:
                        'Registration keeps working when model calls fail.',
                  ),
                ],
              ),
            );

            final systemStatusPanel = AppPanel(
              child: FutureBuilder<Map<String, bool>>(
                future: _loadModelStatus(),
                builder: (context, snapshot) {
                  final status = snapshot.data;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A quick health check for local attendance readiness.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      _StatusTile(
                        color: AppTheme.accent,
                        label: 'Storage',
                        value: studentsAsync.maybeWhen(
                          data: (_) => 'Ready',
                          orElse: () => 'Loading',
                        ),
                        positive: studentsAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: AppTheme.blue,
                        label: 'Student records',
                        value: studentsAsync.maybeWhen(
                          data: (box) => '${box.length} loaded',
                          orElse: () => 'Loading',
                        ),
                        positive: studentsAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: AppTheme.orange,
                        label: 'Attendance logs',
                        value: attendanceAsync.maybeWhen(
                          data: (box) => '${box.length} stored',
                          orElse: () => 'Loading',
                        ),
                        positive: attendanceAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: AppTheme.pink,
                        label: 'Detection model',
                        value: status == null
                            ? 'Checking'
                            : status['Detection model']!
                            ? 'Available'
                            : 'Missing',
                        positive: status?['Detection model'] ?? false,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: AppTheme.accentDark,
                        label: 'Recognition model',
                        value: status == null
                            ? 'Checking'
                            : status['Recognition model']!
                            ? 'Available'
                            : 'Missing',
                        positive: status?['Recognition model'] ?? false,
                      ),
                    ],
                  );
                },
              ),
            );

            return SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppPanel(
                          child: AppSectionHeading(
                            eyebrow: 'Device configuration',
                            title: 'Settings',
                            subtitle:
                                'Tune matching sensitivity, verify local assets, and keep the offline system ready for daily use.',
                            compact: compact,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    appearancePanel,
                                    const SizedBox(height: 18),
                                    thresholdPanel,
                                    const SizedBox(height: 18),
                                    enginePanel,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(child: systemStatusPanel),
                            ],
                          )
                        else ...[
                          appearancePanel,
                          const SizedBox(height: 18),
                          thresholdPanel,
                          const SizedBox(height: 18),
                          systemStatusPanel,
                          const SizedBox(height: 18),
                          enginePanel,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool positive;

  const _StatusTile({
    required this.color,
    required this.label,
    required this.value,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AppPanel(
      radius: 24,
      color: surfaceAlt,
      padding: const EdgeInsets.all(16),
      elevated: false,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              positive ? Icons.check_rounded : Icons.hourglass_top_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          AppPillTag(
            label: positive ? 'Ready' : 'Pending',
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AppPanel(
      radius: 24,
      color: surfaceAlt,
      padding: const EdgeInsets.all(16),
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
