import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/biometric_indicators.dart';
import '../widgets/responsive_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);
    final sessions = ref.watch(sessionsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = AppBreakpoints.isCompact(width);
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);
            final bottomSafeGap = AppBreakpoints.navAwareBottomInset(context);

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: padding.copyWith(bottom: bottomSafeGap + 12),
                    children: [
                      _Header(compact: compact),
                      const SizedBox(height: 16),
                      _KioskHeroCard(
                        studentsBox: studentsAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                        attendanceBox: attendanceAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                        sessions: sessions,
                      ),
                      const SizedBox(height: 16),
                      _OverviewPanel(
                        studentsBox: studentsAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                        attendanceBox: attendanceAsync.maybeWhen(
                          data: (box) => box,
                          orElse: () => null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TodaySessionsStrip(sessions: sessions),
                      if (kIsWeb) ...[
                        const SizedBox(height: 14),
                        AppPanel(
                          color: context.appColors.warningSoft,
                          radius: 14,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: context.appColors.warning,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Web preview mode. Camera inference and kiosk recognition run on Android, iOS, and Desktop.',
                                  style: TextStyle(
                                    color: context.appColors.primaryText,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const TelemetryBadge(label: 'NAVIGATION CLUSTER'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).dividerColor,
                              thickness: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _QuickActionsGrid(
                        compact: compact,
                        actions: [
                          _QuickActionData(
                            label: 'Kiosk Scanner',
                            subtitle: 'Facial recognition HUD',
                            icon: Icons.center_focus_strong_rounded,
                            color: context.appColors.accent,
                            onTap: kIsWeb ? null : () => context.push('/kiosk'),
                          ),
                          _QuickActionData(
                            label: 'Attendance Audit',
                            subtitle: 'Detailed time-stamped logs',
                            icon: Icons.history_edu_rounded,
                            color: context.appColors.blue,
                            onTap: () => context.push('/insights/logs'),
                          ),
                          _QuickActionData(
                            label: 'Student Directory',
                            subtitle: 'Profiles & 5-sample biometric',
                            icon: Icons.badge_outlined,
                            color: context.appColors.success,
                            onTap: () => context.go('/students'),
                          ),
                          _QuickActionData(
                            label: 'Session Windows',
                            subtitle: 'Scheduled class timelines',
                            icon: Icons.timer_outlined,
                            color: context.appColors.orange,
                            onTap: () => context.go('/sessions'),
                          ),
                          _QuickActionData(
                            label: 'Telemetry Reports',
                            subtitle: 'Velocity & distribution analytics',
                            icon: Icons.query_stats_rounded,
                            color: context.appColors.accent,
                            onTap: () => context.go('/insights'),
                          ),
                          _QuickActionData(
                            label: 'Admin Terminal',
                            subtitle: 'Enrollment & model calibration',
                            icon: Icons.tune_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            onTap: () => context.go('/admin'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const _SystemStatusCard(),
                    ],
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

class _Header extends StatelessWidget {
  final bool compact;

  const _Header({required this.compact});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final now = DateTime.now();
    final hourFormatted = now.hour.toString().padLeft(2, '0');
    final minuteFormatted = now.minute.toString().padLeft(2, '0');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TelemetryBadge(
                    label: 'INSIGHT // STATION ONLINE',
                    isLive: true,
                    statusColor: colors.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$hourFormatted:$minuteFormatted',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.mutedText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Attendance Station',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'On-device neural inference & autonomous kiosk telemetry',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.secondaryText,
                    ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/settings');
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.9,
              ),
            ),
            child: const Icon(Icons.settings_outlined, size: 20),
          ),
        ),
      ],
    );
  }
}

class _KioskHeroCard extends StatelessWidget {
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;
  final List<SessionEntry> sessions;

  const _KioskHeroCard({
    required this.studentsBox,
    required this.attendanceBox,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (studentsBox == null || attendanceBox == null) {
      return const AppPanel(
        radius: 18,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder(
      stream: studentsBox!.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendanceBox!.watch(),
        builder: (context, _) {
          final studentsCount = studentsBox!.length;
          final now = DateTime.now();
          final dayStart = DateTime(now.year, now.month, now.day);
          final detectedToday = attendanceBox!.values
              .where((item) => item.timestamp.isAfter(dayStart))
              .map((item) => item.studentId)
              .toSet()
              .length;

          final coveragePercent = studentsCount == 0
              ? 0
              : ((detectedToday / studentsCount) * 100).round();

          return AppPanel(
            radius: 18,
            showReticles: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TelemetryBadge(
                      label: 'OPTICAL RETICLE',
                      statusColor: colors.accent,
                      isLive: true,
                    ),
                    BiometricQualityPips(
                      sampleCount: detectedToday,
                      targetCount: studentsCount == 0 ? 1 : studentsCount,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: isDark ? 0.4 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.center_focus_weak_rounded,
                            size: 28,
                            color: colors.accent,
                          ),
                          PulseDot(color: colors.success, size: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$detectedToday',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                ' / $studentsCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colors.mutedText,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$coveragePercent% VERIFIED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: colors.success,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Students checked-in today',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: kIsWeb
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            context.push('/kiosk');
                          },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text(
                      'ENGAGE KIOSK SCANNER',
                      style: TextStyle(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final Box<Student>? studentsBox;
  final Box<Attendance>? attendanceBox;

  const _OverviewPanel({
    required this.studentsBox,
    required this.attendanceBox,
  });

  @override
  Widget build(BuildContext context) {
    if (studentsBox == null || attendanceBox == null) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;

    return StreamBuilder(
      stream: studentsBox!.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendanceBox!.watch(),
        builder: (context, _) {
          final now = DateTime.now();
          final dayStart = DateTime(now.year, now.month, now.day);
          final todaysLogs = attendanceBox!.values
              .where((item) => item.timestamp.isAfter(dayStart))
              .toList();
          final present = todaysLogs.map((item) => item.studentId).toSet().length;
          final total = studentsBox!.length;
          final absent = (total - present).clamp(0, total);
          final late = todaysLogs.where((item) => item.timestamp.hour >= 9).length;

          final presentRatio = total == 0 ? 0.0 : (present / total).clamp(0.0, 1.0);
          final absentRatio = total == 0 ? 0.0 : (absent / total).clamp(0.0, 1.0);
          final lateRatio = total == 0 ? 0.0 : (late / total).clamp(0.0, 1.0);

          return AppPanel(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATTENDANCE VELOCITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: colors.mutedText,
                      ),
                    ),
                    Text(
                      'TOTAL ROSTER: $total',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colors.mutedText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Segmented velocity track
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      children: [
                        if (presentRatio > 0)
                          Expanded(
                            flex: (presentRatio * 1000).round(),
                            child: Container(color: colors.success),
                          ),
                        if (lateRatio > 0)
                          Expanded(
                            flex: (lateRatio * 1000).round(),
                            child: Container(color: colors.orange),
                          ),
                        if (absentRatio > 0)
                          Expanded(
                            flex: (absentRatio * 1000).round(),
                            child: Container(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCell(
                        label: 'Present',
                        value: '$present',
                        percent: total == 0 ? '0%' : '${((present / total) * 100).round()}%',
                        indicatorColor: colors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: 'Late',
                        value: '$late',
                        percent: total == 0 ? '0%' : '${((late / total) * 100).round()}%',
                        indicatorColor: colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: 'Absent',
                        value: '$absent',
                        percent: total == 0 ? '0%' : '${((absent / total) * 100).round()}%',
                        indicatorColor: colors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String percent;
  final Color indicatorColor;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.percent,
    required this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                percent,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.mutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodaySessionsStrip extends StatelessWidget {
  final List<SessionEntry> sessions;

  const _TodaySessionsStrip({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final liveSession = sessions.cast<SessionEntry?>().firstWhere(
          (s) =>
              s != null &&
              s.startMinuteOfDay <= nowMinutes &&
              s.endMinuteOfDay >= nowMinutes,
          orElse: () => null,
        );

    final colors = context.appColors;

    if (liveSession != null) {
      return AppPanel(
        radius: 16,
        showReticles: true,
        borderColor: colors.success.withValues(alpha: 0.35),
        color: colors.success.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            PulseDot(color: colors.success, size: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACTIVE CLASS WINDOW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    liveSession.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/kiosk');
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Launch Kiosk'),
            ),
          ],
        ),
      );
    }

    return AppPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: colors.mutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sessions.isEmpty
                  ? 'No sessions active. Tap to schedule class windows.'
                  : '${sessions.length} scheduled session${sessions.length == 1 ? '' : 's'} registered today',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/sessions'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Manage', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final bool compact;
  final List<_QuickActionData> actions;

  const _QuickActionsGrid({required this.compact, required this.actions});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 2 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: compact ? 1.65 : 2.1,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _ActionTile(action: action);
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final _QuickActionData action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (action.onTap != null) {
            HapticFeedback.selectionClick();
            action.onTap!();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, size: 17, color: action.color),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppPanel(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          PulseDot(color: colors.success, size: 7),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ENGINE: TFLITE FACENET • STORAGE: HIVE SECURE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Local inference engine operational. Zero cloud leakage.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TelemetryBadge(
            label: 'NOMINAL',
            statusColor: colors.success,
          ),
        ],
      ),
    );
  }
}
