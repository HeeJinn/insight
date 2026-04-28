enum FlavorTone { mint, sky, peach, lilac }

class FlavorProfile {
  final String id;
  final String name;
  final String tagline;
  final String note;
  final bool enabled;
  final FlavorTone tone;

  const FlavorProfile({
    required this.id,
    required this.name,
    required this.tagline,
    required this.note,
    required this.enabled,
    required this.tone,
  });

  FlavorProfile copyWith({
    String? id,
    String? name,
    String? tagline,
    String? note,
    bool? enabled,
    FlavorTone? tone,
  }) {
    return FlavorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      note: note ?? this.note,
      enabled: enabled ?? this.enabled,
      tone: tone ?? this.tone,
    );
  }

  factory FlavorProfile.fromJson(Map<String, dynamic> json) {
    return FlavorProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      note: json['note'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      tone: FlavorTone.values.firstWhere(
        (value) => value.name == json['tone'],
        orElse: () => FlavorTone.mint,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tagline': tagline,
    'note': note,
    'enabled': enabled,
    'tone': tone.name,
  };

  static List<FlavorProfile> defaults() => const [
    FlavorProfile(
      id: 'vessel',
      name: 'Vessel',
      tagline: 'Guided onboarding',
      note:
          'Use Vessel for calmer registration moments, more explanation, and a polished admin-first setup flow.',
      enabled: true,
      tone: FlavorTone.mint,
    ),
    FlavorProfile(
      id: 'scoop',
      name: 'Scoop',
      tagline: 'Fast kiosk rhythm',
      note:
          'Use Scoop for scan-heavy sessions where speed, compact layouts, and quick attendance handoff matter most.',
      enabled: true,
      tone: FlavorTone.sky,
    ),
  ];
}
