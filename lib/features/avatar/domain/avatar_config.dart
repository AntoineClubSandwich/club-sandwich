/// A user's pixel-art character customization. Purely cosmetic — no
/// operational impact — stored as JSON in `avatar_configs.config`.
class AvatarConfig {
  const AvatarConfig({
    required this.bodyType,
    required this.skinTone,
    required this.eyes,
    required this.mouth,
    required this.hairStyle,
    required this.hairColor,
    required this.topStyle,
    required this.topColor,
    required this.bottomStyle,
    required this.bottomColor,
    required this.shoesStyle,
    required this.heldObject,
    this.headAccessory,
    this.backItem,
  });

  final int bodyType;
  final String skinTone;
  final String eyes;
  final String mouth;
  final String hairStyle;
  final String hairColor;
  final String topStyle;
  final String topColor;
  final String bottomStyle;
  final String bottomColor;
  final String shoesStyle;
  final String heldObject;
  final String? headAccessory;
  final String? backItem;

  static const defaultConfig = AvatarConfig(
    bodyType: 1,
    skinTone: '#E8B084',
    eyes: 'default',
    mouth: 'smile',
    hairStyle: 'short',
    hairColor: '#2D2B1F',
    topStyle: 'hoodie',
    topColor: '#6C5CE7',
    bottomStyle: 'jeans',
    bottomColor: '#2C2C3A',
    shoesStyle: 'sneakers',
    heldObject: 'sandwich',
  );

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return defaultConfig;
    return AvatarConfig(
      bodyType: (json['body_type'] as num?)?.toInt() ?? defaultConfig.bodyType,
      skinTone: json['skin_tone'] as String? ?? defaultConfig.skinTone,
      eyes: json['eyes'] as String? ?? defaultConfig.eyes,
      mouth: json['mouth'] as String? ?? defaultConfig.mouth,
      hairStyle: json['hair_style'] as String? ?? defaultConfig.hairStyle,
      hairColor: json['hair_color'] as String? ?? defaultConfig.hairColor,
      topStyle: json['top_style'] as String? ?? defaultConfig.topStyle,
      topColor: json['top_color'] as String? ?? defaultConfig.topColor,
      bottomStyle: json['bottom_style'] as String? ?? defaultConfig.bottomStyle,
      bottomColor: json['bottom_color'] as String? ?? defaultConfig.bottomColor,
      shoesStyle: json['shoes_style'] as String? ?? defaultConfig.shoesStyle,
      heldObject: json['held_object'] as String? ?? defaultConfig.heldObject,
      headAccessory: json['head_accessory'] as String?,
      backItem: json['back_item'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'body_type': bodyType,
      'skin_tone': skinTone,
      'eyes': eyes,
      'mouth': mouth,
      'hair_style': hairStyle,
      'hair_color': hairColor,
      'top_style': topStyle,
      'top_color': topColor,
      'bottom_style': bottomStyle,
      'bottom_color': bottomColor,
      'shoes_style': shoesStyle,
      'held_object': heldObject,
      'head_accessory': headAccessory,
      'back_item': backItem,
    };
  }

  AvatarConfig copyWith({
    int? bodyType,
    String? skinTone,
    String? eyes,
    String? mouth,
    String? hairStyle,
    String? hairColor,
    String? topStyle,
    String? topColor,
    String? bottomStyle,
    String? bottomColor,
    String? shoesStyle,
    String? heldObject,
    Object? headAccessory = _unset,
    Object? backItem = _unset,
  }) {
    return AvatarConfig(
      bodyType: bodyType ?? this.bodyType,
      skinTone: skinTone ?? this.skinTone,
      eyes: eyes ?? this.eyes,
      mouth: mouth ?? this.mouth,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      topStyle: topStyle ?? this.topStyle,
      topColor: topColor ?? this.topColor,
      bottomStyle: bottomStyle ?? this.bottomStyle,
      bottomColor: bottomColor ?? this.bottomColor,
      shoesStyle: shoesStyle ?? this.shoesStyle,
      heldObject: heldObject ?? this.heldObject,
      headAccessory: identical(headAccessory, _unset)
          ? this.headAccessory
          : headAccessory as String?,
      backItem: identical(backItem, _unset)
          ? this.backItem
          : backItem as String?,
    );
  }
}

const _unset = Object();
