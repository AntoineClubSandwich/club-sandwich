import 'package:club_sandwich/core/router/app_router.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_borders.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_shadows.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/avatar/data/avatar_providers.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_character.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Whether the "mode 1" quick popover (sidebar character widget) is open.
/// Owned here rather than as local widget state since it's toggled from
/// the sidebar and rendered as a sibling overlay in [AppShell].
class AvatarPopoverOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool value) => state = value;
}

final avatarPopoverOpenProvider = NotifierProvider<AvatarPopoverOpen, bool>(
  AvatarPopoverOpen.new,
);

/// Slide-in panel anchored to the sidebar's right edge — a quick preview
/// of the equipped animal companion, with a link out to the full
/// customizer where it can actually be changed.
class AvatarSidebarPopover extends ConsumerWidget {
  const AvatarSidebarPopover({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final asyncConfig = ref.watch(currentAvatarConfigProvider);
    final profile = ref.watch(currentProfileProvider).value;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.xlRadius,
          border: Border.all(color: colors.border, width: DsBorders.hairline),
          boxShadow: DsShadows.ambientElevated(colors.textPrimary),
        ),
        child: asyncConfig.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Impossible de charger ton personnage.',
            style: DsTypography.body.copyWith(color: colors.textSecondary),
          ),
          data: (config) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile == null ? 'Mon animal' : profile.firstName,
                      style: DsTypography.h3.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: Icon(DsIcons.close, size: 18, color: colors.textSecondary),
                    onPressed: () =>
                        ref.read(avatarPopoverOpenProvider.notifier).setOpen(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.md),
              Center(
                child: Container(
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.secondarySelectedBg,
                    borderRadius: DsRadius.lgRadius,
                  ),
                  padding: const EdgeInsets.all(DsSpacing.sm),
                  child: AvatarCharacter(config: config, size: 120),
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              GestureDetector(
                onTap: () {
                  ref.read(avatarPopoverOpenProvider.notifier).setOpen(false);
                  context.go(AppRoutes.personalization);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Changer d\'animal',
                      style: DsTypography.meta.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(DsIcons.chevronRight, size: 14, color: colors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
