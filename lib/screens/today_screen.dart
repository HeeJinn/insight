import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/session_clock.dart';
import '../services/today_summary.dart';
import '../ui/insight_ui.dart';
import '../widgets/session_badge.dart';
import 'admin_shell_screen.dart';
import 'session_editor.dart';

/// The admin's home: what's happening right now, today's numbers, who is
/// missing, and the day's schedule. Modeled on Health's Summary.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Sessions start and end on the clock, so refresh the "now" figures.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    final sessions = ref.watch(sessionsProvider);
    final sidebar = InsightBreakpoints.usesSidebar(context);

    // Phones have no sidebar, so Settings and the kiosk live in the bar.
    final trailing = sidebar
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassIconButton(
                icon: CupertinoIcons.viewfinder,
                semanticLabel: 'Start Kiosk',
                size: 36,
                onPressed: () => startKiosk(context, ref),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: CupertinoIcons.gear,
                semanticLabel: 'Settings',
                size: 36,
                onPressed: () => context.go('/admin/settings'),
              ),
            ],
          );

    if (students == null || attendance == null) {
      return InsightRootPage(
        title: 'Today',
        trailing: trailing,
        slivers: const [],
      );
    }

    return StreamBuilder(
      stream: students.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) => _TodayContent(
          summary: TodaySummary.compute(
            students: students.values.toList(),
            attendance: attendance.values,
            sessions: sessions,
            now: _now,
          ),
          students: students,
          attendance: attendance,
          sessions: sessions,
          trailing: trailing,
        ),
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.summary,
    required this.students,
    required this.attendance,
    required this.sessions,
    required this.trailing,
  });

  final TodaySummary summary;
  final Box<Student> students;
  final Box<Attendance> attendance;
  final List<SessionEntry> sessions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final namesById = {for (final s in students.values) s.id: s.name};
    final byTitle = {for (final s in sessions) s.title: s};

    return InsightRootPage(
      title: 'Today',
      trailing: trailing,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _longDate(summary.now),
              style: InsightText.subheadline.copyWith(
                color: InsightColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _NowCard(summary: summary, hasSchedule: sessions.isNotEmpty),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _StatGrid(summary: summary),
          ),
        ),
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, c) {
              final missing = _MissingSection(
                summary: summary,
                hasSchedule: sessions.isNotEmpty,
              );
              final latest = _LatestSection(
                records: summary.todaysRecords.take(6).toList(),
                names: namesById,
                sessionsByTitle: byTitle,
              );
              if (c.maxWidth < 760) {
                return Column(children: [missing, latest]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: missing),
                  Expanded(child: latest),
                ],
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _ScheduleSection(sessions: sessions, now: summary.now),
        ),
      ],
    );
  }

  static String _longDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

/// The hero: the running session with its headcount ring, or what's next.
class _NowCard extends StatelessWidget {
  const _NowCard({required this.summary, required this.hasSchedule});

  final TodaySummary summary;
  final bool hasSchedule;

