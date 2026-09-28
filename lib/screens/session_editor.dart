import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/session_entry.dart';
import '../providers/sessions_provider.dart';
import '../providers/settings_provider.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';

/// Opens the editor for [session], or for a new session. [draft] prefills
/// a new one, e.g. a one-off starting now.
Future<void> showSessionEditor(
  BuildContext context, {
  SessionEntry? session,
  SessionEntry? draft,
}) {
  return showInsightSheet<void>(
    context,
    builder: (context, controller) => _SessionEditor(
      existing: session,
      initial: session ?? draft,
      controller: controller,
    ),
  );
}

/// A one-off session starting now, for when a class meets outside the
/// weekly schedule.
SessionEntry draftSessionNow(DateTime now) {
  final start = minuteOfDay(now);
  return SessionEntry(
    id: '',
    title: '',
    room: '',
    startMinuteOfDay: start,
    endMinuteOfDay: (start + 60).clamp(0, 24 * 60 - 1),
    expected: 0,
    date: DateTime(now.year, now.month, now.day),
  );
}

enum _Repeat { weekly, once }

enum _Picker { none, date, start, end }

class _SessionEditor extends ConsumerStatefulWidget {
  const _SessionEditor({
    required this.existing,
    required this.initial,
    required this.controller,
  });

  final SessionEntry? existing;
  final SessionEntry? initial;
  final ScrollController? controller;

