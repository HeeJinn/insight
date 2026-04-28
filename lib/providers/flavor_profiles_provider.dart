import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flavor_profile.dart';

const _flavorProfilesKey = 'workspace_flavors_v1';

final flavorProfilesProvider =
    StateNotifierProvider<FlavorProfilesController, List<FlavorProfile>>(
      (ref) => FlavorProfilesController()..load(),
    );

final enabledFlavorProfilesProvider = Provider<List<FlavorProfile>>((ref) {
  return ref
      .watch(flavorProfilesProvider)
      .where((profile) => profile.enabled)
      .toList(growable: false);
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
  FlavorProfilesController() : super(FlavorProfile.defaults());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
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
