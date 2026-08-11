import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:club_sandwich/features/avatar/domain/character_portrait.dart';
import 'package:flutter/material.dart';

/// Renders a user's pixel-art character as the ready-made portrait they
/// picked (see [CharacterCatalogue]) — real per-item layered compositing
/// isn't possible with the sprites currently available (most worn-item
/// categories only have full-body composite art, not isolated pieces;
/// see [AvatarCatalogue]'s doc comment). The other [AvatarConfig] fields
/// stay as a cosmetic "equipped" badge list until real isolated art
/// exists to composite them onto this portrait.
class AvatarCharacter extends StatelessWidget {
  const AvatarCharacter({required this.config, this.size = 120, super.key});

  final AvatarConfig config;
  final double size;

  /// Portrait canvas is 480x640 (3:4) — [Image.asset]'s `BoxFit.contain`
  /// needs both dimensions bounded to size itself, so this widget must be
  /// self-contained on width too rather than relying on an ambient
  /// constraint that may be unbounded (e.g. inside a centered/aligned
  /// container).
  static const _aspectRatio = 480 / 640;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size * _aspectRatio,
      child: Image.asset(
        CharacterCatalogue.byId(config.characterId).spritePath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
