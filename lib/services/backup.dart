import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/sessions_provider.dart';

export 'backup_files_web.dart' if (dart.library.io) 'backup_files_io.dart';

/// Everything on this device that can't be rebuilt: students with their
/// face profiles, check-ins and sessions. Not the admin PIN or
/// preferences, so a backup file can't unlock another kiosk.
class Backup {
  const Backup({
    required this.createdAt,
    required this.students,
    required this.attendance,
    required this.sessions,
  });

  final DateTime createdAt;
  final List<Student> students;
  final List<Attendance> attendance;
  final List<SessionEntry> sessions;

  static const _format = 'insight-backup';
  static const _version = 1;

  String encode() => jsonEncode({
    'format': _format,
    'version': _version,
    'createdAt': createdAt.toIso8601String(),
    'students': [
      for (final s in students)
        {
          'id': s.id,
          'name': s.name,
          'embeddings': s.embeddings,
          'enrolledAt': ?s.enrolledAt?.toIso8601String(),
        },
    ],
    'attendance': [
      for (final a in attendance)
        {
          'studentId': a.studentId,
          'timestamp': a.timestamp.toIso8601String(),
          'sessionTitle': ?a.sessionTitle,
          'room': ?a.room,
          'latencyMs': ?a.latencyMs,
          if (a.excused) 'excused': true,
          // JSON has no infinity; a margin with no runner-up is dropped.
          if (a.matchDistance?.isFinite ?? false)
            'matchDistance': a.matchDistance,
          if (a.matchMargin?.isFinite ?? false) 'matchMargin': a.matchMargin,
        },
    ],
    'sessions': [for (final s in sessions) s.toJson()],
  });

  /// Reads a backup file's text. Throws a [FormatException] with a message
  /// fit to show when it isn't a backup, comes from a newer Insight, or is
  /// damaged; nothing on the device is touched until this succeeds.
  static Backup decode(String text) {
    Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      root = null;
    }
    if (root is! Map || root['format'] != _format) {
      throw const FormatException("This file isn't an Insight backup.");
    }
    final version = root['version'];
    if (version is! int || version > _version) {
      throw const FormatException(
        'This backup was made by a newer version of Insight.',
      );
    }
    try {
      final students = [
        for (final s in root['students'] as List)
          Student(
            id: s['id'] as String,
            name: s['name'] as String,
            embeddings: [
              for (final e in s['embeddings'] as List)
                [for (final v in e as List) (v as num).toDouble()],
            ],
            enrolledAt: s['enrolledAt'] == null
                ? null
                : DateTime.parse(s['enrolledAt'] as String),
          ),
      ];
      if (students.any((s) => s.id.trim().isEmpty) ||
          students.map((s) => s.id).toSet().length != students.length) {
        throw const FormatException('Student IDs are missing or repeated.');
      }
      return Backup(
        createdAt: DateTime.parse(root['createdAt'] as String),
        students: students,
        attendance: [
          for (final a in root['attendance'] as List)
            Attendance(
              studentId: a['studentId'] as String,
              timestamp: DateTime.parse(a['timestamp'] as String),
              sessionTitle: a['sessionTitle'] as String?,
              room: a['room'] as String?,
              latencyMs: a['latencyMs'] as int?,
              excused: a['excused'] as bool? ?? false,
              matchDistance: (a['matchDistance'] as num?)?.toDouble(),
              matchMargin: (a['matchMargin'] as num?)?.toDouble(),
            ),
        ],
        sessions: [
          for (final j in root['sessions'] as List)
            SessionEntry.fromJson((j as Map).cast<String, dynamic>()),
        ],
      );
    } catch (_) {
      throw const FormatException('This backup is damaged.');
    }
  }

  /// Replaces everything in the boxes and [sessions] with this backup.
  Future<void> restoreInto({
    required Box<Student> students,
    required Box<Attendance> attendance,
    required SessionsController sessions,
  }) async {
    await attendance.clear();
    await students.clear();
    await students.putAll({for (final s in this.students) s.id: s});
    await attendance.addAll(this.attendance);
    await sessions.replaceAll(this.sessions);
  }
}
