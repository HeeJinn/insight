import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/attendance.dart';
import '../models/student.dart';
import '../providers/hive_provider.dart';
import '../services/student_stats.dart';
import '../ui/insight_ui.dart';
import 'enroll_student_screen.dart';
import 'student_detail.dart';

enum _SortBy { name, id, lastSeen }

/// The roster. Wide windows show the list beside the selected student's
/// detail, like a Mac list–detail app; phones push the detail.
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _query = '';
  _SortBy _sortBy = _SortBy.name;
  bool _needsAttentionOnly = false;
  Object? _selectedKey;

  /// Pane width at which the detail moves beside the list.
  static const double _splitWidth = 860;
  static const double _listWidth = 380;

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsBoxProvider).value;
    final attendance = ref.watch(attendanceBoxProvider).value;
    if (students == null || attendance == null) {
      return const InsightRootPage(title: 'Students', slivers: []);
    }

    return StreamBuilder(
      stream: students.watch(),
      builder: (context, _) => StreamBuilder(
        stream: attendance.watch(),
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final split = c.maxWidth >= _splitWidth;
            final all = students.values.toList();
            final selected = split
                ? all.where((s) => s.key == _selectedKey).firstOrNull ??
                      _firstVisible(all, attendance.values)
                : null;

            final list = _RosterList(
              students: all,
              attendance: attendance.values,
              query: _query,
              sortBy: _sortBy,
              needsAttentionOnly: _needsAttentionOnly,
              selectedKey: selected?.key,
              split: split,
              onQuery: (q) => setState(() => _query = q),
              onSort: (s) => setState(() => _sortBy = s),
              onToggleNeedsAttention: () =>
                  setState(() => _needsAttentionOnly = !_needsAttentionOnly),
              onOpen: (student) {
                if (split) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedKey = student.key);
                } else {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => StudentDetailScreen(student: student),
                    ),
                  );
                }
              },
            );

            if (!split) return list;
            return Row(
              children: [
                SizedBox(width: _listWidth, child: list),
                Container(
                  width: 0.5,
                  color: InsightColors.separator.resolveFrom(context),
                ),
                Expanded(
                  child: selected == null
                      ? const CupertinoPageScaffold(
                          child: EmptyState(
                            icon: CupertinoIcons.person_crop_circle,
                            title: 'No Student Selected',
                            message: 'Choose a student to see their details.',
                          ),
                        )
                      : CupertinoPageScaffold(
                          child: StudentDetailView(
                            key: ValueKey(selected.key),
                            student: selected,
                            topPadding: MediaQuery.paddingOf(context).top + 24,
                            onDeleted: () =>
                                setState(() => _selectedKey = null),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Student? _firstVisible(List<Student> all, Iterable<Attendance> attendance) {
    final visible = _filterAndSort(
      all,
      attendance,
      _query,
      _sortBy,
      _needsAttentionOnly,
    );
    return visible.firstOrNull;
  }
}

List<Student> _filterAndSort(
  List<Student> all,
  Iterable<Attendance> attendance,
  String query,
  _SortBy sortBy,
  bool needsAttentionOnly,
) {
  final q = query.trim().toLowerCase();
  final lastSeen = <String, DateTime>{};
  if (sortBy == _SortBy.lastSeen) {
    for (final a in attendance) {
      final prev = lastSeen[a.studentId];
      if (prev == null || a.timestamp.isAfter(prev)) {
        lastSeen[a.studentId] = a.timestamp;
      }
    }
  }
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  return all.where((s) {
    final matches =
        q.isEmpty ||
        s.name.toLowerCase().contains(q) ||
        s.id.toLowerCase().contains(q);
    final attention =
        !needsAttentionOnly || faceProfileStatus(s) != FaceProfileStatus.ready;
    return matches && attention;
  }).toList()..sort(
    (a, b) => switch (sortBy) {
      _SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _SortBy.id => a.id.toLowerCase().compareTo(b.id.toLowerCase()),
      _SortBy.lastSeen => (lastSeen[b.id] ?? epoch).compareTo(
        lastSeen[a.id] ?? epoch,
      ),
    },
  );
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.students,
    required this.attendance,
    required this.query,
    required this.sortBy,
    required this.needsAttentionOnly,
    required this.selectedKey,
    required this.split,
    required this.onQuery,
    required this.onSort,
    required this.onToggleNeedsAttention,
    required this.onOpen,
  });

  final List<Student> students;
  final Iterable<Attendance> attendance;
  final String query;
  final _SortBy sortBy;
  final bool needsAttentionOnly;
  final Object? selectedKey;

  /// Whether the detail shows beside the list; rows select rather than
  /// drill in, so they drop the chevron.
  final bool split;
  final ValueChanged<String> onQuery;
  final ValueChanged<_SortBy> onSort;
  final VoidCallback onToggleNeedsAttention;
  final ValueChanged<Student> onOpen;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = _filterAndSort(
      students,
      attendance,
      query,
      sortBy,
      needsAttentionOnly,
    );
    final lastSeen = <String, DateTime>{};
    for (final a in attendance) {
      final prev = lastSeen[a.studentId];
      if (prev == null || a.timestamp.isAfter(prev)) {
        lastSeen[a.studentId] = a.timestamp;
      }
    }
    final attentionCount = students
        .where((s) => faceProfileStatus(s) != FaceProfileStatus.ready)
        .length;

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SortMenu(
          sortBy: sortBy,
          needsAttentionOnly: needsAttentionOnly,
          onSort: onSort,
          onToggleNeedsAttention: onToggleNeedsAttention,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: CupertinoIcons.add,
          semanticLabel: 'Enroll Student',
          size: 36,
          onPressed: () => showEnrollStudent(context),
        ),
      ],
    );

    final List<Widget> slivers;
    if (students.isEmpty) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: CupertinoIcons.person_2,
            title: 'No Students Yet',
            message:
                'Enroll students with five quick face photos so the kiosk '
                'can recognize them.',
            action: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(InsightRadii.capsule),
              onPressed: () => showEnrollStudent(context),
              child: const Text('Enroll Student'),
            ),
          ),
        ),
      ];
    } else if (visible.isEmpty) {
      slivers = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: CupertinoIcons.search,
            title: 'No Results',
            message: query.trim().isEmpty
                ? 'Every face profile is up to date.'
                : 'No student matches “${query.trim()}”.',
          ),
        ),
      ];
    } else {
      slivers = [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              [
                '${students.length} enrolled',
                if (attentionCount > 0)
                  '$attentionCount need${attentionCount == 1 ? 's' : ''} re-enrollment',
              ].join(' · '),
              style: InsightText.footnote.copyWith(
                color: InsightColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: InsightListSection(
            dividerInset: 67,
            children: [
              for (final s in visible)
                InsightRow(
                  leading: InitialsAvatar(name: s.name, size: 36),
                  title: s.name,
                  subtitle: '${s.id} · ${formatLastSeen(lastSeen[s.id], now)}',
                  selected: s.key == selectedKey,
                  showChevron: !split,
                  trailing: faceProfileStatus(s) == FaceProfileStatus.ready
                      ? null
                      : Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          size: 18,
                          color: InsightColors.warning.resolveFrom(context),
                          semanticLabel: 'Needs re-enrollment',
                        ),
                  onTap: () => onOpen(s),
                ),
            ],
          ),
        ),
      ];
    }

    return InsightRootPage(
      title: 'Students',
      trailing: trailing,
      searchField: CupertinoSearchTextField(
        placeholder: 'Name or ID',
        onChanged: onQuery,
      ),
      slivers: slivers,
    );
  }
}

