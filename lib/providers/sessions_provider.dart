import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final list = (jsonDecode(raw) as List)
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
