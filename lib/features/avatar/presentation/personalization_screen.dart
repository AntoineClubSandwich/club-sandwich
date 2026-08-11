import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_semantic_variant.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_secondary_button.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_borders.dart';
import 'package:club_sandwich/design_system/tokens/ds_motion.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_shadows.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/avatar/data/avatar_providers.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_catalogue.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_character.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_item_icons.dart';
import 'package:club_sandwich/features/avatar/presentation/avatar_progress.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math';

enum _CustomizerTab { body, hair, top, bottom, shoes, held, accessories, colors }

extension on _CustomizerTab {
  String get label => switch (this) {
    _CustomizerTab.body => 'Corps',
    _CustomizerTab.hair => 'Tête',
    _CustomizerTab.top => 'Haut',
    _CustomizerTab.bottom => 'Bas',
    _CustomizerTab.shoes => 'Chaussures',
    _CustomizerTab.held => 'Objet',
    _CustomizerTab.accessories => 'Accessoires',
    _CustomizerTab.colors => 'Couleurs',
  };
}

class PersonalizationScreen extends ConsumerStatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  ConsumerState<PersonalizationScreen> createState() =>
      _PersonalizationScreenState();
}

class _PersonalizationScreenState extends ConsumerState<PersonalizationScreen> {
  AvatarConfig? _draft;
  _CustomizerTab _tab = _CustomizerTab.body;
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
    AvatarItem pickUnlocked(List<AvatarItem> items) {
      final unlocked = items
          .where((item) => item.isUnlockedFor(maraudesCompleted: maraudesCompleted))
          .toList();
      return unlocked[random.nextInt(unlocked.length)];
    }

    setState(() {
      _draft = _draft!.copyWith(
        bodyType: random.nextInt(AvatarCatalogue.bodyTypes.length) + 1,
        skinTone:
            AvatarCatalogue.skinTones[random.nextInt(AvatarCatalogue.skinTones.length)],
        hairStyle: pickUnlocked(AvatarCatalogue.hairStyles).id,
        topStyle: pickUnlocked(AvatarCatalogue.topStyles).id,
        topColor:
            AvatarCatalogue.colorPresets[random.nextInt(AvatarCatalogue.colorPresets.length)],
        bottomStyle: pickUnlocked(AvatarCatalogue.bottomStyles).id,
        shoesStyle: pickUnlocked(AvatarCatalogue.shoesStyles).id,
        heldObject: pickUnlocked(AvatarCatalogue.heldObjects).id,
      );
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
          final wardrobe = _WardrobePanel(
            tab: _tab,
            onTabChanged: (tab) => setState(() => _tab = tab),
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
                'Personnalise ton avatar Club Sandwich',
                style: DsTypography.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: DsSpacing.xl),
              if (narrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(height: DsSpacing.xl),
                    wardrobe,
                  ],
                )
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: preview),
                      const SizedBox(width: DsSpacing.xl),
                      SizedBox(width: 420, child: wardrobe),
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
    final equipped = <String?>[
      _labelFor(AvatarCatalogue.topStyles, config.topStyle),
      _labelFor(AvatarCatalogue.bottomStyles, config.bottomStyle),
      _labelFor(AvatarCatalogue.heldObjects, config.heldObject),
      if (config.headAccessory != null)
        _labelFor(AvatarCatalogue.headAccessories, config.headAccessory!),
      if (config.backItem != null)
        _labelFor(AvatarCatalogue.backItems, config.backItem!),
      if (config.jewelry != null)
        _labelFor(AvatarCatalogue.jewelryItems, config.jewelry!),
      if (config.tattoo != null)
        _labelFor(AvatarCatalogue.tattoos, config.tattoo!),
      if (config.pet != null) _labelFor(AvatarCatalogue.pets, config.pet!),
    ].whereType<String>().toList();

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
          DsBadge(label: tierLabel, variant: DsSemanticVariant.info),
          const SizedBox(height: DsSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ÉQUIPÉ',
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              for (final label in equipped) DsBadge(label: label),
            ],
          ),
        ],
      ),
    );
  }

  String? _labelFor(List<AvatarItem> items, String id) {
    for (final item in items) {
      if (item.id == id) return item.label;
    }
    return null;
  }
}