  @override
  Widget build(BuildContext context) {
    final active = summary.active;
    final sidebar = InsightBreakpoints.usesSidebar(context);

    // With a schedule but nothing running: show what's next.
    if (hasSchedule && active == null) {
      final next = summary.next;
      return InsightCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UpNextRow(next: next, now: summary.now),
            const SizedBox(height: 16),
            // For a class meeting outside the weekly schedule.
            CupertinoButton.tinted(
              sizeStyle: CupertinoButtonSize.medium,
              borderRadius: BorderRadius.circular(InsightRadii.capsule),
              onPressed: () => showSessionEditor(
                context,
                draft: draftSessionNow(DateTime.now()),
              ),
              child: const Text('Start a Session Now'),
            ),
          ],
        ),
      );
    }

    return _LiveCard(summary: summary, sidebar: sidebar);
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.next, required this.now});

  final SessionEntry? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final accent = InsightColors.accent.resolveFrom(context);
    final next = this.next;
    return Row(
      children: [
        SymbolBadge(
          next == null ? CupertinoIcons.moon_fill : CupertinoIcons.clock_fill,
          next == null
              ? CupertinoColors.systemIndigo.resolveFrom(context)
              : accent,
          size: 44,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next == null ? 'Done for Today' : 'Up Next',
                style: InsightText.footnote.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                next?.title ?? 'No more sessions today',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: InsightText.title3.copyWith(color: label),
              ),
              if (next != null)
                Text(
                  '${_startsIn(next, now)} · ${formatSessionRange(next)}',
                  style: InsightText.subheadline.copyWith(color: secondary),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _startsIn(SessionEntry s, DateTime now) {
    final minutes = s.startMinuteOfDay - minuteOfDay(now);
    if (minutes < 60) return 'Starts in $minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? 'Starts in $h hr' : 'Starts in $h hr $m min';
  }
}

/// The running session (or today's general check-ins) with its headcount.
class _LiveCard extends ConsumerWidget {
  const _LiveCard({required this.summary, required this.sidebar});

  final TodaySummary summary;
  final bool sidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final success = InsightColors.success.resolveFrom(context);
    final active = summary.active;
    final present = summary.presentNow;
    final expected = summary.expectedNow;
    final fraction = expected == 0 ? 0.0 : present / expected;
    final late = active == null
        ? 0
        : summary.activeRecords
              .where((a) => isLateFor(active, a.timestamp))
              .length;

    return InsightCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active != null)
                      StatusPill(
                        label: 'In Session',
                        icon: CupertinoIcons.dot_radiowaves_left_right,
                        color: success,
                      )
                    else
                      Text(
                        'Check-ins Today',
                        style: InsightText.footnote.copyWith(
                          color: secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      active?.title ?? 'General Check-in',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: InsightText.title1.copyWith(color: label),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active == null
                          ? 'No schedule set · every check-in counts'
                          : '${active.room.isEmpty ? '' : '${active.room} · '}${formatSessionRange(active)}',
                      style: InsightText.subheadline.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ProgressRing(
                progress: fraction,
                color: success,
                // Smaller on narrow phones so the title keeps its room.
                size: MediaQuery.sizeOf(context).width < 360 ? 84 : 104,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$present',
                      style: InsightText.title2.copyWith(
                        color: label,
                        fontFeatures: InsightText.tabular,
                      ),
                    ),
                    Text(
                      'of $expected',
                      style: InsightText.caption1.copyWith(
                        color: secondary,
                        fontFeatures: InsightText.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Figure(value: '$present', label: 'Present', color: success),
              _Figure(
                value: '$late',
                label: 'Late',
                color: InsightColors.warning.resolveFrom(context),
              ),
              _Figure(
                value: '${summary.notCheckedIn.length}',
                label: 'Not yet in',
                color: secondary,
              ),
            ],
          ),
          if (!sidebar) ...[
            const SizedBox(height: 18),
            CupertinoButton.filled(
              sizeStyle: CupertinoButtonSize.large,
              borderRadius: BorderRadius.circular(InsightRadii.capsule),
              onPressed: () => startKiosk(context, ref),
              child: const Text('Start Kiosk'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: InsightText.title3.copyWith(
              color: InsightColors.label.resolveFrom(context),
              fontFeatures: InsightText.tabular,
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InsightText.footnote.copyWith(
                    color: InsightColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final TodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        icon: CupertinoIcons.checkmark_seal_fill,
        color: InsightColors.success.resolveFrom(context),
        value: '${summary.checkedInToday}',
        label: 'Checked In',
        detail: 'students today',
      ),
      StatTile(
        icon: CupertinoIcons.clock_fill,
        color: InsightColors.warning.resolveFrom(context),
        value: '${summary.lateToday}',
        label: 'Late',
        detail: 'after the grace period',
      ),
      StatTile(
        icon: CupertinoIcons.person_2_fill,
        color: InsightColors.accent.resolveFrom(context),
        value: '${summary.enrolled}',
        label: 'Enrolled',
        detail: 'face profiles',
      ),
      StatTile(
        icon: CupertinoIcons.bolt_fill,
        color: CupertinoColors.systemPurple.resolveFrom(context),
        value: summary.averageScanMs == null
            ? '–'
            : '${summary.averageScanMs} ms',
        label: 'Avg. Scan',
        detail: 'capture to record',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 720 ? 4 : 2;
        const gap = 12.0;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _MissingSection extends StatelessWidget {
  const _MissingSection({required this.summary, required this.hasSchedule});

  final TodaySummary summary;
  final bool hasSchedule;

  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final missing = summary.notCheckedIn;

    final List<Widget> rows;
    if (summary.enrolled == 0) {
      rows = [
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.person_badge_plus_fill,
            InsightColors.accent.resolveFrom(context),
          ),
          title: 'Enroll Students',
          subtitle: 'Add face profiles so the kiosk can recognize them.',
          onTap: () => context.go('/admin/students'),
        ),
      ];
    } else if (hasSchedule && summary.active == null) {
      rows = const [
        InsightRow(
          title: 'No class in session',
          subtitle: 'This list fills in when a session starts.',
        ),
      ];
    } else if (missing.isEmpty) {
      rows = [
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.checkmark_alt,
            InsightColors.success.resolveFrom(context),
          ),
          title: 'Everyone is in',
        ),
      ];
    } else {
      rows = [
        for (final s in missing.take(_shown))
          InsightRow(
            leading: InitialsAvatar(name: s.name, size: 30),
            title: s.name,
            value: s.id,
          ),
        if (missing.length > _shown)
          InsightRow(
            title: '${missing.length - _shown} more',
            onTap: () => context.go('/admin/students'),
          ),
      ];
    }

    return InsightListSection(
      header: 'Not Checked In',
      dividerInset: 61,
      children: rows,
    );
  }
}

class _LatestSection extends StatelessWidget {
  const _LatestSection({
    required this.records,
    required this.names,
    required this.sessionsByTitle,
  });

  final List<Attendance> records;
  final Map<String, String> names;
  final Map<String, SessionEntry> sessionsByTitle;

  @override
  Widget build(BuildContext context) {
    return InsightListSection(
      header: 'Latest Check-ins',
      headerTrailing: records.isEmpty
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 28),
              onPressed: () => context.go('/admin/attendance'),
              child: Text('See All', style: InsightText.body),
            ),
      dividerInset: 61,
      children: records.isEmpty
          ? const [
              InsightRow(
                title: 'No check-ins yet today',
                subtitle: 'They appear here as students scan in.',
              ),
            ]
          : [
              for (final r in records)
                InsightRow(
                  leading: InitialsAvatar(
                    name: names[r.studentId] ?? r.studentId,
                    size: 30,
                  ),
                  title: names[r.studentId] ?? r.studentId,
                  subtitle: r.sessionTitle ?? 'General check-in',
                  trailing: _timeAndStatus(context, r),
                ),
            ],
    );
  }

  Widget _timeAndStatus(BuildContext context, Attendance r) {
    final session = sessionsByTitle[r.sessionTitle];
    final late = session != null && isLateFor(session, r.timestamp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatClock(r.timestamp),
          style: InsightText.subheadline.copyWith(
            color: InsightColors.secondaryLabel.resolveFrom(context),
            fontFeatures: InsightText.tabular,
          ),
        ),
        if (late)
          Text(
            'Late',
            style: InsightText.footnote.copyWith(
              color: InsightColors.warning.resolveFrom(context),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.sessions, required this.now});

  final List<SessionEntry> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return InsightListSection(
        header: 'Schedule',
        footer:
            'Without a schedule the kiosk records general check-ins all day.',
        children: [
          InsightRow(
            leading: SymbolBadge(
              CupertinoIcons.calendar_badge_plus,
              InsightColors.accent.resolveFrom(context),
            ),
            title: 'Add a Session',
            subtitle: 'Set class times so check-ins are grouped and timed.',
            onTap: () => context.go('/admin/sessions'),
          ),
        ],
      );
    }

    final todays = sessionsOn(sessions, now);
    return InsightListSection(
      header: 'Schedule',
      children: todays.isEmpty
          ? [
              InsightRow(
                title: 'No sessions today',
                onTap: () => context.go('/admin/sessions'),
              ),
            ]
          : [
              for (final s in todays)
                InsightRow(
                  leading: SessionStateBadge(session: s, now: now),
                  title: s.title,
                  subtitle: s.room.isEmpty ? null : s.room,
                  value: formatSessionRange(s),
                  onTap: () => context.go('/admin/sessions'),
                ),
            ],
    );
  }
}
