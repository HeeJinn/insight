import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../models/session_entry.dart';

const _sessionsKey = 'sessions_v1';

final sessionsProvider =
    StateNotifierProvider<SessionsController, List<SessionEntry>>(
      (ref) => SessionsController()..load(),
    );

class SessionsController extends StateNotifier<List<SessionEntry>> {
  SessionsController() : super(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) {
      state = const [];
      return;
    }
    final list =
        (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(SessionEntry.fromJson)
            .toList()
          ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    state = list;
  }

  Future<void> addSession(SessionEntry session) async {
    final next = [...state, session]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    state = next;
    await _persist(next);
  }

  /// Replaces the session with the same id. Check-ins are filed by session
  /// title, so a rename carries them along to the new title in
  /// [attendance], unless another session still uses the old one (a one-off
  /// can share a weekly class's title on purpose).
  Future<void> updateSession(
    SessionEntry session, {
    Box<Attendance>? attendance,
  }) async {
    final oldTitle = state.where((s) => s.id == session.id).firstOrNull?.title;
    final next = [for (final s in state) s.id == session.id ? session : s]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    state = next;
    await _persist(next);

    if (attendance == null ||
        oldTitle == null ||
        oldTitle == session.title ||
        next.any((s) => s.title == oldTitle)) {
      return;
    }
    for (final r in attendance.values.where(
      (r) => r.sessionTitle == oldTitle,
    )) {
      r.sessionTitle = session.title;
      await r.save();
    }
  }

  /// Replaces every session, as restoring a backup does.
  Future<void> replaceAll(List<SessionEntry> sessions) async {
    final next = [...sessions]
      ..sort((a, b) => a.startMinuteOfDay.compareTo(b.startMinuteOfDay));
    state = next;
    await _persist(next);
  }

  /// Drops a deleted student from every class list.
  Future<void> removeStudent(String studentId) async {
    if (!state.any((s) => s.studentIds.contains(studentId))) return;
    final next = [
      for (final s in state)
        s.copyWith(studentIds: {...s.studentIds}..remove(studentId)),
    ];
    state = next;
    await _persist(next);
  }

  Future<void> removeSession(String id) async {
    final next = state.where((s) => s.id != id).toList(growable: false);
    state = next;
    await _persist(next);
  }

  Future<void> _persist(List<SessionEntry> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, raw);
  }
}
