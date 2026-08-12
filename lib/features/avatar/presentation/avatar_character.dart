import 'package:club_sandwich/features/avatar/domain/avatar_catalogue.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:flutter/material.dart';

/// Renders a user's equipped animal companion — the only thing left to
/// customize (see [AvatarCatalogue]). All pet sprites are a 256x256 (1:1)
/// canvas, so this widget is simply square.
class AvatarCharacter extends StatelessWidget {
  const AvatarCharacter({required this.config, this.size = 120, super.key});

  final AvatarConfig config;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spritePath = AvatarCatalogue.byId(config.pet).spritePath;
    return SizedBox(
      height: size,
      width: size,
      child: Image.asset(
        spritePath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
