class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