class _WardrobePanel extends StatelessWidget {
  const _WardrobePanel({
    required this.tab,
    required this.onTabChanged,
    required this.config,
    required this.maraudesCompleted,
    required this.onUpdate,
    required this.saving,
    required this.onSave,
    required this.onRandom,
  });

  final _CustomizerTab tab;
  final ValueChanged<_CustomizerTab> onTabChanged;
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
            'GARDE-ROBE',
            style: DsTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Sélectionne un accessoire ou un outil pour tes maraudes',
            style: DsTypography.meta.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpacing.lg),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.secondarySelectedBg,
              borderRadius: DsRadius.mdRadius,
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final t in _CustomizerTab.values)
                  _TabPill(
                    label: t.label,
                    selected: t == tab,
                    onTap: () => onTabChanged(t),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),
          _TabContent(
            tab: tab,
            config: config,
            maraudesCompleted: maraudesCompleted,
            onUpdate: onUpdate,
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              Icon(DsIcons.info, size: 14, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  'Débloque plus d\'items en participant aux maraudes',
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

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: DsMotion.standard,
        curve: DsMotion.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: DsRadius.smRadius,
          boxShadow: selected ? DsShadows.ambient(colors.textPrimary) : const [],
        ),
        child: Text(
          label,
          style: DsTypography.meta.copyWith(
            color: selected ? colors.textPrimary : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.config,
    required this.maraudesCompleted,
    required this.onUpdate,
  });

  final _CustomizerTab tab;
  final AvatarConfig config;
  final int maraudesCompleted;
  final void Function(AvatarConfig Function(AvatarConfig current)) onUpdate;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case _CustomizerTab.body:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemGrid(
              category: AvatarCategory.body,
              items: AvatarCatalogue.bodyTypes,
              selectedId: '${config.bodyType}',
              maraudesCompleted: maraudesCompleted,
              onSelect: (id) => onUpdate(
                (c) => c.copyWith(bodyType: int.parse(id!)),
              ),
            ),
            const SizedBox(height: DsSpacing.lg),
            _ColorRow(
              label: 'Teint de peau',
              colors: AvatarCatalogue.skinTones,
              selected: config.skinTone,
              onSelect: (hex) => onUpdate((c) => c.copyWith(skinTone: hex)),
            ),
          ],
        );
      case _CustomizerTab.hair:
        return _ItemGrid(
          category: AvatarCategory.hair,
          items: AvatarCatalogue.hairStyles,
          selectedId: config.hairStyle,
          maraudesCompleted: maraudesCompleted,
          onSelect: (id) => onUpdate((c) => c.copyWith(hairStyle: id)),
        );
      case _CustomizerTab.top:
        return _ItemGrid(
          category: AvatarCategory.top,
          items: AvatarCatalogue.topStyles,
          selectedId: config.topStyle,
          maraudesCompleted: maraudesCompleted,
          onSelect: (id) => onUpdate((c) => c.copyWith(topStyle: id)),
        );
      case _CustomizerTab.bottom:
        return _ItemGrid(
          category: AvatarCategory.bottom,
          items: AvatarCatalogue.bottomStyles,
          selectedId: config.bottomStyle,
          maraudesCompleted: maraudesCompleted,
          onSelect: (id) => onUpdate((c) => c.copyWith(bottomStyle: id)),
        );
      case _CustomizerTab.shoes:
        return _ItemGrid(
          category: AvatarCategory.shoes,
          items: AvatarCatalogue.shoesStyles,
          selectedId: config.shoesStyle,
          maraudesCompleted: maraudesCompleted,
          onSelect: (id) => onUpdate((c) => c.copyWith(shoesStyle: id)),
        );
      case _CustomizerTab.held:
        return _ItemGrid(
          category: AvatarCategory.held,
          items: AvatarCatalogue.heldObjects,
          selectedId: config.heldObject,
          maraudesCompleted: maraudesCompleted,
          onSelect: (id) => onUpdate((c) => c.copyWith(heldObject: id)),
        );
      case _CustomizerTab.accessories:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tête', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              category: AvatarCategory.head,
              items: AvatarCatalogue.headAccessories,
              selectedId: config.headAccessory,
              maraudesCompleted: maraudesCompleted,
              clearable: true,
              onSelect: (id) => onUpdate((c) => c.copyWith(headAccessory: id)),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text('Dos', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              category: AvatarCategory.back,
              items: AvatarCatalogue.backItems,
              selectedId: config.backItem,
              maraudesCompleted: maraudesCompleted,
              clearable: true,
              onSelect: (id) => onUpdate((c) => c.copyWith(backItem: id)),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text('Bijoux', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              category: AvatarCategory.jewelry,
              items: AvatarCatalogue.jewelryItems,
              selectedId: config.jewelry,
              maraudesCompleted: maraudesCompleted,
              clearable: true,
              onSelect: (id) => onUpdate((c) => c.copyWith(jewelry: id)),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text('Tatouage', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              category: AvatarCategory.tattoo,
              items: AvatarCatalogue.tattoos,
              selectedId: config.tattoo,
              maraudesCompleted: maraudesCompleted,
              clearable: true,
              onSelect: (id) => onUpdate((c) => c.copyWith(tattoo: id)),
            ),
            const SizedBox(height: DsSpacing.lg),
            Text('Animal de compagnie', style: DsTypography.meta.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: DsSpacing.sm),
            _ItemGrid(
              category: AvatarCategory.pet,
              items: AvatarCatalogue.pets,
              selectedId: config.pet,
              maraudesCompleted: maraudesCompleted,
              clearable: true,
              onSelect: (id) => onUpdate((c) => c.copyWith(pet: id)),
            ),
          ],
        );
      case _CustomizerTab.colors:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ColorRow(
              label: 'Haut',
              colors: AvatarCatalogue.colorPresets,
              selected: config.topColor,
              onSelect: (hex) => onUpdate((c) => c.copyWith(topColor: hex)),
            ),
            const SizedBox(height: DsSpacing.lg),
            _ColorRow(
              label: 'Bas',
              colors: AvatarCatalogue.colorPresets,
              selected: config.bottomColor,
              onSelect: (hex) => onUpdate((c) => c.copyWith(bottomColor: hex)),
            ),
            const SizedBox(height: DsSpacing.lg),
            _ColorRow(
              label: 'Cheveux',
              colors: AvatarCatalogue.colorPresets,
              selected: config.hairColor,
              onSelect: (hex) => onUpdate((c) => c.copyWith(hairColor: hex)),
            ),
          ],
        );
    }
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.category,
    required this.items,
    required this.selectedId,
    required this.maraudesCompleted,
    required this.onSelect,
    this.clearable = false,
  });

  final AvatarCategory category;
  final List<AvatarItem> items;
  final String? selectedId;
  final int maraudesCompleted;
  final ValueChanged<String?> onSelect;
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.sm,
      runSpacing: DsSpacing.sm,
      children: [
        if (clearable)
          _ItemCell(
            icon: DsIcons.close,
            label: 'Aucun',
            selected: selectedId == null,
            locked: false,
            onTap: () => onSelect(null),
          ),
        for (final item in items)
          _ItemCell(
            icon: avatarItemIcon(category, item.id),
            spritePath: item.spritePath,
            label: item.label,
            selected: item.id == selectedId,
            locked: !item.isUnlockedFor(maraudesCompleted: maraudesCompleted),
            lockedTooltip: item.lockedTooltip,
            onTap: () => onSelect(item.id),
          ),
      ],
    );
  }
}

class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.icon,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.lockedTooltip,
    this.spritePath,
  });

  final IconData icon;
  final String? spritePath;
  final String label;
  final bool selected;
  final bool locked;
  final String? lockedTooltip;
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
            if (spritePath != null)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(spritePath!, fit: BoxFit.contain),
              )
            else
              Icon(icon, size: 22, color: colors.textPrimary),
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
      message: locked ? (lockedTooltip ?? 'Verrouillé') : label,
      child: GestureDetector(onTap: locked ? null : onTap, child: cell),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<String> colors;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final dsColors = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DsTypography.meta.copyWith(
            color: dsColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        Wrap(
          spacing: DsSpacing.sm,
          runSpacing: DsSpacing.sm,
          children: [
            for (final hex in colors)
              _ColorSwatch(
                hex: hex,
                selected: hex.toUpperCase() == selected.toUpperCase(),
                onTap: () => onSelect(hex),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final value = int.parse(hex.replaceFirst('#', 'FF'), radix: 16);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 2 : DsBorders.hairline,
          ),
        ),
      ),
    );
  }
}
