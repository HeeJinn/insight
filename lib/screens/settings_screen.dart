import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_lock_provider.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../providers/settings_provider.dart';
import '../services/attendance_filter.dart';
import '../services/csv_export.dart';
import '../services/data_maintenance.dart';
import '../services/face_processor.dart';
import '../ui/insight_ui.dart';
import '../widgets/admin_unlock_dialog.dart';
import 'privacy_policy_screen.dart';

/// Settings, laid out like the iOS Settings app: grouped rows that toggle
/// in place or drill into a page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebar = InsightBreakpoints.usesSidebar(context);
    final hasPin = ref.watch(adminPinProvider) != null;
    final sound = ref.watch(soundFeedbackProvider);
    final theme = ref.watch(themePreferenceProvider);
    final lateDefault = ref.watch(defaultLateAfterProvider);
    final threshold = ref.watch(recognitionThresholdProvider);
    final settings = ref.read(settingsControllerProvider);
    final accent = InsightColors.accent.resolveFrom(context);

    void push(Widget page) => Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => page));

    return InsightRootPage(
      title: 'Settings',
      maxContentWidth: 720,
      // Phones reach Settings from Today's toolbar; this takes them back.
      leading: sidebar
          ? null
          : GlassIconButton(
              icon: CupertinoIcons.chevron_back,
              semanticLabel: 'Back',
              size: 36,
              onPressed: () => context.go('/admin/today'),
            ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsightListSection(
                header: 'Kiosk',
                footer: hasPin
                    ? 'The PIN keeps the admin area closed while the kiosk '
                          'runs at the door.'
                    : 'Set a PIN so students at the kiosk can\'t open the '
                          'admin area.',
                children: [
                  InsightRow(
                    leading: SymbolBadge(
                      CupertinoIcons.lock_fill,
                      CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    title: hasPin ? 'Change Admin PIN' : 'Set Admin PIN',
                    onTap: () async {
                      if (await showChangePinDialog(context)) {
                        HapticFeedback.mediumImpact();
                      }
                    },
                  ),
                  InsightRow(
                    leading: SymbolBadge(
                      CupertinoIcons.speaker_2_fill,
                      CupertinoColors.systemPink.resolveFrom(context),
                    ),
                    title: 'Sound on Check-in',
                    trailing: CupertinoSwitch(
                      value: sound,
                      activeTrackColor: accent,
                      onChanged: settings.setSoundFeedback,
                    ),
                  ),
                  InsightRow(
                    leading: SymbolBadge(
                      CupertinoIcons.viewfinder,
                      CupertinoColors.systemIndigo.resolveFrom(context),
                    ),
                    title: 'Recognition',
                    value: _strictnessLabel(threshold),
                    onTap: () => push(const RecognitionSettingsPage()),
                  ),
                  _LateDefaultRow(
                    minutes: lateDefault,
                    onChanged: settings.setDefaultLateAfter,
                  ),
                ],
              ),
              InsightListSection(
                header: 'Appearance',
                dividerInset: 16,
                children: [
                  for (final (pref, label) in const [
                    (AppThemePreference.system, 'Match System'),
                    (AppThemePreference.light, 'Light'),
                    (AppThemePreference.dark, 'Dark'),
                  ])
                    InsightRow(
                      title: label,
                      showChevron: false,
                      trailing: theme == pref
                          ? Icon(
                              CupertinoIcons.checkmark,
                              size: 18,
                              color: accent,
                            )
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.setThemePreference(pref);
                      },
                    ),
                ],
              ),
              const _DataSection(),
              InsightListSection(
                children: [
                  InsightRow(
                    leading: SymbolBadge(
                      CupertinoIcons.hand_raised_fill,
                      CupertinoColors.systemBlue.resolveFrom(context),
                    ),
                    title: 'Privacy Policy',
                    onTap: () => push(const PrivacyPolicyScreen()),
                  ),
                  InsightRow(
                    leading: SymbolBadge(
                      CupertinoIcons.info,
                      CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    title: 'About Insight',
                    onTap: () => push(const AboutPage()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Strict", "Balanced" or "Lenient" for a recognition threshold. Lower
/// thresholds demand a closer face match.
String _strictnessLabel(double threshold) {
  final d = threshold - FaceProcessor.defaultThreshold;
  if (d.abs() < 0.05) return 'Balanced';
  return d < 0 ? 'Strict' : 'Lenient';
}

class _LateDefaultRow extends StatelessWidget {
  const _LateDefaultRow({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  static const _options = [0, 5, 10, 15, 20, 30, 45];

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    return CupertinoMenuAnchor(
      menuChildren: [
        for (final m in _options)
          CupertinoMenuItem(
            trailing: m == minutes
                ? Icon(CupertinoIcons.checkmark, size: 17, color: accent)
                : null,
            onPressed: () => onChanged(m),
            child: Text(m == 0 ? 'At the start' : '$m minutes after start'),
          ),
      ],
      builder: (context, controller, _) => InsightRow(
        leading: SymbolBadge(
          CupertinoIcons.clock_fill,
          CupertinoColors.systemOrange.resolveFrom(context),
        ),
        title: 'Default Late Cutoff',
        showChevron: false,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                minutes == 0 ? 'At start' : '$minutes min',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: InsightText.body.copyWith(
                  color: InsightColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_up_chevron_down,
              size: 15,
              color: InsightColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Export and delete local records.
class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceBoxProvider).value;
    final count = attendance?.length ?? 0;
    final danger = InsightColors.danger.resolveFrom(context);

    return InsightListSection(
      header: 'Data',
      footer:
          'Everything is stored only on this device. Erasing can\'t be '
          'undone, so export first if you need a copy.',
      children: [
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.square_arrow_up,
            CupertinoColors.systemGreen.resolveFrom(context),
          ),
          title: 'Export All Check-ins',
          value: '$count',
          showChevron: false,
          onTap: count == 0 ? null : () => _exportAll(context, ref),
        ),
        InsightRow(
          leading: SymbolBadge(CupertinoIcons.trash_fill, danger),
          title: 'Delete Check-ins…',
          showChevron: false,
          onTap: count == 0 ? null : () => _deleteRecords(context, ref),
        ),
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.exclamationmark_octagon_fill,
            danger,
          ),
          title: 'Erase All Data…',
          subtitle: 'Students, face profiles, check-ins and sessions',
          showChevron: false,
          onTap: () => _eraseAll(context, ref),
        ),
      ],
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final students = await ref.read(studentsBoxProvider.future);
    final attendance = await ref.read(attendanceBoxProvider.future);
    final sessions = ref.read(sessionsProvider);
    final records = attendance.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final csv = attendanceCsv(
      records,
      namesById: {for (final s in students.values) s.id: s.name},
      sessionsByTitle: {for (final s in sessions) s.title: s},
    );
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    String? location;
    Object? error;
    try {
      location = await exportCsv(
        csv,
        'insight-all-checkins-${now.year}${two(now.month)}${two(now.day)}.csv',
      );
    } catch (e) {
      error = e;
    }
    if (!context.mounted) return;
    await _alert(
      context,
      error == null
          ? 'Exported ${records.length} Check-ins'
          : "Couldn't Export",
      error == null ? 'Saved as $location' : '$error',
    );
  }

  Future<void> _deleteRecords(BuildContext context, WidgetRef ref) async {
    final choice = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Delete Check-ins'),
        message: const Text(
          'Students and sessions are kept. This can\'t be undone.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(90),
            child: const Text('Older Than 90 Days'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(0),
            child: const Text('All Check-ins'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (choice == null) return;
    final attendance = await ref.read(attendanceBoxProvider.future);
    final removed = await deleteCheckIns(
      attendance,
      olderThan: choice == 0 ? null : Duration(days: choice),
    );
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      await _alert(
        context,
        removed == 0 ? 'Nothing to Delete' : 'Deleted $removed Check-ins',
        removed == 0 ? 'No check-ins were that old.' : null,
      );
    }
  }

  Future<void> _eraseAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Erase All Data?'),
        content: const Text(
          'Every student, face profile, check-in and session on this device '
          'will be deleted. This can\'t be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final students = await ref.read(studentsBoxProvider.future);
    final attendance = await ref.read(attendanceBoxProvider.future);
    await attendance.clear();
    await students.clear();
    final sessions = ref.read(sessionsProvider.notifier);
    for (final s in ref.read(sessionsProvider)) {
      await sessions.removeSession(s.id);
    }
    HapticFeedback.heavyImpact();
  }

  static Future<void> _alert(
    BuildContext context,
    String title,
    String? message,
  ) {
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// How closely a face must match an enrolled profile.
class RecognitionSettingsPage extends ConsumerWidget {
  const RecognitionSettingsPage({super.key});

  static const double _min = 0.6;
  static const double _max = 1.4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(recognitionThresholdProvider);
    final settings = ref.read(settingsControllerProvider);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final isDefault =
        (threshold - FaceProcessor.defaultThreshold).abs() < 0.001;

    return CupertinoPageScaffold(
      navigationBar: insightPushedBar(title: 'Recognition'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              children: [
                InsightListSection(
                  header: 'Match Strictness',
                  footer:
                      'Stricter rejects more look-alikes but may ask students '
                      'to scan again. More lenient recognizes faster in poor '
                      'light but risks mixing up similar faces. Balanced '
                      'suits most classrooms.',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _strictnessLabel(threshold),
                                  style: InsightText.headline.copyWith(
                                    color: InsightColors.label.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                threshold.toStringAsFixed(2),
                                style: InsightText.body.copyWith(
                                  color: secondary,
                                  fontFeatures: InsightText.tabular,
                                ),
                              ),
                            ],
                          ),
                          CupertinoSlider(
                            value: threshold.clamp(_min, _max),
                            min: _min,
                            max: _max,
                            divisions: 16,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              ref
                                      .read(
                                        recognitionThresholdProvider.notifier,
                                      )
                                      .state =
                                  v;
                            },
                            onChangeEnd: settings.setRecognitionThreshold,
                          ),
                          Row(
                            children: [
                              Text(
                                'Stricter',
                                style: InsightText.footnote.copyWith(
                                  color: secondary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'More lenient',
                                style: InsightText.footnote.copyWith(
                                  color: secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                InsightListSection(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: isDefault
                          ? null
                          : () => settings.setRecognitionThreshold(
                              FaceProcessor.defaultThreshold,
                            ),
                      child: Text(
                        'Reset to Balanced',
                        style: InsightText.body.copyWith(
                          color: isDefault
                              ? InsightColors.tertiaryLabel.resolveFrom(context)
                              : InsightColors.accent.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What Insight is made of and what it's holding, for the admin and for
/// anyone evaluating the system.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    final sessions = ref.watch(sessionsProvider);

    return CupertinoPageScaffold(
      navigationBar: insightPushedBar(title: 'About'),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: InsightColors.accent.resolveFrom(context),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      CupertinoIcons.viewfinder,
                      size: 40,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Insight',
                  textAlign: TextAlign.center,
                  style: InsightText.title1.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
                Text(
                  'Offline biometric attendance',
                  textAlign: TextAlign.center,
                  style: InsightText.subheadline.copyWith(
                    color: InsightColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                InsightListSection(
                  header: 'On This Device',
                  dividerInset: 16,
                  children: [
                    InsightRow(
                      title: 'Students',
                      value: '${students?.length ?? 0}',
                    ),
                    InsightRow(
                      title: 'Check-ins',
                      value: '${attendance?.length ?? 0}',
                    ),
                    InsightRow(title: 'Sessions', value: '${sessions.length}'),
                  ],
                ),
                const InsightListSection(
                  header: 'How It Works',
                  dividerInset: 16,
                  footer:
                      'Recognition runs fully offline. No face data or '
                      'attendance leaves this device unless an admin exports '
                      'it.',
                  children: [
                    InsightRow(title: 'Face Detection', value: 'BlazeFace'),
                    InsightRow(
                      title: 'Face Recognition',
                      value: 'MobileFaceNet',
                    ),
                    InsightRow(title: 'Face Profile', value: '192-d vectors'),
                    InsightRow(title: 'Storage', value: 'Hive, on device'),
                  ],
                ),
                // Required by the Storyset (Freepik) and LottieFiles licenses
                // of the onboarding animations.
                const InsightListSection(
                  header: 'Acknowledgements',
                  dividerInset: 16,
                  footer:
                      'Illustrations by Storyset (storyset.com). "Success" '
                      'animation by Darius Afchar via LottieFiles.',
                  children: [
                    InsightRow(title: 'Illustrations', value: 'Storyset'),
                    InsightRow(
                      title: 'Success Animation',
                      value: 'Darius Afchar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
