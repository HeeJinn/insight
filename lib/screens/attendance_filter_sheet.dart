import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../services/attendance_filter.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';

/// Edits a copy of [filter]; resolves to the new filter on Done, or null
/// when cancelled.
Future<AttendanceFilter?> showAttendanceFilterSheet(
  BuildContext context, {
  required AttendanceFilter filter,
  required List<String> sessionTitles,
}) {
  return showInsightSheet<AttendanceFilter>(
    context,
    builder: (context, controller) => _FilterSheet(
      initial: filter,
      sessionTitles: sessionTitles,
      controller: controller,
    ),
  );
}

enum _DatePicker { none, start, end }

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.sessionTitles,
    required this.controller,
  });

  final AttendanceFilter initial;
  final List<String> sessionTitles;
  final ScrollController? controller;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late AttendanceFilter _filter = widget.initial;
  _DatePicker _picker = _DatePicker.none;

  void _set(AttendanceFilter next) {
    HapticFeedback.selectionClick();
    setState(() => _filter = next);
  }

  void _chooseRange(AttendanceRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _set(
      _filter.copyWith(
        range: range,
        // A custom range starts as the last week, ready to adjust.
        customStart: range == AttendanceRange.custom
            ? (_filter.customStart ?? today.subtract(const Duration(days: 6)))
            : null,
        customEnd: range == AttendanceRange.custom
            ? (_filter.customEnd ?? today)
            : null,
      ),
    );
    if (range != AttendanceRange.custom) _picker = _DatePicker.none;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final accent = InsightColors.accent.resolveFrom(context);
    Widget? check(bool on) =>
        on ? Icon(CupertinoIcons.checkmark, size: 18, color: accent) : null;

    final start = _filter.customStart ?? today;
    final end = _filter.customEnd ?? today;

    return CupertinoPageScaffold(
      backgroundColor: InsightColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        border: null,
        backgroundColor: const Color(0x00000000),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        leading: Align(
          widthFactor: 1,
          child: GlassIconButton(
            icon: CupertinoIcons.xmark,
            semanticLabel: 'Cancel',
            size: 36,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        middle: const Text('Filter'),
        trailing: CupertinoButton.filled(
          sizeStyle: CupertinoButtonSize.small,
          borderRadius: BorderRadius.circular(InsightRadii.capsule),
          onPressed: () => Navigator.of(context).pop(_filter),
          child: const Text('Done'),
        ),
      ),
      child: ListView(
        controller: widget.controller,
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.paddingOf(context).top + 44,
          0,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          InsightListSection(
            header: 'Date Range',
            dividerInset: 16,
            children: [
              for (final (range, label) in const [
                (AttendanceRange.today, 'Today'),
                (AttendanceRange.week, 'Last 7 Days'),
                (AttendanceRange.month, 'Last 30 Days'),
                (AttendanceRange.all, 'All Time'),
                (AttendanceRange.custom, 'Custom Range'),
              ])
                InsightRow(
                  title: label,
                  showChevron: false,
                  trailing: check(_filter.range == range),
                  onTap: () => _chooseRange(range),
                ),
              if (_filter.range == AttendanceRange.custom) ...[
                _DateRow(
                  title: 'From',
                  value: formatShortDate(start, now),
                  open: _picker == _DatePicker.start,
                  onTap: () => setState(
                    () => _picker = _picker == _DatePicker.start
                        ? _DatePicker.none
                        : _DatePicker.start,
                  ),
                ),
                if (_picker == _DatePicker.start)
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: start,
                      maximumDate: today,
                      onDateTimeChanged: (d) => setState(() {
                        final day = DateTime(d.year, d.month, d.day);
                        _filter = _filter.copyWith(
                          customStart: day,
                          // Keep the range the right way round.
                          customEnd: end.isBefore(day) ? day : end,
                        );
                      }),
                    ),
                  ),
                _DateRow(
                  title: 'To',
                  value: formatShortDate(end, now),
                  open: _picker == _DatePicker.end,
                  onTap: () => setState(
                    () => _picker = _picker == _DatePicker.end
                        ? _DatePicker.none
                        : _DatePicker.end,
                  ),
                ),
                if (_picker == _DatePicker.end)
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: end,
                      minimumDate: start,
                      maximumDate: today,
                      onDateTimeChanged: (d) => setState(
                        () => _filter = _filter.copyWith(
                          customEnd: DateTime(d.year, d.month, d.day),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          InsightListSection(
            header: 'Session',
            dividerInset: 16,
            children: [
              InsightRow(
                title: 'All Sessions',
                showChevron: false,
                trailing: check(_filter.session == null),
                onTap: () => _set(_filter.copyWith(clearSession: true)),
              ),
              for (final title in widget.sessionTitles)
                InsightRow(
                  title: title,
                  showChevron: false,
                  trailing: check(_filter.session == title),
                  onTap: () => _set(_filter.copyWith(session: title)),
                ),
            ],
          ),
          InsightListSection(
            header: 'Status',
            dividerInset: 16,
            footer:
                'General check-ins were recorded with no session running. '
                'Unknown students have since been deleted.',
            children: [
              InsightRow(
                title: 'Any Status',
                showChevron: false,
                trailing: check(_filter.status == null),
                onTap: () => _set(_filter.copyWith(clearStatus: true)),
              ),
              for (final status in CheckInStatus.values)
                InsightRow(
                  title: _titleCase(statusLabel(status)),
                  showChevron: false,
                  trailing: check(_filter.status == status),
                  onTap: () => _set(_filter.copyWith(status: status)),
                ),
            ],
          ),
          InsightListSection(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () => Navigator.of(
                  context,
                ).pop(AttendanceFilter.defaults.copyWith(query: _filter.query)),
                child: Text(
                  'Reset Filters',
                  style: InsightText.body.copyWith(
                    color: InsightColors.danger.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.title,
    required this.value,
    required this.open,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InsightRow(
      title: title,
      showChevron: false,
      onTap: onTap,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: InsightColors.fill.resolveFrom(context),
        ),
        child: Text(
          value,
          style: InsightText.body.copyWith(
            color: open
                ? InsightColors.accent.resolveFrom(context)
                : InsightColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