  @override
  ConsumerState<_SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends ConsumerState<_SessionEditor> {
  late final TextEditingController _title;
  late final TextEditingController _room;
  late final TextEditingController _expected;
  late _Repeat _repeat;
  late Set<int> _weekdays;
  late DateTime _date;
  late int _start;
  late int _end;
  late int _lateAfter;
  _Picker _picker = _Picker.none;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final now = DateTime.now();
    _title = TextEditingController(text: s?.title ?? '')..addListener(_rebuild);
    _room = TextEditingController(text: s?.room ?? '');
    _expected = TextEditingController(
      text: (s?.expected ?? 0) > 0 ? '${s!.expected}' : '',
    );
    _repeat = s?.isOneOff ?? false ? _Repeat.once : _Repeat.weekly;
    // New weekly sessions default to weekdays. A session saved before
    // repeat days existed arrives as every day and keeps that.
    _weekdays = s == null || s.isOneOff ? {1, 2, 3, 4, 5} : {...s.weekdays};
    _date = s?.date ?? DateTime(now.year, now.month, now.day);
    _start = s?.startMinuteOfDay ?? 9 * 60;
    _end = s?.endMinuteOfDay ?? 10 * 60 + 30;
    // New sessions, drafts included, start from the default in Settings.
    _lateAfter =
        widget.existing?.lateAfterMinutes ?? ref.read(defaultLateAfterProvider);
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _expected.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String? get _problem {
    if (_end <= _start) return 'The session has to end after it starts.';
    if (_repeat == _Repeat.weekly && _weekdays.isEmpty) {
      return 'Choose at least one day.';
    }
    return null;
  }

  bool get _canSave => _title.text.trim().isNotEmpty && _problem == null;

  SessionEntry _build() {
    return SessionEntry(
      id:
          widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      room: _room.text.trim(),
      startMinuteOfDay: _start,
      endMinuteOfDay: _end,
      expected: int.tryParse(_expected.text.trim()) ?? 0,
      weekdays: _repeat == _Repeat.weekly ? _weekdays : SessionEntry.everyDay,
      date: _repeat == _Repeat.once ? _date : null,
      lateAfterMinutes: _lateAfter,
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final sessions = ref.read(sessionsProvider.notifier);
    final session = _build();
    if (_isNew) {
      await sessions.addSession(session);
    } else {
      await sessions.updateSession(session);
    }
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endNow() async {
    final now = minuteOfDay(DateTime.now());
    final existing = widget.existing!;
    await ref
        .read(sessionsProvider.notifier)
        .updateSession(
          existing.copyWith(
            endMinuteOfDay: now.clamp(existing.startMinuteOfDay, 24 * 60 - 1),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Delete ${existing.title}?'),
        message: const Text(
          'Check-ins already recorded for it stay in attendance records.',
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete Session'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionsProvider.notifier).removeSession(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _togglePicker(_Picker picker) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _picker = _picker == picker ? _Picker.none : picker);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final existing = widget.existing;
    final runningNow =
        existing != null &&
        existing.occursOn(now) &&
        activeSessionAt([existing], now) != null;
    final problem = _problem;
    final danger = InsightColors.danger.resolveFrom(context);

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
        middle: Text(_isNew ? 'New Session' : 'Edit Session'),
        trailing: CupertinoButton.filled(
          sizeStyle: CupertinoButtonSize.small,
          borderRadius: BorderRadius.circular(InsightRadii.capsule),
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ),
      child: ListView(
        controller: widget.controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.paddingOf(context).top + 52,
          0,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        children: [
          InsightListSection(
            dividerInset: 16,
            children: [
              _TextRow(
                controller: _title,
                placeholder: 'Class Name',
                autofocus: _isNew,
                capitalization: TextCapitalization.words,
              ),
              _TextRow(
                controller: _room,
                placeholder: 'Room (optional)',
                capitalization: TextCapitalization.words,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: CapsuleSegments<_Repeat>(
              value: _repeat,
              segments: const {
                _Repeat.weekly: 'Every Week',
                _Repeat.once: 'One Time',
              },
              onChanged: (r) => setState(() {
                _repeat = r;
                _picker = _Picker.none;
              }),
            ),
          ),
          if (_repeat == _Repeat.weekly)
            InsightListSection(
              header: 'Repeats',
              footer: _weekdays.isEmpty ? null : formatWeekdays(_weekdays),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: _WeekdayPicker(
                    selected: _weekdays,
                    onToggle: (d) => setState(() {
                      _weekdays = {..._weekdays};
                      if (!_weekdays.remove(d)) _weekdays.add(d);
                    }),
                  ),
                ),
              ],
            )
          else
            InsightListSection(
              header: 'Date',
              dividerInset: 16,
              children: [
                _PickerRow(
                  title: 'Date',
                  value: formatShortDate(_date, now),
                  open: _picker == _Picker.date,
                  onTap: () => _togglePicker(_Picker.date),
                ),
                if (_picker == _Picker.date)
                  SizedBox(
                    height: 216,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _date,
                      minimumDate: DateTime(now.year, now.month, now.day),
                      onDateTimeChanged: (d) => setState(
                        () => _date = DateTime(d.year, d.month, d.day),
                      ),
                    ),
                  ),
              ],
            ),
          InsightListSection(
            header: 'Time',
            dividerInset: 16,
            footer: problem,
            children: [
              _PickerRow(
                title: 'Starts',
                value: formatMinuteOfDay(_start),
                open: _picker == _Picker.start,
                onTap: () => _togglePicker(_Picker.start),
              ),
              if (_picker == _Picker.start)
                _TimePicker(
                  minute: _start,
                  onChanged: (m) => setState(() {
                    // Keep the length when moving the start.
                    final length = _end - _start;
                    _start = m;
                    if (length > 0) {
                      _end = (m + length).clamp(0, 24 * 60 - 1);
                    }
                  }),
                ),
              _PickerRow(
                title: 'Ends',
                value: formatMinuteOfDay(_end),
                open: _picker == _Picker.end,
                invalid: _end <= _start,
                onTap: () => _togglePicker(_Picker.end),
              ),
              if (_picker == _Picker.end)
                _TimePicker(
                  minute: _end,
                  onChanged: (m) => setState(() => _end = m),
                ),
            ],
          ),
          InsightListSection(
            header: 'Check-in',
            dividerInset: 16,
            footer:
                'Check-ins after the late cutoff are marked Late. Expected '
                'students sets the headcount; leave it empty to count '
                'everyone enrolled.',
            children: [
              _LateAfterRow(
                value: _lateAfter,
                onChanged: (v) => setState(() => _lateAfter = v),
              ),
              InsightRow(
                title: 'Expected Students',
                trailing: SizedBox(
                  width: 80,
                  child: CupertinoTextField(
                    controller: _expected,
                    placeholder: 'All',
                    decoration: null,
                    textAlign: TextAlign.end,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    style: InsightText.body.copyWith(
                      color: InsightColors.secondaryLabel.resolveFrom(context),
                      fontFeatures: InsightText.tabular,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (existing != null) ...[
            if (runningNow && existing.isOneOff)
              InsightListSection(
                footer: 'Stops check-ins for this session now.',
                children: [
                  _CenteredAction(
                    label: 'End Session Now',
                    color: InsightColors.accent.resolveFrom(context),
                    onTap: _endNow,
                  ),
                ],
              ),
            InsightListSection(
              children: [
                _CenteredAction(
                  label: 'Delete Session',
                  color: danger,
                  onTap: _delete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.controller,
    required this.placeholder,
    this.autofocus = false,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool autofocus;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      autofocus: autofocus,
      decoration: null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      clearButtonMode: OverlayVisibilityMode.editing,
      style: InsightText.body.copyWith(
        color: InsightColors.label.resolveFrom(context),
      ),
    );
  }
}

/// A row whose value opens an inline picker beneath it, as Calendar does.
/// The value turns accent-colored while its picker is open.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.title,
    required this.value,
    required this.open,
    required this.onTap,
    this.invalid = false,
  });

  final String title;
  final String value;
  final bool open;
  final bool invalid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (invalid) {
      color = InsightColors.danger.resolveFrom(context);
    } else if (open) {
      color = InsightColors.accent.resolveFrom(context);
    } else {
      color = InsightColors.label.resolveFrom(context);
    }
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
            color: color,
            fontFeatures: InsightText.tabular,
          ),
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.minute, required this.onChanged});

  final int minute;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 216,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: DateTime(2000, 1, 1, minute ~/ 60, minute % 60),
        onDateTimeChanged: (d) => onChanged(d.hour * 60 + d.minute),
      ),
    );
  }
}

/// Seven round toggles, Monday first, like the Clock app's repeat days.
class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    final fill = InsightColors.fill.resolveFrom(context);
    final label = InsightColors.label.resolveFrom(context);
    return LayoutBuilder(
      builder: (context, c) {
        // 40pt circles where they fit, smaller on the narrowest phones.
        final size = ((c.maxWidth - 6 * 4) / 7).clamp(28.0, 40.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var d = 1; d <= 7; d++)
              Semantics(
                button: true,
                selected: selected.contains(d),
                label: _names[d - 1],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggle(d);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected.contains(d) ? accent : fill,
                    ),
                    child: Text(
                      _letters[d - 1],
                      style: InsightText.headline.copyWith(
                        color: selected.contains(d)
                            ? CupertinoColors.white
                            : label,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LateAfterRow extends StatelessWidget {
  const _LateAfterRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [0, 5, 10, 15, 20, 30, 45];

  static String _label(int m) => m == 0 ? 'At start' : '$m min';

  @override
  Widget build(BuildContext context) {
    final accent = InsightColors.accent.resolveFrom(context);
    return CupertinoMenuAnchor(
      menuChildren: [
        for (final m in _options)
          CupertinoMenuItem(
            trailing: m == value
                ? Icon(CupertinoIcons.checkmark, size: 17, color: accent)
                : null,
            onPressed: () => onChanged(m),
            child: Text(m == 0 ? 'At the start' : '$m minutes after start'),
          ),
      ],
      builder: (context, controller, _) => InsightRow(
        title: 'Late After',
        showChevron: false,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _label(value),
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

class _CenteredAction extends StatelessWidget {
  const _CenteredAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      onPressed: onTap,
      child: Text(label, style: InsightText.body.copyWith(color: color)),
    );
  }
}
