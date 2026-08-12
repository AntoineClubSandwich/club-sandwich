import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_semantic_variant.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_secondary_button.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_borders.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/avatar/data/avatar_providers.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_catalogue.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_character.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_progress.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math';

const _tiers = [
  (0, '⭐ Niveau 1 — Communs (dès l\'inscription)'),
  (5, '⭐⭐ Niveau 2 — Peu communs (5 maraudes)'),
  (10, '⭐⭐⭐ Niveau 3 — Rares (10 maraudes)'),
  (15, '💎 Niveau 4 — Épiques (15 maraudes)'),
  (20, '👑 Niveau 5 — Légendaires (20 maraudes)'),
];

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  AvatarConfig? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final asyncConfig = ref.watch(currentAvatarConfigProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncConfig.when(
        loading: () => const AppLoadingState(label: 'Chargement du personnage'),
        error: (_, _) => AppErrorState(
          message: 'Impossible de charger ton personnage.',
          onRetry: () => ref.invalidate(currentAvatarConfigProvider),
        ),
        data: (initial) {
          _draft ??= initial;
          return _content(context, _draft!);
        },
      ),
    );
  }

  void _update(AvatarConfig Function(AvatarConfig current) updater) {
    setState(() => _draft = updater(_draft!));
  }

  Future<void> _save() async {
    if (_draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(avatarRepositoryProvider).saveCurrentAvatar(_draft!);
      ref.invalidate(currentAvatarConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Personnage sauvegardé.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible de sauvegarder le personnage.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _randomize(int maraudesCompleted) {
    final random = Random();
    final unlocked = AvatarCatalogue.pets
        .where((item) => item.isUnlockedFor(maraudesCompleted: maraudesCompleted))
        .toList();
    setState(() {
      _draft = _draft!.copyWith(pet: unlocked[random.nextInt(unlocked.length)].id);
    });
  }

  Widget _content(BuildContext context, AvatarConfig config) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final profile = ref.watch(currentProfileProvider).value;
    final maraudesCompleted = ref.watch(maraudesCompletedProvider);
    final fullName = profile == null
        ? '...'
        : '${profile.firstName} ${profile.lastName}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 960;
          final preview = _PreviewCard(
            config: config,
            fullName: fullName,
            tierLabel: avatarTierLabel(maraudesCompleted),
          );
          final picker = _PetPickerPanel(
            config: config,
            maraudesCompleted: maraudesCompleted,
            onUpdate: _update,
            saving: _saving,
            onSave: _save,
            onRandom: () => _randomize(maraudesCompleted),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mon personnage', style: DsTypography.h1.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Choisis l\'animal qui te représente sur Club Sandwich',
                style: DsTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: DsSpacing.xl),
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(height: DsSpacing.xl),
                    picker,
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: preview),
                      const SizedBox(width: DsSpacing.xl),
                      SizedBox(width: 420, child: picker),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.config,
    required this.fullName,
    required this.tierLabel,
  });

  final AvatarConfig config;
  final String fullName;
  final String tierLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsCard(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 420,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.secondarySelectedBg,
              borderRadius: DsRadius.xlRadius,
            ),
            child: AvatarCharacter(config: config, size: 340),
          ),
          const SizedBox(height: DsSpacing.lg),
          Text(
            fullName,
            style: DsTypography.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            AvatarCatalogue.byId(config.pet).label,
            style: DsTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpacing.sm),
          DsBadge(label: tierLabel, variant: DsSemanticVariant.info),
        ],
      ),
    );
  }
}

class _PetPickerPanel extends StatelessWidget {
  const _PetPickerPanel({
    required this.config,
    required this.maraudesCompleted,
    required this.onUpdate,
    required this.saving,
    required this.onSave,
    required this.onRandom,
  });

  final AvatarConfig config;
  final int maraudesCompleted;
  final void Function(AvatarConfig Function(AvatarConfig current)) onUpdate;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onRandom;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MON ANIMAL',
            style: DsTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Plus tu fais de maraudes, plus tu débloques d\'animaux stylés.',
            style: DsTypography.meta.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpacing.lg),
          for (final tier in _tiers) ...[
            Text(tier.$2, style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              items: AvatarCatalogue.pets
                  .where((p) => !p.requiresBadge && p.maraudesRequired == tier.$1)
                  .toList(),
              selectedId: config.pet,
              maraudesCompleted: maraudesCompleted,
              onSelect: (id) => onUpdate((c) => c.copyWith(pet: id)),
            ),
            const SizedBox(height: DsSpacing.lg),
          ],
          Text('🏅 Badges (accomplissements)', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: DsSpacing.sm),
          _ItemGrid(
            items: AvatarCatalogue.pets.where((p) => p.requiresBadge).toList(),
            selectedId: config.pet,
            maraudesCompleted: maraudesCompleted,
            onSelect: (id) => onUpdate((c) => c.copyWith(pet: id)),
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              Icon(DsIcons.info, size: 14, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  'Débloque plus d\'animaux en participant aux maraudes',
                  style: DsTypography.meta.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.lg),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: DsSpacing.lg),
          DsPrimaryButton(
            label: 'Sauvegarder',
            isFullWidth: true,
            isLoading: saving,
            onPressed: onSave,
          ),
          const SizedBox(height: DsSpacing.sm),
          DsSecondaryButton(
            label: 'Générer au hasard 🎲',
            isFullWidth: true,
            onPressed: onRandom,
          ),
        ],
      ),
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.items,
    required this.selectedId,
    required this.maraudesCompleted,
    required this.onSelect,
  });

  final List<AvatarItem> items;
  final String selectedId;
  final int maraudesCompleted;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.sm,
      runSpacing: DsSpacing.sm,
      children: [
        for (final item in items)
          _ItemCell(
            item: item,
            selected: item.id == selectedId,
            locked: !item.isUnlockedFor(maraudesCompleted: maraudesCompleted),
            onTap: () => onSelect(item.id),
          ),
      ],
    );
  }
}

class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.item,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final AvatarItem item;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    final cell = Opacity(
      opacity: locked ? 0.4 : 1,
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.mdRadius,
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 2 : DsBorders.hairline,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.1),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : const [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(item.spritePath, fit: BoxFit.contain),
            ),
            if (locked)
              Positioned(
                right: 4,
                bottom: 4,
                child: Icon(LucideIcons.lock, size: 12, color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );

    return Tooltip(
      message: locked ? item.lockedTooltip : item.label,
      child: GestureDetector(onTap: locked ? null : onTap, child: cell),
    );
  }
}
