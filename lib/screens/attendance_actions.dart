import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';

/// Admin corrections for what the camera can't handle: a student whose
/// face isn't recognized today, an absence with leave, a wrong check-in.

/// Marks [student] present or excused for [session] (a general check-in
/// when null), as of now.
Future<void> showMissingStudentActions(
  BuildContext context, {
  required Box<Attendance> attendance,
  required Student student,
  required SessionEntry? session,
}) async {
  final present = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(student.name),
      message: Text(
        session == null ? 'Today, no session' : '${session.title}, today',
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Mark Present'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Mark Excused'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
  if (present == null) return;
  HapticFeedback.mediumImpact();
  await attendance.add(
    Attendance(
      studentId: student.id,
      timestamp: DateTime.now(),
      sessionTitle: session?.title,
      room: session?.room,
      excused: !present,
    ),
  );
}

/// Switches [record] between present and excused, or deletes it.
Future<void> showRecordActions(
  BuildContext context, {
  required Attendance record,
  required String name,
}) async {
  final action = await showCupertinoModalPopup<_RecordAction>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Text(name),
      message: Text(record.sessionTitle ?? 'General check-in'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_RecordAction.toggle),
          child: Text(record.excused ? 'Mark Present' : 'Mark Excused'),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(_RecordAction.delete),
          child: const Text('Delete Check-in'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
  switch (action) {
    case _RecordAction.toggle:
      record.excused = !record.excused;
      await record.save();
    case _RecordAction.delete:
      await record.delete();
    case null:
      return;
  }
  HapticFeedback.mediumImpact();
}

enum _RecordAction { toggle, delete }
