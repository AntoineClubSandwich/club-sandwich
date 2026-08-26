import 'package:flutter/material.dart';

import '../../tokens/ds_tokens.dart';
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
    // Keep this low-level identity component usable in isolated dialogs and
    // widget tests that provide a plain Material theme.
    final colors =
        (Theme.of(context).extension<DsTokens>() ?? DsTokens.light).colors;
    // A restrained, muted palette an avatar's background is deterministically
    // picked from (by hashing initials) — never the saturated brand purple,
    // to keep a wall of avatars calm rather than busy.
    final palette = [
      colors.secondarySelectedBg,
      colors.primarySelectedBg,
      colors.successBg,
      colors.infoBg,
      colors.warningBg,
      colors.neutralSelectedBg,
    ];
    final foregrounds = [
      colors.secondary,
      colors.primary,
      colors.success,
      colors.info,
      colors.warning,
      colors.textSecondary,
    ];
    final index = initials.isEmpty
        ? 0
        : initials.codeUnitAt(0) % palette.length;
    final background = palette[index];
    final foreground = foregrounds[index];
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
