import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import '../app_theme.dart';
import '../models/student.dart';
import 'app_chrome.dart';

class StudentList extends StatefulWidget {
  final Box<Student> studentsBox;

  const StudentList({super.key, required this.studentsBox});

  @override
  State<StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<StudentList> {
  String query = '';
  bool onlyComplete = false;

  @override
  Widget build(BuildContext context) {
    final students = widget.studentsBox.values
        .where((s) {
          final q = query.trim().toLowerCase();
          final matchesQuery = q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              s.id.toLowerCase().contains(q);
          final complete = !onlyComplete || s.embeddings.length >= 5;
          return matchesQuery && complete;
        })
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchBar(
          hintText: 'Search student name or ID',
          leading: const Icon(Icons.search),
          onChanged: (value) => setState(() => query = value),
          backgroundColor: WidgetStatePropertyAll(
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          elevation: const WidgetStatePropertyAll(0),
          side: const WidgetStatePropertyAll(BorderSide(color: AppTheme.border)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilterChip(
              label: const Text('Complete profiles only'),
              selected: onlyComplete,
              onSelected: (v) => setState(() => onlyComplete = v),
            ),
            const Spacer(),
            AppPillTag(
              label: '${students.length} total',
              backgroundColor: AppTheme.orangeSoft,
              foregroundColor: AppTheme.orange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: students.isEmpty
              ? const _EmptyState(
                  title: 'No students registered yet',
                  subtitle:
                      'Add a student from the Register tab to create the first biometric profile.',
                )
              : ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _StudentTile(
                      student: student,
                      onEdit: () => _editStudent(context, student),
                      onDelete: () => _deleteStudent(context, student),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _deleteStudent(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Remove ${student.name} from the local database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.studentsBox.delete(student.id);
              if (mounted) setState(() {});
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editStudent(BuildContext context, Student student) {
    final nameController = TextEditingController(text: student.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Student'),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              if (updatedName.isEmpty) return;
              student.name = updatedName;
              await student.save();
              if (mounted) setState(() {});
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
    final metadata = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        AppPillTag(
          label: 'ID ${student.id}',
          backgroundColor: AppTheme.blueSoft,
          foregroundColor: AppTheme.blue,
        ),
        AppPillTag(
          label: '${student.embeddings.length} samples',
          backgroundColor: AppTheme.accentSoft,
          foregroundColor: AppTheme.accentDark,
        ),
      ],
    );

    return AppPanel(
      radius: 14,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      elevated: false,
      child: Row(
        children: [
          _AvatarLetter(name: student.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                metadata,
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onEdit,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.blueSoft,
              foregroundColor: AppTheme.blue,
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            onPressed: onDelete,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.dangerSoft,
              foregroundColor: AppTheme.danger,
            ),
            icon: const Icon(Icons.delete_outline),
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
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppTheme.blueGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.panelShadow,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppPanel(
                radius: 28,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                elevated: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppTheme.orangeGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppTheme.panelShadow,
                      ),
                      child: const Icon(
                        Icons.person_search_outlined,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
