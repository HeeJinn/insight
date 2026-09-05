import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/flavor_profiles_provider.dart';
import '../providers/hive_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/biometric_indicators.dart';
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
    final flavors = ref.watch(flavorProfilesProvider);
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: () => context.push('/settings/privacy'),
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
            final bottomSafeGap =
                MediaQuery.viewPaddingOf(context).bottom +
                kBottomNavigationBarHeight +
                24;

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
                        backgroundColor: context.appColors.accentSoft,
                        foregroundColor: context.appColors.accentDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Applied during live kiosk recognition.',
                          style: TextStyle(color: context.appColors.mutedText),
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
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                    subtitle: const Text(
                      'Use motion effects across the interface.',
                    ),
                    value: animationsEnabled,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider)
                        .setAnimationsEnabled(v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sound feedback'),
                    subtitle: const Text(
                      'Play cues for recognition and actions.',
                    ),
                    value: soundFeedback,
                    onChanged: (v) => ref
                        .read(settingsControllerProvider)
                        .setSoundFeedback(v),
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
                  _InfoTile(
                    color: context.appColors.accent,
                    icon: Icons.cloud_off_outlined,
                    title: 'Offline first',
                    subtitle:
                        'Student data and recognition stay on the device.',
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    color: context.appColors.blue,
                    icon: Icons.shield_outlined,
                    title: 'Fallback protection',
                    subtitle:
                        'Registration keeps working when model calls fail.',
                  ),
                ],
              ),
            );

            final flavorPanel = AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flavor studio',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize Vessel and Scoop from the admin side with editable copy, tone, and visibility.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  ...flavors.map(
                    (profile) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.flavorToneSoft(profile.tone),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            profile.id == 'vessel'
                                ? Icons.layers_outlined
                                : Icons.auto_awesome_mosaic_outlined,
                            color: AppTheme.flavorToneColor(profile.tone),
                          ),
                        ),
                        title: Text(profile.name),
                        subtitle: Text(
                          profile.enabled
                              ? profile.tagline
                              : '${profile.tagline} · paused',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/flavors'),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Open Flavor Studio'),
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
                        color: context.appColors.accent,
                        label: 'Storage',
                        value: studentsAsync.maybeWhen(
                          data: (_) => 'Ready',
                          orElse: () => 'Loading',
                        ),
                        positive: studentsAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: context.appColors.blue,
                        label: 'Student records',
                        value: studentsAsync.maybeWhen(
                          data: (box) => '${box.length} loaded',
                          orElse: () => 'Loading',
                        ),
                        positive: studentsAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: context.appColors.orange,
                        label: 'Attendance logs',
                        value: attendanceAsync.maybeWhen(
                          data: (box) => '${box.length} stored',
                          orElse: () => 'Loading',
                        ),
                        positive: attendanceAsync.hasValue,
                      ),
                      const SizedBox(height: 12),
                      _StatusTile(
                        color: context.appColors.pink,
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
                        color: context.appColors.accentDark,
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: padding.copyWith(bottom: bottomSafeGap),
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
                                    systemStatusPanel,
                                    const SizedBox(height: 18),
                                    thresholdPanel,
                                    const SizedBox(height: 18),
                                    appearancePanel,
                                    const SizedBox(height: 18),
                                    enginePanel,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  children: [
                                    flavorPanel,
                                    const SizedBox(height: 18),
                                    AppPanel(
                                      child: const Text(
                                        'Advanced tools are grouped below to keep daily configuration faster and cleaner.',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          systemStatusPanel,
                          const SizedBox(height: 18),
                          thresholdPanel,
                          const SizedBox(height: 18),
                          appearancePanel,
                          const SizedBox(height: 18),
                          flavorPanel,
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
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              positive ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          TelemetryBadge(
            label: positive ? 'VERIFIED' : 'PENDING',
            color: color,
            pulse: !positive,
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
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.mutedText,
                    height: 1.35,
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
