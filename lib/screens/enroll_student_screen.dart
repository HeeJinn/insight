import 'package:flutter/cupertino.dart';

import '../models/student.dart';
import 'enroll_student_web.dart' if (dart.library.io) 'enroll_student_io.dart';

export 'enroll_student_web.dart' if (dart.library.io) 'enroll_student_io.dart';

/// Opens enrollment full screen, over the sidebar and tab bar. With
/// [student] it re-enrolls that student's face.
Future<void> showEnrollStudent(BuildContext context, {Student? student}) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EnrollStudentScreen(student: student),
    ),
  );
}
