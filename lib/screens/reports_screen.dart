import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/report_data.dart';
import '../ui/insight_ui.dart';

/// Trends across days: how many attend, how punctual they are, how each
/// session and student is doing, and how fast recognition runs. One filter
/// row scopes every chart.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.week;
  String? _session;

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    if (students == null || attendance == null) {
      return const InsightRootPage(title: 'Reports', slivers: []);
    }
    return StreamBuilder(
      stream: students.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) =>
            _build(context, students.values.toList(), attendance.values),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    List<Student> students,
    Iterable<Attendance> attendance,
  ) {
    final sessions = ref.watch(sessionsProvider);
    if (attendance.isEmpty) {
      return const InsightRootPage(
        title: 'Reports',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: CupertinoIcons.chart_bar,
              title: 'No Data Yet',
              message:
                  'Reports fill in once students start checking in at the '
                  'kiosk.',
            ),
          ),
        ],
      );
    }

    final sessionTitles = {
      ...sessions.map((s) => s.title),
      ...attendance.map((a) => a.sessionTitle).whereType<String>(),
    }.toList()..sort();
    final data = ReportData.compute(
      students: students,
      attendance: attendance,
      sessions: sessions,
      range: _range,
      now: DateTime.now(),
      session: _session,
    );

    return InsightRootPage(
      title: 'Reports',
      maxContentWidth: 1200,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _FilterRow(
              range: _range,
              session: _session,
              sessionTitles: sessionTitles,
              onRange: (r) => setState(() => _range = r),
              onSession: (s) => setState(() => _session = s),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Kpis(data: data),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ChartGrid(data: data),
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.range,
    required this.session,
    required this.sessionTitles,
    required this.onRange,
    required this.onSession,
  });

  final ReportRange range;
  final String? session;
  final List<String> sessionTitles;
  final ValueChanged<ReportRange> onRange;
  final ValueChanged<String?> onSession;

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    Widget? check(bool on) =>
        on ? Icon(CupertinoIcons.checkmark, size: 17, color: accent) : null;

    final segments = CapsuleSegments<ReportRange>(
      value: range,
      segments: {for (final r in ReportRange.values) r: r.label},
      onChanged: onRange,
    );
    final picker = CupertinoMenuAnchor(
      menuChildren: [
        CupertinoMenuItem(
          trailing: check(session == null),
          onPressed: () => onSession(null),
          child: const Text('All Sessions'),
        ),
        for (final t in sessionTitles)
          CupertinoMenuItem(
            trailing: check(session == t),
            onPressed: () => onSession(t),
            child: Text(t),
          ),
      ],
      builder: (context, controller, _) => CupertinoButton.tinted(
        sizeStyle: CupertinoButtonSize.small,
        borderRadius: BorderRadius.circular(InsightRadii.capsule),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                session ?? 'All Sessions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_down, size: 13),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [segments, const SizedBox(height: 10), picker],
          );
        }
        return Row(
          children: [
            Expanded(child: segments),
            const SizedBox(width: 12),
            picker,
          ],
        );
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.data});

  final ReportData data;

  String _pct(double v) => '${(v * 100).round()}%';

  /// "▲ 4 pts vs previous 7 days"; null when there's nothing to compare.
  String? _pointsDelta(double? now, double? before) {
    if (now == null || before == null) return null;
    final pts = ((now - before) * 100).round();
    if (pts == 0) return 'Same as ${data.range.previousLabel}';
    return '${pts > 0 ? '▲' : '▼'} ${pts.abs()} pts vs ${data.range.previousLabel}';
  }

  String? _countDelta(int now, int? before) {
    if (before == null || before == 0) return null;
    final pct = ((now - before) / before * 100).round();
    if (pct == 0) return 'Same as ${data.range.previousLabel}';
    return '${pct > 0 ? '▲' : '▼'} ${pct.abs()}% vs ${data.range.previousLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        icon: CupertinoIcons.person_2_fill,
        color: InsightColors.accent.resolveFrom(context),
        label: 'Attendance',
        value: data.attendanceRate == null ? '–' : _pct(data.attendanceRate!),
        detail:
            _pointsDelta(data.attendanceRate, data.previousAttendanceRate) ??
            'present on class days',
      ),
      StatTile(
        icon: CupertinoIcons.checkmark_seal_fill,
        color: InsightColors.success.resolveFrom(context),
        label: 'Check-ins',
        value: '${data.checkIns}',
        detail:
            _countDelta(data.checkIns, data.previousCheckIns) ??
            '${data.studentsSeen} students',
      ),
      StatTile(
        icon: CupertinoIcons.clock_fill,
        color: InsightColors.warning.resolveFrom(context),
        label: 'Late',
        value: data.lateShare == null ? '–' : _pct(data.lateShare!),
        detail:
            _pointsDelta(data.lateShare, data.previousLateShare) ??
            'of timed check-ins',
      ),
      StatTile(
        icon: CupertinoIcons.bolt_fill,
        color: CupertinoColors.systemPurple.resolveFrom(context),
        label: 'Avg. Scan',
        value: data.averageScanMs == null ? '–' : '${data.averageScanMs} ms',
        detail: 'capture to record',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 720 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _ChartGrid extends StatelessWidget {
  const _ChartGrid({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final primary = ChartColors.primary.resolveFrom(context);
    final late = ChartColors.late.resolveFrom(context);
    final unit = data.weekly ? 'week' : 'day';

    final checkIns = ChartCard(
      title: 'Check-ins',
      subtitle: 'Per $unit, on time and late',
      legend: ChartLegend(
        series: [ChartSeries('On time', primary), ChartSeries('Late', late)],
      ),
      chart: ColumnChart(
        labels: [for (final b in data.buckets) b.label],
        values: [
          for (final b in data.buckets)
            [b.onTime.toDouble(), b.late.toDouble()],
        ],
        series: [ChartSeries('On time', primary), ChartSeries('Late', late)],
      ),
      tableHeaders: [
        data.weekly ? 'Week of' : 'Day',
        'On time',
        'Late',
        'Total',
      ],
      tableRows: [
        for (final b in data.buckets.reversed)
          [b.label, '${b.onTime}', '${b.late}', '${b.total}'],
      ],
    );

    final arrivals = ChartCard(
      title: 'Arrival Times',
      subtitle: 'Minutes after the session starts',
      chart: ColumnChart(
        labels: [for (final b in arrivalBins) b.$1],
        values: [
          for (final n in data.arrivals) [n.toDouble()],
        ],
        series: [ChartSeries('Check-ins', primary)],
      ),
      tableHeaders: const ['Minutes', 'Check-ins'],
      tableRows: [
        for (var i = 0; i < arrivalBins.length; i++)
          [arrivalBins[i].$1, '${data.arrivals[i]}'],
      ],
    );

    final scans = [for (final b in data.buckets) b.averageScanMs?.toDouble()];
    final scanTime = ChartCard(
      title: 'Recognition Speed',
      subtitle: 'Average capture-to-record time per $unit',
      chart: LineChart(
        labels: [for (final b in data.buckets) b.label],
        values: scans,
        color: primary,
        seriesLabel: 'Avg. scan',
        format: (v) => '${v.round()} ms',
      ),
      tableHeaders: [data.weekly ? 'Week of' : 'Day', 'Avg. scan'],
      tableRows: [
        for (final b in data.buckets.reversed)
          if (b.averageScanMs != null) [b.label, '${b.averageScanMs} ms'],
      ],
    );

    final bySession = _SessionsCard(sessions: data.sessions);
    final followUp = _FollowUpCard(
      followUp: data.followUp,
      classDays: data.classDays,
    );

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final w in [
                checkIns,
                arrivals,
                bySession,
                followUp,
                scanTime,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: w,
                ),
            ],
          );
        }
        Widget pair(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: gap),
              Expanded(child: b),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: checkIns,
            ),
            pair(arrivals, scanTime),
            pair(bySession, followUp),
          ],
        );
      },
    );
  }
}

