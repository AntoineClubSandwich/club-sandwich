import 'package:flutter/material.dart';

import '../../tokens/ds_typography.dart';

enum DsAvatarSize { sm, md, lg }

extension on DsAvatarSize {
  double get diameter => switch (this) {
    DsAvatarSize.sm => 24,
    DsAvatarSize.md => 32,
    DsAvatarSize.lg => 48,
  };

  TextStyle textStyle(Color color) => switch (this) {
    DsAvatarSize.sm => DsTypography.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    ),
    DsAvatarSize.md => DsTypography.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    ),
    DsAvatarSize.lg => DsTypography.body.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    ),
  };
}

/// A restrained, muted palette an avatar's background is deterministically
/// picked from (by hashing [DsAvatar.initials]) — never the saturated
/// brand orange/blue, to keep a wall of avatars calm rather than busy.
const List<Color> _avatarPalette = [
  Color(0xFFE7E9F7), // secondary tint
  Color(0xFFFCE9E3), // primary tint
  Color(0xFFE7F6EE), // success tint
  Color(0xFFEAF2FD), // info tint
  Color(0xFFFCF1DC), // warning tint
  Color(0xFFF1F2F4), // neutral tint
];

const List<Color> _avatarForeground = [
  Color(0xFF293283),
  Color(0xFFB93A1A),
  Color(0xFF187A45),
  Color(0xFF1F5BB0),
  Color(0xFFA66C0B),
  Color(0xFF5B6270),
];

/// A person/organisation avatar — initials on a deterministic muted tint,
/// or an image with initials as the loading/error fallback.
class DsAvatar extends StatelessWidget {
  const DsAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = DsAvatarSize.md,
    this.square = false,
  });

  final String initials;
  final String? imageUrl;
  final DsAvatarSize size;

  /// Rounded-square shape instead of a circle — used for organisation
  /// marks, which read more like a logo than a person.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final index = initials.isEmpty
        ? 0
        : initials.codeUnitAt(0) % _avatarPalette.length;
    final background = _avatarPalette[index];
    final foreground = _avatarForeground[index];
    final diameter = size.diameter;

    final fallback = Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(diameter * 0.28) : null,
      ),
      child: Text(initials.toUpperCase(), style: size.textStyle(foreground)),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: square
          ? BorderRadius.circular(diameter * 0.28)
          : BorderRadius.circular(diameter),
      child: Image.network(
        imageUrl!,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}
