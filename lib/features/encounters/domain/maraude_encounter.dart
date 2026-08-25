class MaraudeEncounter {
  const MaraudeEncounter({
    required this.id,
    required this.maraudeId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.createdAt,
    required this.createdBy,
    this.maraudeDate,
    this.artist,
    this.venueId,
    this.venueName,
    this.createdByName,
    this.teamNames = const [],
  });

  factory MaraudeEncounter.fromJson(Map<String, dynamic> json) =>
      MaraudeEncounter(
        id: json['id'] as String,
        maraudeId: json['maraude_id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        createdBy: json['created_by'] as String,
        maraudeDate: json['maraude_date'] == null
            ? null
            : DateTime.parse(json['maraude_date'] as String),
        artist: json['artist'] as String?,
        venueId: json['venue_id'] as String?,
        venueName: json['venue_name'] as String?,
        createdByName: json['created_by_name'] as String?,
        teamNames: (json['team_names'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final String id;
  final String maraudeId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? maraudeDate;
  final String? artist;
  final String? venueId;
  final String? venueName;
  final String? createdByName;
  final List<String> teamNames;
}

class EncounterMapPeriod {
  const EncounterMapPeriod({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is EncounterMapPeriod && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class EncounterMapSummary {
  const EncounterMapSummary({
    required this.encounterCount,
    required this.maraudeCount,
    required this.activeZoneCount,
  });

  factory EncounterMapSummary.from(List<MaraudeEncounter> encounters) =>
      EncounterMapSummary(
        encounterCount: encounters.length,
        maraudeCount: encounters.map((item) => item.maraudeId).toSet().length,
        activeZoneCount: encounters
            .map((item) => '${item.latitude}:${item.longitude}')
            .toSet()
            .length,
      );

  final int encounterCount;
  final int maraudeCount;
  final int activeZoneCount;

  double get encountersPerMaraude =>
      maraudeCount == 0 ? 0 : encounterCount / maraudeCount;
}
