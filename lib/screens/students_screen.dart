import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/student_list.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (studentsBox) => AppPageScaffold(
            title: 'Students',
            subtitle: 'Manage student profiles and biometric completeness',
            child: StreamBuilder(
              stream: studentsBox.watch(),
              builder: (context, _) => StudentList(studentsBox: studentsBox),
            ),
          ),
        ),
      ),
    );
  }
}
