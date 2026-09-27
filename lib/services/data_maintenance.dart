import 'package:hive_ce/hive.dart';

import '../models/attendance.dart';

/// Deletes check-ins recorded before [olderThan] ago, or all of them when
/// [olderThan] is null. Returns how many were deleted.
Future<int> deleteCheckIns(
  Box<Attendance> box, {
  Duration? olderThan,
  DateTime? now,
}) async {
  if (olderThan == null) return box.clear();
  final cutoff = (now ?? DateTime.now()).subtract(olderThan);
  final old = [
    for (final r in box.values)
      if (r.timestamp.isBefore(cutoff)) r.key,
  ];
  await box.deleteAll(old);
  return old.length;
}
