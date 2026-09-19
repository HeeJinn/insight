import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/widgets/core_widgets.dart';
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
        child: AppAsyncView(
          value: studentsAsync,
          data: (context, studentsBox) => AppPageScaffold(
            eyebrow: 'ROSTER & BIOMETRIC PROFILES',
            title: 'Students',
            subtitle: 'Manage student identity profiles and facial baseline embeddings',
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
