import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../providers/hive_provider.dart';
import '../providers/saved_filters_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/attendance_filter.dart';
import '../services/csv_export.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';
import 'attendance_filter_sheet.dart';

enum _SortBy { time, student, session, status }

/// Every check-in, filterable and exportable. Phones group check-ins by
/// day; wide windows show a sortable table.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  AttendanceFilter _filter = AttendanceFilter.defaults;
  _SortBy _sortBy = _SortBy.time;
  bool _ascending = false;

  static const double _tableWidth = 760;

  void _setFilter(AttendanceFilter f) => setState(() => _filter = f);

  void _sort(_SortBy by) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_sortBy == by) {
        _ascending = !_ascending;
      } else {
        _sortBy = by;
        // Newest first for time; A–Z for everything else.
        _ascending = by != _SortBy.time;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    if (students == null || attendance == null) {
      return const InsightRootPage(title: 'Attendance', slivers: []);
    }
    return StreamBuilder(
      stream: students.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) => _build(context, {
          for (final s in students.values) s.id: s.name,
        }, attendance.values),
      ),
    );
  }

  Widget _build(
    BuildContext context,
    Map<String, String> namesById,
    Iterable<Attendance> all,
  ) {
    final now = DateTime.now();
    final sessions = ref.watch(sessionsProvider);
    final sessionsByTitle = {for (final s in sessions) s.title: s};
    final sessionTitles = {
      ...sessions.map((s) => s.title),
      for (final r in all)
        if (r.sessionTitle != null && r.sessionTitle!.trim().isNotEmpty)
          r.sessionTitle!,
    }.toList()..sort();

    CheckInStatus statusOf(Attendance r) => checkInStatus(
      r,
      namesById: namesById,
      sessionsByTitle: sessionsByTitle,
    );

    final records = _filter.apply(
      all,
      namesById: namesById,
      sessionsByTitle: sessionsByTitle,
      now: now,
    );
    if (_sortBy != _SortBy.time || _ascending) {
      int compare(Attendance a, Attendance b) => switch (_sortBy) {
        _SortBy.time => a.timestamp.compareTo(b.timestamp),
        _SortBy.student =>
          (namesById[a.studentId] ?? a.studentId).toLowerCase().compareTo(
            (namesById[b.studentId] ?? b.studentId).toLowerCase(),
          ),
        _SortBy.session => (a.sessionTitle ?? '').compareTo(
          b.sessionTitle ?? '',
        ),
        _SortBy.status => statusOf(a).index.compareTo(statusOf(b).index),
      };
      records.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    }

    final lateCount = records
        .where((r) => statusOf(r) == CheckInStatus.late)
        .length;
    final studentCount = records.map((r) => r.studentId).toSet().length;

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SavedFiltersMenu(
          filter: _filter,
          onApply: (f) => _setFilter(f.copyWith(query: _filter.query)),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: _filter.hasRefinements
              ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
              : CupertinoIcons.line_horizontal_3_decrease_circle,
          semanticLabel: 'Filter',
          size: 36,
          onPressed: () async {
            final next = await showAttendanceFilterSheet(
              context,
              filter: _filter,
              sessionTitles: sessionTitles,
            );
            if (next != null) _setFilter(next);
          },
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: CupertinoIcons.square_arrow_up,
          semanticLabel: 'Export CSV',
          size: 36,
          onPressed: records.isEmpty
              ? null
              : () => _export(records, namesById, sessionsByTitle),
        ),
      ],
    );

    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CapsuleSegments<AttendanceRange>(
              value: _filter.range,
              segments: {
                AttendanceRange.today: 'Today',
                AttendanceRange.week: '7 Days',
                AttendanceRange.month: '30 Days',
                AttendanceRange.all: 'All',
                if (_filter.range == AttendanceRange.custom)
                  AttendanceRange.custom: 'Custom',
              },
              onChanged: (r) => _setFilter(_filter.copyWith(range: r)),
            ),
            _ActiveFilters(filter: _filter, now: now, onChanged: _setFilter),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(
                [
                  '${records.length} check-in${records.length == 1 ? '' : 's'}',
                  '$studentCount student${studentCount == 1 ? '' : 's'}',
                  if (lateCount > 0) '$lateCount late',
                ].join(' · '),
                style: InsightText.footnote.copyWith(
                  color: InsightColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final Widget body;
    if (records.isEmpty) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: CupertinoIcons.checkmark_seal,
          title: all.isEmpty ? 'No Check-ins Yet' : 'No Matches',
          message: all.isEmpty
              ? 'Check-ins appear here as students scan in at the kiosk.'
              : 'No check-ins match these filters.',
          action:
              all.isEmpty || !_filter.hasRefinements && _filter.query.isEmpty
              ? null
              : CupertinoButton.tinted(
                  borderRadius: BorderRadius.circular(InsightRadii.capsule),
                  onPressed: () => _setFilter(AttendanceFilter.defaults),
                  child: const Text('Reset Filters'),
                ),
        ),
      );
    } else {
      body = SliverLayoutBuilder(
        builder: (context, constraints) =>
            constraints.crossAxisExtent >= _tableWidth
            ? _TableSliver(
                records: records,
                namesById: namesById,
                statusOf: statusOf,
                sortBy: _sortBy,
                ascending: _ascending,
                onSort: _sort,
              )
            : _DayGroupedSliver(
                records: records,
                namesById: namesById,
                statusOf: statusOf,
                now: now,
              ),
      );
    }

    return InsightRootPage(
      title: 'Attendance',
      trailing: trailing,
      searchField: CupertinoSearchTextField(
        placeholder: 'Student name or ID',
        onChanged: (q) => _setFilter(_filter.copyWith(query: q)),
      ),
      maxContentWidth: 1200,
      slivers: [header, body],
    );
  }

  Future<void> _export(
    List<Attendance> records,
    Map<String, String> namesById,
    Map<String, SessionEntry> sessionsByTitle,
  ) async {
    final csv = attendanceCsv(
      records,
      namesById: namesById,
      sessionsByTitle: sessionsByTitle,
    );
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name =
        'insight-checkins-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.csv';
    String? location;
    Object? error;
    try {
      location = await exportCsv(csv, name);
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          error == null
              ? 'Exported ${records.length} Check-in${records.length == 1 ? '' : 's'}'
              : "Couldn't Export",
        ),
        content: Text(error == null ? 'Saved as $location' : '$error'),
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

/// Removable chips for the session, status and custom range in effect.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.now,
    required this.onChanged,
  });

  final AttendanceFilter filter;
  final DateTime now;
  final ValueChanged<AttendanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (filter.range == AttendanceRange.custom)
        _Chip(
          label: rangeLabel(filter, now),
          onRemove: () =>
              onChanged(filter.copyWith(range: AttendanceRange.week)),
        ),
      if (filter.session != null)
        _Chip(
          label: filter.session!,
          onRemove: () => onChanged(filter.copyWith(clearSession: true)),
        ),
      if (filter.status != null)
        _Chip(
          label: statusLabel(filter.status!),
          onRemove: () => onChanged(filter.copyWith(clearStatus: true)),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    return Semantics(
      button: true,
      label: 'Remove filter $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: accent.withValues(alpha: 0.14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InsightText.subheadline.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phones: one inset-grouped section per day, newest day first.
class _DayGroupedSliver extends StatelessWidget {
  const _DayGroupedSliver({
    required this.records,
    required this.namesById,
    required this.statusOf,
    required this.now,
  });

  final List<Attendance> records;
  final Map<String, String> namesById;
  final CheckInStatus Function(Attendance) statusOf;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = <DateTime, List<Attendance>>{};
    for (final r in records) {
      final day = DateTime(
        r.timestamp.year,
        r.timestamp.month,
        r.timestamp.day,
      );
      (days[day] ??= []).add(r);
    }
    final entries = days.entries.toList();

    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final day = entries[i].key;
        final items = entries[i].value;
        return InsightListSection(
          header: _dayLabel(day, now),
          headerTrailing: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${items.length}',
              style: InsightText.subheadline.copyWith(
                color: InsightColors.secondaryLabel.resolveFrom(context),
                fontFeatures: InsightText.tabular,
              ),
            ),
          ),
          dividerInset: 61,
          children: [
            for (final r in items)
              InsightRow(
                leading: InitialsAvatar(
                  name: namesById[r.studentId] ?? '?',
                  size: 30,
                ),
                title: namesById[r.studentId] ?? 'Unknown student',
                subtitle: [
                  r.sessionTitle ?? 'General check-in',
                  if (r.room != null && r.room!.isNotEmpty) r.room!,
                ].join(' · '),
                trailing: _TimeAndStatus(
                  time: r.timestamp,
                  status: statusOf(r),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _dayLabel(DateTime day, DateTime now) {
    if (isSameDay(day, now)) return 'Today';
    if (isSameDay(day, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return formatShortDate(day, now);
  }
}

class _TimeAndStatus extends StatelessWidget {
  const _TimeAndStatus({required this.time, required this.status});

  final DateTime time;
  final CheckInStatus status;

  @override
  Widget build(BuildContext context) {
    final flag = switch (status) {
      CheckInStatus.late => (
        'Late',
        InsightColors.warning.resolveFrom(context),
      ),
      CheckInStatus.unknownStudent => (
        'Deleted',
        InsightColors.danger.resolveFrom(context),
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatClock(time),
          style: InsightText.subheadline.copyWith(
            color: InsightColors.secondaryLabel.resolveFrom(context),
            fontFeatures: InsightText.tabular,
          ),
        ),
        if (flag != null)
          Text(
            flag.$1,
            style: InsightText.footnote.copyWith(
              color: flag.$2,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Wide windows: a sortable table, built lazily row by row.
class _TableSliver extends StatelessWidget {
  const _TableSliver({
    required this.records,
    required this.namesById,
    required this.statusOf,
    required this.sortBy,
    required this.ascending,
    required this.onSort,
  });

  final List<Attendance> records;
  final Map<String, String> namesById;
  final CheckInStatus Function(Attendance) statusOf;
  final _SortBy sortBy;
  final bool ascending;
  final ValueChanged<_SortBy> onSort;

  static const _flex = [4, 4, 3, 2, 2];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children:
                    [
                          _HeaderCell('Student', _SortBy.student, _flex[0]),
                          _HeaderCell('Session', _SortBy.session, _flex[1]),
                          _HeaderCell('Date & Time', _SortBy.time, _flex[2]),
                          _HeaderCell('Status', _SortBy.status, _flex[3]),
                          _HeaderCell('Scan', null, _flex[4], alignEnd: true),
                        ]
                        .map((c) => c.build(context, sortBy, ascending, onSort))
                        .toList(),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: records.length,
            itemBuilder: (context, i) => _TableRow(
              record: records[i],
              name: namesById[records[i].studentId],
              status: statusOf(records[i]),
              first: i == 0,
              last: i == records.length - 1,
              flex: _flex,
              now: now,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell {
  const _HeaderCell(this.label, this.sort, this.flex, {this.alignEnd = false});

  final String label;
  final _SortBy? sort;
  final int flex;
  final bool alignEnd;

  Widget build(
    BuildContext context,
    _SortBy current,
    bool ascending,
    ValueChanged<_SortBy> onSort,
  ) {
    final active = sort != null && sort == current;
    final color = active
        ? InsightColors.accent.resolveFrom(context)
        : InsightColors.secondaryLabel.resolveFrom(context);
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: InsightText.footnote.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (active) ...[
          const SizedBox(width: 3),
          Icon(
            ascending ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 11,
            color: color,
          ),
        ],
      ],
    );
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: sort == null
            ? text
            : MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Semantics(
                  button: true,
                  label: 'Sort by $label',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSort(sort!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: text,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.record,
    required this.name,
    required this.status,
    required this.first,
    required this.last,
    required this.flex,
    required this.now,
  });

  final Attendance record;
  final String? name;
  final CheckInStatus status;
  final bool first;
  final bool last;
  final List<int> flex;
  final DateTime now;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    const radius = Radius.circular(InsightRadii.card);

    final statusColor = switch (widget.status) {
      CheckInStatus.onTime => InsightColors.success.resolveFrom(context),
      CheckInStatus.late => InsightColors.warning.resolveFrom(context),
      CheckInStatus.general => CupertinoColors.systemGrey.resolveFrom(context),
      CheckInStatus.unknownStudent => InsightColors.danger.resolveFrom(context),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hover
              ? Color.alphaBlend(
                  InsightColors.fill.resolveFrom(context),
                  InsightColors.card.resolveFrom(context),
                )
              : InsightColors.card.resolveFrom(context),
          borderRadius: BorderRadius.vertical(
            top: widget.first ? radius : Radius.zero,
            bottom: widget.last ? radius : Radius.zero,
          ),
        ),
        child: Column(
          children: [
            if (!widget.first)
              Container(
                height: 0.5,
                margin: const EdgeInsets.only(left: 16),
                color: InsightColors.separator.resolveFrom(context),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: widget.flex[0],
                    child: Row(
                      children: [
                        InitialsAvatar(name: widget.name ?? '?', size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name ?? 'Unknown student',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: InsightText.subheadline.copyWith(
                                  color: label,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                r.studentId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: InsightText.footnote.copyWith(
                                  color: secondary,
                                  fontFeatures: InsightText.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: widget.flex[1],
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        r.sessionTitle ?? 'General check-in',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InsightText.subheadline.copyWith(
                          color: r.sessionTitle == null ? secondary : label,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: widget.flex[2],
                    child: Text(
                      '${formatShortDate(r.timestamp, widget.now)}, '
                      '${formatClock(r.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: InsightText.subheadline.copyWith(
                        color: label,
                        fontFeatures: InsightText.tabular,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: widget.flex[3],
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        label: statusLabel(widget.status),
                        color: statusColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: widget.flex[4],
                    child: Text(
                      r.latencyMs == null ? '–' : '${r.latencyMs} ms',
                      textAlign: TextAlign.end,
                      style: InsightText.subheadline.copyWith(
                        color: secondary,
                        fontFeatures: InsightText.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bookmark pull-down: apply a saved filter, save the current one, or
/// delete one.
class _SavedFiltersMenu extends ConsumerWidget {
  const _SavedFiltersMenu({required this.filter, required this.onApply});

  final AttendanceFilter filter;
  final ValueChanged<AttendanceFilter> onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedFiltersProvider);
    final accent = InsightColors.accent.resolveFrom(context);
    final matching = saved.where((s) => s.filter.sameAs(filter)).firstOrNull;

    return CupertinoMenuAnchor(
      menuChildren: [
        for (final s in saved)
          CupertinoMenuItem(
            trailing: s == matching
                ? Icon(CupertinoIcons.checkmark, size: 17, color: accent)
                : null,
            onPressed: () => onApply(s.filter),
            child: Text(s.name),
          ),
        if (saved.isNotEmpty) const CupertinoMenuDivider(),
        CupertinoMenuItem(
          leading: const Icon(CupertinoIcons.bookmark),
          onPressed: () => _saveCurrent(context, ref),
          child: const Text('Save Current Filter…'),
        ),
        if (saved.isNotEmpty)
          CupertinoMenuItem(
            leading: const Icon(CupertinoIcons.trash),
            isDestructiveAction: true,
            onPressed: () => _deleteOne(context, ref, saved),
            child: const Text('Delete a Saved Filter…'),
          ),
      ],
      builder: (context, controller, _) => GlassIconButton(
        icon: matching != null
            ? CupertinoIcons.bookmark_fill
            : CupertinoIcons.bookmark,
        semanticLabel: 'Saved Filters',
        size: 36,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final controller = TextEditingController(
      text: [
        rangeLabel(filter, now),
        ?filter.session,
        if (filter.status != null) statusLabel(filter.status!),
      ].join(' · '),
    );
    final save = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Save Filter'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'Name',
            clearButtonMode: OverlayVisibilityMode.editing,
            onSubmitted: (_) => Navigator.of(context).pop(true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (save == true && name.isNotEmpty) {
      await ref.read(savedFiltersProvider.notifier).save(name, filter);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    List<SavedAttendanceFilter> saved,
  ) async {
    final name = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Delete a Saved Filter'),
        actions: [
          for (final s in saved)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(s.name),
              child: Text(s.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (name != null) {
      await ref.read(savedFiltersProvider.notifier).delete(name);
    }
  }
}
