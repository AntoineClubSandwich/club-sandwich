import 'dart:math' as math;

import 'package:club_sandwich/features/encounters/domain/maraude_encounter.dart';

class EncounterCluster {
  const EncounterCluster({
    required this.latitude,
    required this.longitude,
    required this.encounters,
  });

  final double latitude;
  final double longitude;
  final List<MaraudeEncounter> encounters;
}

List<EncounterCluster> clusterEncounters(
  List<MaraudeEncounter> encounters,
  double zoom,
) {
  final cellSize = switch (zoom) {
    >= 16 => 0.0005,
    >= 14 => 0.003,
    >= 12 => 0.012,
    >= 10 => 0.035,
    _ => 0.09,
  };
  final groups = <String, List<MaraudeEncounter>>{};
  for (final encounter in encounters) {
    final row = (encounter.latitude / cellSize).floor();
    final column = (encounter.longitude / cellSize).floor();
    groups.putIfAbsent('$row:$column', () => []).add(encounter);
  }
  return groups.values
      .map((items) {
        final latitude = items.fold<double>(
          0,
          (sum, item) => sum + item.latitude,
        );
        final longitude = items.fold<double>(
          0,
          (sum, item) => sum + item.longitude,
        );
        return EncounterCluster(
          latitude: latitude / math.max(1, items.length),
          longitude: longitude / math.max(1, items.length),
          encounters: List.unmodifiable(items),
        );
      })
      .toList(growable: false);
}