/// A labelled horizontal meter: the fill on a lighter track of the same
/// hue, so the whole bar reads as one quantity.
class _Meter extends StatelessWidget {
  const _Meter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(InsightRadii.capsule),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: 0.18)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsCard extends StatelessWidget {
  const _SessionsCard({required this.sessions});

  final List<SessionReport> sessions;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final primary = ChartColors.primary.resolveFrom(context);
    return _ListCard(
      title: 'By Session',
      subtitle: 'Average share of the class present, lowest first',
      empty: 'No session check-ins in this range.',
      children: [
        for (final s in sessions)
          Semantics(
            label:
                '${s.title}: ${(s.rate * 100).round()} percent present, '
                '${s.meetings} meetings',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InsightText.subheadline.copyWith(color: label),
                      ),
                    ),
                    Text(
                      '${(s.rate * 100).round()}%',
                      style: InsightText.subheadline.copyWith(
                        color: label,
                        fontWeight: FontWeight.w600,
                        fontFeatures: InsightText.tabular,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _Meter(fraction: s.rate, color: primary),
                const SizedBox(height: 4),
                Text(
                  'Avg. ${s.averagePresent.toStringAsFixed(1)} present · '
                  '${s.meetings} meeting${s.meetings == 1 ? '' : 's'} · '
                  '${(s.lateShare * 100).round()}% late',
                  style: InsightText.footnote.copyWith(color: secondary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({required this.followUp, required this.classDays});

  final List<StudentPresence> followUp;
  final int classDays;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final primary = ChartColors.primary.resolveFrom(context);
    return _ListCard(
      title: 'Needs Follow-up',
      subtitle:
          'Lowest presence across $classDays class day${classDays == 1 ? '' : 's'}',
      empty: classDays < 2
          ? 'Appears after two or more class days.'
          : 'Everyone attended every class day.',
      children: [
        for (final p in followUp)
          Semantics(
            label:
                '${p.student.name}: present ${p.daysPresent} of '
                '${p.classDays} class days',
            excludeSemantics: true,
            child: Row(
              children: [
                InitialsAvatar(name: p.student.name, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: InsightText.subheadline.copyWith(
                                color: label,
                              ),
                            ),
                          ),
                          Text(
                            '${p.daysPresent} of ${p.classDays}',
                            style: InsightText.subheadline.copyWith(
                              color: label,
                              fontWeight: FontWeight.w600,
                              fontFeatures: InsightText.tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _Meter(fraction: p.rate, color: primary),
                      if (p.lateCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${p.lateCount} late',
                          style: InsightText.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.subtitle,
    required this.empty,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    return InsightCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: InsightText.headline.copyWith(
              color: InsightColors.label.resolveFrom(context),
            ),
          ),
          Text(
            subtitle,
            style: InsightText.footnote.copyWith(color: secondary),
          ),
          const SizedBox(height: 16),
          if (children.isEmpty)
            Text(
              empty,
              style: InsightText.subheadline.copyWith(color: secondary),
            )
          else
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
        ],
      ),
    );
  }
}