/// The "…" pull-down: sort order and the needs-attention filter.
class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.sortBy,
    required this.needsAttentionOnly,
    required this.onSort,
    required this.onToggleNeedsAttention,
  });

  final _SortBy sortBy;
  final bool needsAttentionOnly;
  final ValueChanged<_SortBy> onSort;
  final VoidCallback onToggleNeedsAttention;

  @override
  Widget build(BuildContext context) {
    Widget? check(bool on) => on
        ? Icon(
            CupertinoIcons.checkmark,
            size: 17,
            color: InsightColors.accent.resolveFrom(context),
          )
        : null;

    return CupertinoMenuAnchor(
      menuChildren: [
        CupertinoMenuItem(
          trailing: check(sortBy == _SortBy.name),
          onPressed: () => onSort(_SortBy.name),
          child: const Text('Sort by Name'),
        ),
        CupertinoMenuItem(
          trailing: check(sortBy == _SortBy.id),
          onPressed: () => onSort(_SortBy.id),
          child: const Text('Sort by Student ID'),
        ),
        CupertinoMenuItem(
          trailing: check(sortBy == _SortBy.lastSeen),
          onPressed: () => onSort(_SortBy.lastSeen),
          child: const Text('Sort by Last Seen'),
        ),
        const CupertinoMenuDivider(),
        CupertinoMenuItem(
          leading: const Icon(CupertinoIcons.exclamationmark_triangle),
          trailing: check(needsAttentionOnly),
          onPressed: onToggleNeedsAttention,
          child: const Text('Needs Re-enrollment'),
        ),
      ],
      builder: (context, controller, _) => GlassIconButton(
        icon: CupertinoIcons.ellipsis,
        semanticLabel: 'Sort and Filter',
        size: 36,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
