import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';

class InsightLogsScreen extends ConsumerStatefulWidget {
  const InsightLogsScreen({super.key});

  @override
  ConsumerState<InsightLogsScreen> createState() => _InsightLogsScreenState();
}

class _InsightLogsScreenState extends ConsumerState<InsightLogsScreen> {
  static const _presetsKey = 'insight_logs_saved_presets_v1';
  String _query = '';
  int _rangeDays = 7;
  DateTimeRange? _customRange;
  String? _selectedSession;
  String? _selectedRoom;
  bool _onlyUnknownStudents = false;
  bool _withSessionTag = false;
  bool _byRoomOccupancy = false;
  List<_SavedPreset> _savedPresets = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedPresets();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/insights'),
        ),
        title: const Text('All check-ins'),
      ),
      body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (studentsBox) => attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (attendanceBox) => StreamBuilder(
              stream: attendanceBox.watch(),
              builder: (context, _) {
                final idToName = <String, String>{
                  for (final Student s in studentsBox.values) s.id: s.name,
                };
                final q = _query.trim().toLowerCase();
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final range = _effectiveRange(today);
                final rangeStart = range.start;
                final rangeEndExclusive = DateTime(
                  range.end.year,
                  range.end.month,
                  range.end.day + 1,
                );

                final allLogs = attendanceBox.values.toList();
                final availableSessions = allLogs
                    .map((a) => (a.sessionTitle ?? '').trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final availableRooms = allLogs
                    .map((a) => (a.room ?? '').trim())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final roomUsage = <String, int>{};
                for (final a in allLogs) {
                  final room = (a.room ?? '').trim();
                  if (room.isEmpty) continue;
                  roomUsage[room] = (roomUsage[room] ?? 0) + 1;
                }
                String? busiestRoom;
                int busiestCount = 0;
                roomUsage.forEach((room, count) {
                  if (count > busiestCount) {
                    busiestCount = count;
                    busiestRoom = room;
                  }
                });
                final effectiveRoom = _byRoomOccupancy
                    ? (_selectedRoom ?? busiestRoom)
                    : _selectedRoom;

                final filtered = allLogs.where((Attendance a) {
                  if (a.timestamp.isBefore(rangeStart) ||
                      !a.timestamp.isBefore(rangeEndExclusive)) {
                    return false;
                  }
                  if (_selectedSession != null &&
                      (a.sessionTitle ?? '').trim() != _selectedSession) {
                    return false;
                  }
                  if (effectiveRoom != null &&
                      (a.room ?? '').trim() != effectiveRoom) {
                    return false;
                  }
                  final hasKnownStudent = idToName.containsKey(a.studentId);
                  if (_onlyUnknownStudents && hasKnownStudent) {
                    return false;
                  }
                  final hasSessionTag = (a.sessionTitle ?? '').trim().isNotEmpty;
                  if (_withSessionTag && !hasSessionTag) {
                    return false;
                  }
                  if (q.isEmpty) {
                    return true;
                  }
                  final id = a.studentId.toLowerCase();
                  final name = (idToName[a.studentId] ?? '').toLowerCase();
                  return id.contains(q) || name.contains(q);
                }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wideActions = constraints.maxWidth >= 480;
                          return Container(
                            padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SearchBar(
                              hintText: 'Search by student name or ID',
                              leading: const Icon(Icons.search, size: 20),
                              onChanged: (v) => setState(() => _query = v),
                              backgroundColor: WidgetStatePropertyAll(
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              elevation: const WidgetStatePropertyAll(0),
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: AppTheme.border),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              constraints: const BoxConstraints(minHeight: 46),
                            ),
                            const SizedBox(height: 6),
                            if (wideActions)
                              Row(
                                children: [
                                  Expanded(
                                    child: _CompactActionButton(
                                      icon: Icons.filter_alt_outlined,
                                      label: _hasActiveFilters
                                          ? 'Filters (${_activeFilterCount})'
                                          : 'Filters',
                                      onPressed: () => _openFilterSheet(
                                        context: context,
                                        availableSessions: availableSessions,
                                        availableRooms: availableRooms,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _CompactActionButton(
                                      icon: Icons.download_outlined,
                                      label: 'Export',
                                      onPressed: filtered.isEmpty
                                          ? null
                                          : () => _exportFilteredCsv(
                                              context: context,
                                              logs: filtered,
                                              idToName: idToName,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _PresetMenuButton(
                                      defaultPresets: _defaultPresets,
                                      savedPresets: _savedPresets,
                                      onSelected: (value) async {
                                        if (value == '__save__') {
                                          await _saveCurrentPreset(context);
                                          return;
                                        }
                                        if (value == '__manage__') {
                                          await _openManagePresetsSheet(context);
                                          return;
                                        }
                                        _applyPreset(value);
                                      },
                                    ),
                                  ),
                                ],
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _CompactActionButton(
                                    icon: Icons.filter_alt_outlined,
                                    label: _hasActiveFilters
                                        ? 'Filters (${_activeFilterCount})'
                                        : 'Filters',
                                    onPressed: () => _openFilterSheet(
                                      context: context,
                                      availableSessions: availableSessions,
                                      availableRooms: availableRooms,
                                    ),
                                  ),
                                  _CompactActionButton(
                                    icon: Icons.download_outlined,
                                    label: 'Export',
                                    onPressed: filtered.isEmpty
                                        ? null
                                        : () => _exportFilteredCsv(
                                            context: context,
                                            logs: filtered,
                                            idToName: idToName,
                                          ),
                                  ),
                                  _PresetMenuButton(
                                    defaultPresets: _defaultPresets,
                                    savedPresets: _savedPresets,
                                    onSelected: (value) async {
                                      if (value == '__save__') {
                                        await _saveCurrentPreset(context);
                                        return;
                                      }
                                      if (value == '__manage__') {
                                        await _openManagePresetsSheet(context);
                                        return;
                                      }
                                      _applyPreset(value);
                                    },
                                  ),
                                ],
                              ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ..._buildActiveFilterPills(
                                    effectiveRoom: effectiveRoom,
                                  ).map(
                                    (pill) => InputChip(
                                      label: Text(pill.label),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onDeleted: pill.onRemove,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _resetAllFilters,
                                    child: const Text('Reset all'),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${filtered.length} check-ins • ${_rangeLabel(range)}${effectiveRoom != null ? ' • room $effectiveRoom' : ''}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                          ],
                        ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No check-ins match this filter set.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : CustomScrollView(
                              slivers: [
                                ..._buildStickyDaySlivers(
                                  context: context,
                                  logs: filtered,
                                  idToName: idToName,
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  DateTimeRange _effectiveRange(DateTime today) {
    if (_customRange != null) {
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
      );
      return DateTimeRange(start: start, end: end);
    }
    final start = today.subtract(Duration(days: _rangeDays - 1));
    return DateTimeRange(start: start, end: today);
  }

  String _rangeLabel(DateTimeRange range) {
    return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
  }

  String _shortDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  String _timeLabel(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _humanDayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) {
      return 'Today';
    }
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDateRange(DateTimeRange range) {
    return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
  }

  bool get _hasActiveFilters =>
      _rangeDays != 7 ||
      _customRange != null ||
      _selectedSession != null ||
      _selectedRoom != null ||
      _onlyUnknownStudents ||
      _withSessionTag ||
      _byRoomOccupancy;

  int get _activeFilterCount {
    var count = 0;
    if (_rangeDays != 7 || _customRange != null) count++;
    if (_selectedSession != null) count++;
    if (_selectedRoom != null) count++;
    if (_onlyUnknownStudents) count++;
    if (_withSessionTag) count++;
    if (_byRoomOccupancy) count++;
    return count;
  }

  List<_ActiveFilterPill> _buildActiveFilterPills({required String? effectiveRoom}) {
    final pills = <_ActiveFilterPill>[];
    if (_customRange != null) {
      pills.add(
        _ActiveFilterPill(
          label: 'Range ${_formatDateRange(_customRange!)}',
          onRemove: () => setState(() => _customRange = null),
        ),
      );
    } else if (_rangeDays != 7) {
      pills.add(
        _ActiveFilterPill(
          label: _rangeDays == 1 ? 'Today' : 'Last $_rangeDays days',
          onRemove: () => setState(() => _rangeDays = 7),
        ),
      );
    }
    if (_selectedSession != null) {
      pills.add(
        _ActiveFilterPill(
          label: 'Session ${_selectedSession!}',
          onRemove: () => setState(() => _selectedSession = null),
        ),
      );
    }
    if (effectiveRoom != null) {
      pills.add(
        _ActiveFilterPill(
          label: 'Room $effectiveRoom',
          onRemove: () => setState(() {
            _selectedRoom = null;
            _byRoomOccupancy = false;
          }),
        ),
      );
    }
    if (_onlyUnknownStudents) {
      pills.add(
        _ActiveFilterPill(
          label: 'Unknown only',
          onRemove: () => setState(() => _onlyUnknownStudents = false),
        ),
      );
    }
    if (_withSessionTag) {
      pills.add(
        _ActiveFilterPill(
          label: 'With session tag',
          onRemove: () => setState(() => _withSessionTag = false),
        ),
      );
    }
    if (_byRoomOccupancy) {
      pills.add(
        _ActiveFilterPill(
          label: 'By occupancy',
          onRemove: () => setState(() => _byRoomOccupancy = false),
        ),
      );
    }
    return pills;
  }

  void _resetAllFilters() {
    setState(() {
      _rangeDays = 7;
      _customRange = null;
      _selectedSession = null;
      _selectedRoom = null;
      _onlyUnknownStudents = false;
      _withSessionTag = false;
      _byRoomOccupancy = false;
    });
  }

  Future<void> _openFilterSheet({
    required BuildContext context,
    required List<String> availableSessions,
    required List<String> availableRooms,
  }) async {
    var draftRangeDays = _rangeDays;
    DateTimeRange? draftCustomRange = _customRange;
    var draftSelectedSession = _selectedSession;
    var draftSelectedRoom = _selectedRoom;
    var draftOnlyUnknown = _onlyUnknownStudents;
    var draftWithSessionTag = _withSessionTag;
    var draftByRoomOccupancy = _byRoomOccupancy;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter check-ins', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Today')),
                      ButtonSegment(value: 7, label: Text('7d')),
                      ButtonSegment(value: 30, label: Text('30d')),
                    ],
                    selected: {draftRangeDays},
                    onSelectionChanged: (set) {
                      setSheetState(() {
                        draftRangeDays = set.first;
                        draftCustomRange = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickCustomRangeForSheet(
                        context,
                        draftCustomRange,
                      );
                      if (picked != null) {
                        setSheetState(() => draftCustomRange = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      draftCustomRange == null
                          ? 'Custom range'
                          : _formatDateRange(draftCustomRange!),
                    ),
                  ),
                  if (draftCustomRange != null)
                    TextButton(
                      onPressed: () => setSheetState(() => draftCustomRange = null),
                      child: const Text('Clear custom'),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: draftSelectedSession,
                    decoration: const InputDecoration(
                      labelText: 'Session',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All sessions'),
                      ),
                      ...availableSessions.map(
                        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => draftSelectedSession = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: draftSelectedRoom,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All rooms'),
                      ),
                      ...availableRooms.map(
                        (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                      ),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => draftSelectedRoom = value),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Only unknown students'),
                        selected: draftOnlyUnknown,
                        onSelected: (v) =>
                            setSheetState(() => draftOnlyUnknown = v),
                      ),
                      FilterChip(
                        label: const Text('With session tag'),
                        selected: draftWithSessionTag,
                        onSelected: (v) =>
                            setSheetState(() => draftWithSessionTag = v),
                      ),
                      FilterChip(
                        label: const Text('By room occupancy'),
                        selected: draftByRoomOccupancy,
                        onSelected: (v) =>
                            setSheetState(() => draftByRoomOccupancy = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            draftRangeDays = 7;
                            draftCustomRange = null;
                            draftSelectedSession = null;
                            draftSelectedRoom = null;
                            draftOnlyUnknown = false;
                            draftWithSessionTag = false;
                            draftByRoomOccupancy = false;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _rangeDays = draftRangeDays;
                            _customRange = draftCustomRange;
                            _selectedSession = draftSelectedSession;
                            _selectedRoom = draftSelectedRoom;
                            _onlyUnknownStudents = draftOnlyUnknown;
                            _withSessionTag = draftWithSessionTag;
                            _byRoomOccupancy = draftByRoomOccupancy;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTimeRange?> _pickCustomRangeForSheet(
    BuildContext context,
    DateTimeRange? initialRange,
  ) async {
    final now = DateTime.now();
    final initial = initialRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: DateTime(now.year, now.month, now.day),
        );
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
    );
  }

  Future<void> _exportFilteredCsv({
    required BuildContext context,
    required List<Attendance> logs,
    required Map<String, String> idToName,
  }) async {
    try {
      final headers = [
        'timestamp',
        'student_id',
        'student_name',
        'session_title',
        'room',
      ];
      final rows = logs.map((log) {
        final values = [
          log.timestamp.toIso8601String(),
          log.studentId,
          idToName[log.studentId] ?? 'Unknown student',
          (log.sessionTitle ?? '').trim(),
          (log.room ?? '').trim(),
        ];
        return values.map(_csvCell).join(',');
      }).toList();
      final csv = [headers.join(','), ...rows].join('\n');
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}${Platform.pathSeparator}checkins_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Filtered check-ins export',
          subject: 'Check-ins CSV export',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV exported and shared: ${file.path}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Exported locally. Sharing is not available on this platform.',
          ),
        ),
      );
    }
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _loadSavedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_presetsKey) ?? const [];
    setState(() {
      _savedPresets = raw
          .map((item) => _SavedPreset.fromJson(jsonDecode(item)))
          .toList();
    });
  }

  Future<void> _persistPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _savedPresets.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_presetsKey, encoded);
  }

  Future<void> _saveCurrentPreset(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Preset name',
            hintText: 'e.g. Morning audit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final preset = _SavedPreset(
      name: name,
      rangeDays: _rangeDays,
      customStartMs: _customRange?.start.millisecondsSinceEpoch,
      customEndMs: _customRange?.end.millisecondsSinceEpoch,
      selectedSession: _selectedSession,
      selectedRoom: _selectedRoom,
      onlyUnknownStudents: _onlyUnknownStudents,
      withSessionTag: _withSessionTag,
      byRoomOccupancy: _byRoomOccupancy,
    );
    setState(() {
      _savedPresets = [
        ..._savedPresets.where((p) => p.name != preset.name),
        preset,
      ];
    });
    await _persistPresets();
  }

  Future<void> _deletePreset(String name) async {
    setState(() {
      _savedPresets = _savedPresets.where((p) => p.name != name).toList();
    });
    await _persistPresets();
  }

  Future<void> _openManagePresetsSheet(BuildContext context) async {
    if (_savedPresets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved presets yet.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage presets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._savedPresets.map(
                (preset) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(preset.name),
                  leading: const Icon(Icons.bookmark_outline),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Rename',
                        onPressed: () => _renamePreset(context, preset.name),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _deletePreset(preset.name),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () {
                    _applyPreset(preset.name);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renamePreset(BuildContext context, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Preset name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    setState(() {
      _savedPresets = _savedPresets.map((p) {
        if (p.name != oldName) return p;
        return p.copyWith(name: newName);
      }).toList();
    });
    await _persistPresets();
  }

  void _applyPreset(String name) {
    _SavedPreset? preset;
    for (final item in [..._defaultPresets, ..._savedPresets]) {
      if (item.name == name) {
        preset = item;
        break;
      }
    }
    if (preset == null) return;
    final selected = preset;
    setState(() {
      _rangeDays = selected.rangeDays;
      _customRange = selected.toDateRange();
      _selectedSession = selected.selectedSession;
      _selectedRoom = selected.selectedRoom;
      _onlyUnknownStudents = selected.onlyUnknownStudents;
      _withSessionTag = selected.withSessionTag;
      _byRoomOccupancy = selected.byRoomOccupancy;
    });
  }

  List<_SavedPreset> get _defaultPresets => [
    const _SavedPreset(
      name: 'Morning audit',
      rangeDays: 1,
      withSessionTag: true,
    ),
    const _SavedPreset(
      name: 'Last 30 days by room',
      rangeDays: 30,
      byRoomOccupancy: true,
    ),
  ];

  List<Widget> _buildStickyDaySlivers({
    required BuildContext context,
    required List<Attendance> logs,
    required Map<String, String> idToName,
  }) {
    final groups = <DateTime, List<Attendance>>{};
    for (final item in logs) {
      final day = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      groups.putIfAbsent(day, () => []).add(item);
    }
    final orderedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final slivers = <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: 6)),
    ];
    for (final day in orderedDays) {
      final items = groups[day]!;
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DayHeaderDelegate(label: _humanDayLabel(day)),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final name = idToName[item.studentId] ?? 'Unknown student';
              return Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 8 : 0,
                  bottom: 10,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fingerprint, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'ID ${item.studentId}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                            if ((item.sessionTitle ?? '').isNotEmpty ||
                                (item.room ?? '').isNotEmpty)
                              Text(
                                '${item.sessionTitle ?? 'Session'}${(item.room ?? '').isNotEmpty ? ' • ${item.room!}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeLabel(item.timestamp),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    return slivers;
  }
}

class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;

  const _DayHeaderDelegate({required this.label});

  @override
  double get minExtent => 26;

  @override
  double get maxExtent => 26;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeaderDelegate oldDelegate) {
    return label != oldDelegate.label;
  }
}

class _SavedPreset {
  final String name;
  final int rangeDays;
  final int? customStartMs;
  final int? customEndMs;
  final String? selectedSession;
  final String? selectedRoom;
  final bool onlyUnknownStudents;
  final bool withSessionTag;
  final bool byRoomOccupancy;

  const _SavedPreset({
    required this.name,
    required this.rangeDays,
    this.customStartMs,
    this.customEndMs,
    this.selectedSession,
    this.selectedRoom,
    this.onlyUnknownStudents = false,
    this.withSessionTag = false,
    this.byRoomOccupancy = false,
  });

  _SavedPreset copyWith({String? name}) => _SavedPreset(
    name: name ?? this.name,
    rangeDays: rangeDays,
    customStartMs: customStartMs,
    customEndMs: customEndMs,
    selectedSession: selectedSession,
    selectedRoom: selectedRoom,
    onlyUnknownStudents: onlyUnknownStudents,
    withSessionTag: withSessionTag,
    byRoomOccupancy: byRoomOccupancy,
  );

  DateTimeRange? toDateRange() {
    if (customStartMs == null || customEndMs == null) return null;
    return DateTimeRange(
      start: DateTime.fromMillisecondsSinceEpoch(customStartMs!),
      end: DateTime.fromMillisecondsSinceEpoch(customEndMs!),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'rangeDays': rangeDays,
    'customStartMs': customStartMs,
    'customEndMs': customEndMs,
    'selectedSession': selectedSession,
    'selectedRoom': selectedRoom,
    'onlyUnknownStudents': onlyUnknownStudents,
    'withSessionTag': withSessionTag,
    'byRoomOccupancy': byRoomOccupancy,
  };

  factory _SavedPreset.fromJson(Map<String, dynamic> json) => _SavedPreset(
    name: json['name'] as String,
    rangeDays: json['rangeDays'] as int? ?? 7,
    customStartMs: json['customStartMs'] as int?,
    customEndMs: json['customEndMs'] as int?,
    selectedSession: json['selectedSession'] as String?,
    selectedRoom: json['selectedRoom'] as String?,
    onlyUnknownStudents: json['onlyUnknownStudents'] as bool? ?? false,
    withSessionTag: json['withSessionTag'] as bool? ?? false,
    byRoomOccupancy: json['byRoomOccupancy'] as bool? ?? false,
  );
}

class _ActiveFilterPill {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterPill({required this.label, required this.onRemove});
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _PresetMenuButton extends StatelessWidget {
  final List<_SavedPreset> defaultPresets;
  final List<_SavedPreset> savedPresets;
  final Future<void> Function(String value) onSelected;

  const _PresetMenuButton({
    required this.defaultPresets,
    required this.savedPresets,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Saved presets',
      onSelected: (value) async => onSelected(value),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[
          const PopupMenuItem(
            value: '__save__',
            child: Text('Save current preset'),
          ),
          const PopupMenuItem(
            value: '__manage__',
            child: Text('Manage saved presets'),
          ),
          const PopupMenuDivider(),
          ...defaultPresets.map(
            (preset) => PopupMenuItem(
              value: preset.name,
              child: Text('Apply: ${preset.name}'),
            ),
          ),
        ];
        if (savedPresets.isNotEmpty) {
          items
            ..add(const PopupMenuDivider())
            ..addAll(
              savedPresets.map(
                (preset) => PopupMenuItem(
                  value: preset.name,
                  child: Text('Saved: ${preset.name}'),
                ),
              ),
            );
        }
        return items;
      },
      child: OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.bookmark_outline, size: 18),
        label: const Text('Presets'),
      ),
    );
  }
}
