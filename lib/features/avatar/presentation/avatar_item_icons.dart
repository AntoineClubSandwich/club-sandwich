import 'package:club_sandwich/features/avatar/domain/avatar_catalogue.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/widgets.dart';

/// Glyph shown in a garde-robe grid cell, standing in for real per-item
/// artwork (see [AvatarCharacter]'s doc comment — no sprite catalogue
/// exists yet). Falls back to a generic per-category icon when an item
/// doesn't have a close Lucide match.
IconData avatarItemIcon(AvatarCategory category, String id) {
  return switch (id) {
    'sandwich' => LucideIcons.sandwich,
    'backpack_maraude' => LucideIcons.backpack,
    'cabas' => LucideIcons.shoppingBasket,
    'thermos' => LucideIcons.coffee,
    'megaphone' => LucideIcons.megaphone,
    'guitar' => LucideIcons.guitar,
    'guitar_back' => LucideIcons.guitar,
    'vinyl' => LucideIcons.disc,
    'mic' => LucideIcons.mic,
    'lightsaber' => LucideIcons.sword,
    'magic_wand' => LucideIcons.wandSparkles,
    'mjolnir' => LucideIcons.hammer,
    'cap' || 'cap_backward' => LucideIcons.shoppingBag,
    'beanie' || 'bucket_hat' => LucideIcons.gift,
    'headphones' => LucideIcons.headphones,
    'sunglasses' || 'elton_glasses' => LucideIcons.glasses,
    'bandana' => LucideIcons.feather,
    'helmet_daft' => LucideIcons.hardHat,
    'crown' => LucideIcons.crown,
    'santa_hat' => LucideIcons.snowflake,
    'cape' => LucideIcons.feather,
    'wings' => LucideIcons.bird,
    'sneakers' || 'converse' || 'docs' || 'platforms' => LucideIcons.sportShoe,
    'boots' || 'sandals' => LucideIcons.footprints,
    _ => switch (category) {
      AvatarCategory.top => LucideIcons.shirt,
      AvatarCategory.bottom => LucideIcons.shirt,
      AvatarCategory.shoes => LucideIcons.footprints,
      AvatarCategory.hair => LucideIcons.sparkles,
      AvatarCategory.face => LucideIcons.smile,
      AvatarCategory.body => LucideIcons.user,
      AvatarCategory.head => LucideIcons.gem,
      AvatarCategory.back => LucideIcons.backpack,
      AvatarCategory.held => LucideIcons.sandwich,
    },
  };
}
