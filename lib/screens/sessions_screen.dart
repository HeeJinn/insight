import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';
import '../widgets/session_badge.dart';
import 'session_editor.dart';

/// The class schedule: what meets today, the weekly timetable, and one-time
/// sessions. Editing happens in a sheet, like an alarm in Clock.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
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
    final sessions = ref.watch(sessionsProvider);
    final attendance = ref.watch(attendanceBoxProvider).value;

    final add = GlassIconButton(
      icon: CupertinoIcons.add,
      semanticLabel: 'Add Session',
      size: 36,
      onPressed: () => showSessionEditor(context),
    );

    if (sessions.isEmpty) {
      return InsightRootPage(
        title: 'Sessions',
        trailing: add,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: CupertinoIcons.calendar_badge_plus,
              title: 'No Sessions Yet',
              message:
                  'Add your class schedule so check-ins are grouped by class '
                  'and late arrivals are marked. Until then the kiosk records '
                  'general check-ins.',
              action: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(InsightRadii.capsule),
                onPressed: () => showSessionEditor(context),
                child: const Text('Add Session'),
              ),
            ),
          ),
        ],
      );
    }

    Widget content(Iterable<Attendance> records) => InsightRootPage(
      title: 'Sessions',
      trailing: add,
      slivers: [
        SliverToBoxAdapter(
          child: _SessionsBody(sessions: sessions, now: _now, records: records),
        ),
      ],
    );

    if (attendance == null) return content(const []);
    return StreamBuilder(
      stream: attendance.watch(),
      builder: (context, _) => content(attendance.values),
    );
  }
}

class _SessionsBody extends StatelessWidget {
  const _SessionsBody({
    required this.sessions,
    required this.now,
    required this.records,
  });

  final List<SessionEntry> sessions;
  final DateTime now;
  final Iterable<Attendance> records;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final todays = sessionsOn(sessions, now);
    final weekly = sessions.where((s) => !s.isOneOff).toList()
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    int byDateThenStart(SessionEntry a, SessionEntry b) {
      final d = a.date!.compareTo(b.date!);
      return d != 0 ? d : a.startMinuteOfDay.compareTo(b.startMinuteOfDay);
    }

    final upcoming =
        sessions.where((s) => s.isOneOff && !s.date!.isBefore(today)).toList()
          ..sort(byDateThenStart);
    final past =
        sessions.where((s) => s.isOneOff && s.date!.isBefore(today)).toList()
          ..sort((a, b) => byDateThenStart(b, a));

    // Distinct students checked in to each of today's sessions.
    final todaysCounts = <String, Set<String>>{};
    for (final r in records) {
      if (r.sessionTitle != null && isSameDay(r.timestamp, now)) {
        (todaysCounts[r.sessionTitle!] ??= {}).add(r.studentId);
      }
    }

    void edit(SessionEntry s) => showSessionEditor(context, session: s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsightListSection(
          header: 'Today',
          headerTrailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 28),
            onPressed: () => showSessionEditor(
              context,
              draft: draftSessionNow(DateTime.now()),
            ),
            child: Text('Start Now', style: InsightText.body),
          ),
          footer: todays.isEmpty
              ? null
              : 'A one-time session overrides the weekly schedule while it runs.',
          children: todays.isEmpty
              ? [
                  InsightRow(
                    title: 'No sessions today',
                    subtitle:
                        'Use Start Now when a class meets outside the '
                        'schedule.',
                  ),
                ]
              : [
                  for (final s in todays)
                    InsightRow(
                      leading: SessionStateBadge(session: s, now: now),
                      title: s.title,
                      subtitle: _todaySubtitle(
                        s,
                        todaysCounts[s.title]?.length ?? 0,
                      ),
                      value: formatSessionRange(s),
                      onTap: () => edit(s),
                    ),
                ],
        ),
        if (weekly.isNotEmpty)
          InsightListSection(
            header: 'Weekly Schedule',
            children: [
              for (final s in weekly)
                InsightRow(
                  leading: SymbolBadge(
                    CupertinoIcons.repeat,
                    InsightColors.accent.resolveFrom(context),
                  ),
                  title: s.title,
                  subtitle: [
                    formatWeekdays(s.weekdays),
                    if (s.room.isNotEmpty) s.room,
                  ].join(' · '),
                  value: formatSessionRange(s),
                  onTap: () => edit(s),
                ),
            ],
          ),
        if (upcoming.isNotEmpty)
          InsightListSection(
            header: 'One-Time Sessions',
            children: [
              for (final s in upcoming)
                InsightRow(
                  leading: SymbolBadge(
                    CupertinoIcons.calendar,
                    CupertinoColors.systemIndigo.resolveFrom(context),
                  ),
                  title: s.title,
                  subtitle: [
                    formatRecurrence(s, now),
                    if (s.room.isNotEmpty) s.room,
                  ].join(' · '),
                  value: formatSessionRange(s),
                  onTap: () => edit(s),
                ),
            ],
          ),
        if (past.isNotEmpty)
          InsightListSection(
            header: 'Past One-Time Sessions',
            footer: 'Deleting a past session keeps its check-ins.',
            children: [
              for (final s in past)
                InsightRow(
                  leading: SymbolBadge(
                    CupertinoIcons.calendar,
                    CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                  title: s.title,
                  subtitle: formatShortDate(s.date!, now),
                  value: formatSessionRange(s),
                  onTap: () => edit(s),
                ),
            ],
          ),
      ],
    );
  }

  String? _todaySubtitle(SessionEntry s, int checkedIn) {
    final started = minuteOfDay(now) >= s.startMinuteOfDay;
    final parts = [
      if (s.isOneOff) 'One-time',
      if (s.room.isNotEmpty) s.room,
      if (started) '$checkedIn checked in',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
