import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/attendance_filter.dart';

const _savedFiltersKey = 'attendance_saved_filters_v1';

/// Attendance filters the admin named and saved, in the order saved.
final savedFiltersProvider =
    StateNotifierProvider<SavedFiltersController, List<SavedAttendanceFilter>>(
      (ref) => SavedFiltersController()..load(),
    );

class SavedFiltersController
    extends StateNotifier<List<SavedAttendanceFilter>> {
  SavedFiltersController() : super(const []);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedFiltersKey) ?? const [];
    state = [
      for (final item in raw)
        SavedAttendanceFilter.fromJson(
          (jsonDecode(item) as Map).cast<String, dynamic>(),
        ),
    ];
  }

  /// Saves [filter] as [name], replacing any saved filter with that name.
  Future<void> save(String name, AttendanceFilter filter) async {
    final saved = SavedAttendanceFilter(name: name, filter: filter);
    final exists = state.any((s) => s.name == name);
    await _persist(
      exists
          ? [for (final s in state) s.name == name ? saved : s]
          : [...state, saved],
    );
  }

  Future<void> delete(String name) async {
    await _persist(state.where((s) => s.name != name).toList());
  }

  Future<void> _persist(List<SavedAttendanceFilter> next) async {
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedFiltersKey, [
      for (final s in next) jsonEncode(s.toJson()),
    ]);
  }
}
