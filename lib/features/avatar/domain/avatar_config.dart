/// A user's chosen animal companion. Purely cosmetic — no operational
/// impact — stored as JSON in `avatar_configs.config`. [pet] is an
/// [AvatarCatalogue] id; which ones are selectable depends on maraudes
/// completed (see [AvatarItem.isUnlockedFor]).
class AvatarConfig {
  const AvatarConfig({required this.pet});

  final String pet;

  static const defaultConfig = AvatarConfig(pet: 'ferme_vache');

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return defaultConfig;
    return AvatarConfig(pet: json['pet'] as String? ?? defaultConfig.pet);
  }

  Map<String, dynamic> toJson() => {'pet': pet};

  AvatarConfig copyWith({String? pet}) => AvatarConfig(pet: pet ?? this.pet);
}
