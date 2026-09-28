import 'package:flutter/cupertino.dart';

import '../models/student.dart';
import '../ui/insight_ui.dart';

/// Enrollment needs the camera and on-device face models, which the web
/// build doesn't have.
class EnrollStudentScreen extends StatelessWidget {
  const EnrollStudentScreen({super.key, this.student});

  final Student? student;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: insightPushedBar(
        title: student == null ? 'New Student' : 'Re-enroll Face',
        modal: true,
      ),
      child: const EmptyState(
        icon: CupertinoIcons.desktopcomputer,
        title: 'Enroll on a Device',
        message:
            'Enrollment uses the camera and on-device face models. Open '
            'Insight on the Mac, PC, iPhone or Android device to enroll.',
      ),
    );
  }
}
