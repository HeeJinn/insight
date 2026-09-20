import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../core/widgets/core_widgets.dart';
import '../models/student.dart';
import 'app_chrome.dart';
import 'biometric_indicators.dart';

class StudentList extends StatefulWidget {
  final Box<Student> studentsBox;

  const StudentList({super.key, required this.studentsBox});

  @override
  State<StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<StudentList> {
  String query = '';
  _CompletionFilter completionFilter = _CompletionFilter.all;
  _SortMode sortMode = _SortMode.nameAsc;

  @override
  Widget build(BuildContext context) {
    final students = widget.studentsBox.values.where((s) {
      final q = query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q);
      final isComplete = s.embeddings.length >= 5;
      final matchesCompletion = switch (completionFilter) {
        _CompletionFilter.all => true,
        _CompletionFilter.completeOnly => isComplete,
        _CompletionFilter.incompleteOnly => !isComplete,
      };
      return matchesQuery && matchesCompletion;
    }).toList()
      ..sort((a, b) {
        return switch (sortMode) {
          _SortMode.nameAsc => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
          _SortMode.nameDesc => b.name.toLowerCase().compareTo(
            a.name.toLowerCase(),
          ),
          _SortMode.idAsc => a.id.toLowerCase().compareTo(b.id.toLowerCase()),
          _SortMode.idDesc => b.id.toLowerCase().compareTo(a.id.toLowerCase()),
        };
      });

    final hasActiveFilter =
        completionFilter != _CompletionFilter.all ||
        sortMode != _SortMode.nameAsc;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final toolbarButtons = [
                _ToolbarButton(
                  icon: Icons.tune_rounded,
                  label: 'Filters',
                  showDot: hasActiveFilter,
                  onTap: () => _openFilterSheet(context),
                ),
                _ToolbarButton(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Open register',
                  onTap: () => context.go('/admin'),
                ),
              ];
              final countTag = AppPillTag(
                icon: Icons.groups_2_rounded,
                label: '${students.length} total',
              );

              if (constraints.maxWidth >= 560) {
                // Wide layout: search field stays a sensible width instead
                // of stretching edge-to-edge, with actions on the same row.
                return Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AppSearchField(
                        hintText: 'Search student name or ID',
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...toolbarButtons.expand(
                      (button) => [button, const SizedBox(width: 8)],
                    ),
                    const Spacer(),
                    countTag,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSearchField(
                    hintText: 'Search student name or ID',
                    onChanged: (value) => setState(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [...toolbarButtons, countTag],
                  ),
                ],
              );
            },
          ),
        ),
        if (hasActiveFilter) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ..._activeFilterLabels().map(
                  (label) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(label),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      completionFilter = _CompletionFilter.all;
                      sortMode = _SortMode.nameAsc;
                    });
                  },
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (students.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              title: 'No students registered yet',
              subtitle:
                  'Add a student from the Register tab to create the first biometric profile.',
            ),
          )
        else
          SliverToBoxAdapter(
            child: AppleInsetGroupedSection(
              children: students.map(
                (student) => _StudentTile(
                  student: student,
                  onEdit: () => _editStudent(context, student),
                  onDelete: () => _deleteStudent(context, student),
                ),
              ).toList(),
            ),
          ),
      ],
    );
  }

  String _filterSummaryLabel() {
    final completionLabel = switch (completionFilter) {
      _CompletionFilter.all => 'All profiles',
      _CompletionFilter.completeOnly => 'Complete profiles',
      _CompletionFilter.incompleteOnly => 'Incomplete profiles',
    };
    final sortLabel = switch (sortMode) {
      _SortMode.nameAsc => 'Name A-Z',
      _SortMode.nameDesc => 'Name Z-A',
      _SortMode.idAsc => 'ID A-Z',
      _SortMode.idDesc => 'ID Z-A',
    };
    return '$completionLabel • Sorted by $sortLabel';
  }

  List<String> _activeFilterLabels() {
    final labels = <String>[];
    if (completionFilter != _CompletionFilter.all) {
      labels.add(
        switch (completionFilter) {
          _CompletionFilter.completeOnly => 'Complete only',
          _CompletionFilter.incompleteOnly => 'Incomplete only',
          _CompletionFilter.all => 'All profiles',
        },
      );
    }
    if (sortMode != _SortMode.nameAsc) {
      labels.add(
        switch (sortMode) {
          _SortMode.nameAsc => 'Name A-Z',
          _SortMode.nameDesc => 'Name Z-A',
          _SortMode.idAsc => 'ID A-Z',
          _SortMode.idDesc => 'ID Z-A',
        },
      );
    }
    if (labels.isEmpty) {
      labels.add(_filterSummaryLabel());
    }
    return labels;
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    var draftCompletion = completionFilter;
    var draftSort = sortMode;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter students', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Text('Completion', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<_CompletionFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _CompletionFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: _CompletionFilter.completeOnly,
                      label: Text('Complete'),
                    ),
                    ButtonSegment(
                      value: _CompletionFilter.incompleteOnly,
                      label: Text('Incomplete'),
                    ),
                  ],
                  selected: {draftCompletion},
                  onSelectionChanged: (value) {
                    setSheetState(() => draftCompletion = value.first);
                  },
                ),
                const SizedBox(height: 14),
                Text('Sort by', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<_SortMode>(
                  initialValue: draftSort,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _SortMode.nameAsc,
                      child: Text('Name A-Z'),
                    ),
                    DropdownMenuItem(
                      value: _SortMode.nameDesc,
                      child: Text('Name Z-A'),
                    ),
                    DropdownMenuItem(
                      value: _SortMode.idAsc,
                      child: Text('ID A-Z'),
                    ),
                    DropdownMenuItem(
                      value: _SortMode.idDesc,
                      child: Text('ID Z-A'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => draftSort = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          completionFilter = _CompletionFilter.all;
                          sortMode = _SortMode.nameAsc;
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Reset'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          completionFilter = draftCompletion;
                          sortMode = draftSort;
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
    );
  }

  Future<bool> _confirmDeleteStudent(
    BuildContext context,
    Student student,
  ) {
    return AppDialog.confirm(
      context,
      title: 'Delete Student?',
      message: 'Remove ${student.name} from the local database? This can\'t be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
  }

  Future<void> _deleteStudent(BuildContext context, Student student) async {
    final shouldDelete = await _confirmDeleteStudent(context, student);
    if (!shouldDelete) {
      return;
    }
    await widget.studentsBox.delete(student.id);
    if (mounted) {
      setState(() {});
    }
  }

  void _editStudent(BuildContext context, Student student) {
    final nameController = TextEditingController(text: student.name);
    AppDialog.show<void>(
      context,
      title: 'Edit Student',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: student.id,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Student ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Student name'),
          ),
        ],
      ),
      actions: (dialogContext) => [
        Expanded(
          child: AppleTactileButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            backgroundColor: dialogContext.appColors.surface,
            foregroundColor: dialogContext.appColors.primaryText,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppleTactileButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              if (updatedName.isEmpty) return;
              student.name = updatedName;
              await student.save();
              if (mounted) setState(() {});
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ),
      ],
    ).whenComplete(nameController.dispose);
  }
}

class _StudentTile extends StatelessWidget {
  final Student student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentTile({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          _AvatarLetter(name: student.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppleTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.appColors.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'ID ${student.id}',
                      style: AppleTypography.footnote.copyWith(
                        fontFeatures: AppleTypography.tabular,
                        color: context.appColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BiometricQualityPips(
                      sampleCount: student.embeddings.length,
                      targetCount: 5,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: context.appColors.secondaryText,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.appColors.border,
                width: 0.5,
              ),
            ),
            color: isDark
                ? context.appColors.surface
                : context.appColors.elevatedSurface,
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16),
                    SizedBox(width: 8),
                    Text('Edit Name'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: context.appColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String name;

  const _AvatarLetter({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.accent.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 0.9,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: TextStyle(
          color: colors.accent,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.appColors.border, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 16, color: context.appColors.primaryText),
                  if (showDot)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.appColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppleTypography.footnote.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.appColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.person_search_outlined,
      title: title,
      subtitle: subtitle,
    );
  }
}

enum _CompletionFilter { all, completeOnly, incompleteOnly }

enum _SortMode { nameAsc, nameDesc, idAsc, idDesc }
