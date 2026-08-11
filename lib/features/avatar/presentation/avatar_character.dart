import 'package:club_sandwich/features/avatar/domain/avatar_catalogue.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:club_sandwich/features/avatar/domain/character_portrait.dart';
import 'package:flutter/material.dart';

/// Renders a user's displayed character. This is genuinely one of two
/// things, not an accessory list applied to a fixed base:
/// - a ready-made human portrait picked from [CharacterCatalogue], or
/// - an animal companion picked from [AvatarCatalogue.pets] — when
///   [AvatarConfig.pet] is set, it *replaces* the human portrait as the
///   character shown, it doesn't sit "on" it.
///
/// The remaining [AvatarConfig] fields (hair/top/held/jewelry/tattoo/...)
/// stay a cosmetic "equipped" badge list until real isolated art exists
/// to composite them onto whichever of the two is showing — see
/// [AvatarCatalogue]'s doc comment for why that isn't possible yet.
class AvatarCharacter extends StatelessWidget {
  const AvatarCharacter({required this.config, this.size = 120, super.key});

  final AvatarConfig config;
  final double size;

  /// Human portraits are 480x640 (3:4); pet sprites are 256x256 (1:1).
  static const _portraitAspectRatio = 480 / 640;

  @override
  Widget build(BuildContext context) {
    final petId = config.pet;
    final String spritePath;
    final double aspectRatio;
    if (petId != null) {
      spritePath = AvatarCatalogue.pets
          .firstWhere((item) => item.id == petId)
          .spritePath!;
      aspectRatio = 1;
    } else {
      spritePath = CharacterCatalogue.byId(config.characterId).spritePath;
      aspectRatio = _portraitAspectRatio;
    }

    return SizedBox(
      height: size,
      width: size * aspectRatio,
      child: Image.asset(
        spritePath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
