class VolunteerStatistics {
  const VolunteerStatistics({
    required this.memberSince,
    required this.maraudesCompleted,
    required this.volunteeringHours,
    required this.roles,
    required this.invitationsObtained,
    required this.collectiveWeightKg,
    required this.collectiveMeals,
  });

  factory VolunteerStatistics.fromJson(Map<String, dynamic> json) {
    return VolunteerStatistics(
      memberSince: DateTime.parse(json['member_since'] as String),
      maraudesCompleted: (json['maraudes_completed'] as num).toInt(),
      volunteeringHours: (json['volunteering_hours'] as num).toDouble(),
      roles: Map<String, int>.unmodifiable(
        (json['roles'] as Map<String, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
      ),
      invitationsObtained: (json['invitations_obtained'] as num).toInt(),
      collectiveWeightKg: (json['collective_weight_kg'] as num).toDouble(),
      collectiveMeals: (json['collective_meals'] as num).toInt(),
    );
  }

  final DateTime memberSince;
  final int maraudesCompleted;
  final double volunteeringHours;
  final Map<String, int> roles;
  final int invitationsObtained;
  final double collectiveWeightKg;
  final int collectiveMeals;
}
