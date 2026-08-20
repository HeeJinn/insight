import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flavor_profile.dart';

const _flavorProfilesKey = 'workspace_flavors_v1';
const _activeFlavorKey = 'active_flavor_id_v1';

final activeFlavorIdProvider = StateProvider<String>((ref) => 'vessel');

final flavorProfilesProvider =
    StateNotifierProvider<FlavorProfilesController, List<FlavorProfile>>(
      (ref) => FlavorProfilesController(ref)..load(),
    );

final enabledFlavorProfilesProvider = Provider<List<FlavorProfile>>((ref) {
  return ref
      .watch(flavorProfilesProvider)
      .where((profile) => profile.enabled)
      .toList(growable: false);
});

final activeFlavorProfileProvider = Provider<FlavorProfile?>((ref) {
  final activeId = ref.watch(activeFlavorIdProvider);
  final profiles = ref.watch(flavorProfilesProvider);
  for (final profile in profiles) {
    if (profile.id == activeId) {
      return profile;
    }
  }
  return profiles.isNotEmpty ? profiles.first : null;
});

final flavorProfileByIdProvider = Provider.family<FlavorProfile?, String>((
  ref,
  id,
) {
  for (final profile in ref.watch(flavorProfilesProvider)) {
    if (profile.id == id) {
      return profile;
    }
  }
  return null;
});

class FlavorProfilesController extends StateNotifier<List<FlavorProfile>> {
  final Ref _ref;
  FlavorProfilesController(this._ref) : super(FlavorProfile.defaults());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedActive = prefs.getString(_activeFlavorKey);
    if (savedActive != null && savedActive.isNotEmpty) {
      _ref.read(activeFlavorIdProvider.notifier).state = savedActive;
    }

    final raw = prefs.getString(_flavorProfilesKey);
    if (raw == null || raw.isEmpty) {
      state = FlavorProfile.defaults();
      return;
    }

    try {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(FlavorProfile.fromJson)
          .toList(growable: false);
      if (decoded.isNotEmpty) {
        state = decoded;
      }
    } catch (_) {
      state = FlavorProfile.defaults();
    }
  }

  Future<void> setActiveFlavor(String id) async {
    _ref.read(activeFlavorIdProvider.notifier).state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeFlavorKey, id);
  }

  Future<void> upsertFlavor(FlavorProfile profile) async {
    final next = [
      for (final item in state)
        if (item.id == profile.id) profile else item,
    ];
    state = next;
    await _persist(next);
  }

  Future<void> resetFlavor(String id) async {
    final defaults = FlavorProfile.defaults();
    final fallback = defaults.firstWhere(
      (profile) => profile.id == id,
      orElse: () => defaults.first,
    );
    await upsertFlavor(fallback);
  }

  Future<void> resetAll() async {
    final defaults = FlavorProfile.defaults();
    state = defaults;
    await _persist(defaults);
  }

  Future<void> _persist(List<FlavorProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _flavorProfilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }
}
