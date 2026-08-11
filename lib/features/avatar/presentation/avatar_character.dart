import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:flutter/material.dart';

/// Renders a user's pixel-art character. MVP: every config renders the
/// same placeholder illustration (traced from the Figma reference) since
/// per-item layered sprites don't exist yet — see [AvatarCatalogue] for
/// the item mechanics that already work end-to-end (selection, unlocks,
/// persistence). Swap this widget's body for real z-index sprite
/// compositing once `assets/avatar/<category>/<id>.png` sprites land,
/// without touching any call site: they all just pass an [AvatarConfig].
class AvatarCharacter extends StatelessWidget {
  const AvatarCharacter({required this.config, this.size = 120, super.key});

  /// Currently unused pending real per-item sprites — kept as the public
  /// contract so callers don't need to change when layering lands.
  final AvatarConfig config;
  final double size;

  /// Native aspect ratio of `placeholder_character.png` (896x1152) —
  /// [Image.asset]'s `BoxFit.contain` needs both dimensions bounded to
  /// size itself, so this widget must be self-contained on width too
  /// rather than relying on an ambient constraint that may be unbounded
  /// (e.g. inside a centered/aligned container).
  static const _aspectRatio = 896 / 1152;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size * _aspectRatio,
      child: Image.asset(
        'assets/avatar/placeholder_character.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
