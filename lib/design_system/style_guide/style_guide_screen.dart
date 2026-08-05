import 'package:flutter/material.dart';

import '../components/buttons/ds_ghost_button.dart';
import '../components/buttons/ds_primary_button.dart';
import '../components/buttons/ds_secondary_button.dart';
import '../components/calendar/ds_calendar_cell.dart';
import '../components/domain_showcase/ds_invitation_card.dart';
import '../components/domain_showcase/ds_maraude_card.dart';
import '../components/domain_showcase/ds_organisation_card.dart';
import '../components/domain_showcase/ds_volunteer_card.dart';
import '../components/feedback/ds_bottom_sheet.dart';
import '../components/feedback/ds_dialog.dart';
import '../components/feedback/ds_empty_state.dart';
import '../components/feedback/ds_loading_state.dart';
import '../components/indicators/ds_avatar.dart';
import '../components/indicators/ds_badge.dart';
import '../components/indicators/ds_notification_badge.dart';
import '../components/indicators/ds_semantic_variant.dart';
import '../components/indicators/ds_status_chip.dart';
import '../components/inputs/ds_dropdown.dart';
import '../components/inputs/ds_filter_chip.dart';
import '../components/inputs/ds_search_bar.dart';
import '../components/inputs/ds_text_field.dart';
import '../components/navigation/ds_navigation_rail.dart';
import '../components/navigation/ds_section_header.dart';
import '../components/navigation/ds_top_bar.dart';
import '../components/surfaces/ds_card.dart';
import '../components/surfaces/ds_metric_card.dart';
import '../icons/ds_icons.dart';
import '../illustrations/ds_illustration.dart';
import '../mock/style_guide_mock_data.dart';
import '../tokens/ds_colors.dart';
import '../tokens/ds_spacing.dart';
import '../tokens/ds_theme.dart';
import '../tokens/ds_tokens.dart';
import '../tokens/ds_typography.dart';

/// `/style-guide` — every design-system component in one place, with
/// mock data, so the new visual identity can be reviewed before any real
/// screen adopts it. Admin-only, absent from the navigation menu (see
/// `lib/core/router/app_router.dart`). Wraps its whole subtree in
/// `Theme(data: DsTheme.light, ...)`: it is the *only* place in the app
/// that renders with the new theme — every other screen keeps using
/// `AppTheme.light` untouched.
class StyleGuideScreen extends StatelessWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(data: DsTheme.light, child: const _StyleGuideBody());
  }
}

class _StyleGuideBody extends StatefulWidget {
  const _StyleGuideBody();

  @override
  State<_StyleGuideBody> createState() => _StyleGuideBodyState();
}

class _StyleGuideBodyState extends State<_StyleGuideBody> {
  bool _filterSelected = true;
  int _navIndex = 0;
  String? _dropdownValue;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: DsTopBar(
        title: 'Design system — Club Sandwich',
        actions: [
          DsNotificationBadge(
            count: 3,
            child: Icon(DsIcons.bell, color: colors.textSecondary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DsSpacing.xxl),
        children: [
          _section(
            context,
            title: 'Couleurs',
            subtitle:
                'Primary/Secondary sont les couleurs réelles de la marque, '
                'échantillonnées sur le logo.',
            child: _ColorPalette(colors: colors),
          ),
          _section(
            context,
            title: 'Typographie',
            subtitle: 'Inter — H1 à Caption.',
            child: const _TypographyShowcase(),
          ),
          _section(
            context,
            title: 'Boutons',
            subtitle:
                'Primary / Secondary / Ghost — normal, chargement, désactivé.',
            child: const _ButtonsShowcase(),
          ),
          _section(
            context,
            title: 'Cartes & indicateurs',
            child: _CardsAndIndicatorsShowcase(colors: colors),
          ),
          _section(
            context,
            title: 'Formulaires',
            child: _FormsShowcase(
              filterSelected: _filterSelected,
              onFilterChanged: (v) => setState(() => _filterSelected = v),
              dropdownValue: _dropdownValue,
              onDropdownChanged: (v) => setState(() => _dropdownValue = v),
              textController: _textController,
            ),
          ),
          _section(
            context,
            title: 'Navigation',
            child: _NavigationShowcase(
              navIndex: _navIndex,
              onNavSelected: (i) => setState(() => _navIndex = i),
            ),
          ),
          _section(
            context,
            title: 'Feedback',
            child: const _FeedbackShowcase(),
          ),
          _section(
            context,
            title: 'Cartes métier',
            subtitle:
                'Données fictives — n\'utilisent ni providers Riverpod ni Supabase.',
            child: const _DomainCardsShowcase(),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: DsSpacing.xl),
          child,
        ],
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({required this.colors});

  final DsColorTokens colors;

  @override
  Widget build(BuildContext context) {
    final swatches = <(String, Color)>[
      ('Primary', colors.primary),
      ('Secondary', colors.secondary),
      ('Canvas', colors.canvas),
      ('Surface', colors.surface),
      ('Border', colors.border),
      ('Success', colors.success),
      ('Warning', colors.warning),
      ('Error', colors.error),
      ('Info', colors.info),
    ];
    return Wrap(
      spacing: DsSpacing.md,
      runSpacing: DsSpacing.md,
      children: [
        for (final (label, color) in swatches)
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                ),
                const SizedBox(height: DsSpacing.xs),
                Text(
                  label,
                  style: DsTypography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypographyShowcase extends StatelessWidget {
  const _TypographyShowcase();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'H1 — Titre de page',
          style: DsTypography.h1.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          'H2 — Titre de section',
          style: DsTypography.h2.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          'H3 — Titre de carte',
          style: DsTypography.h3.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          'Body — texte courant, pour les paragraphes et le contenu principal.',
          style: DsTypography.body.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: DsSpacing.sm),
        Text(
          'CAPTION — LIBELLÉS, MÉTADONNÉES',
          style: DsTypography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _ButtonsShowcase extends StatelessWidget {
  const _ButtonsShowcase();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.lg,
      runSpacing: DsSpacing.lg,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DsPrimaryButton(
          label: 'Primary',
          icon: DsIcons.check,
          onPressed: () {},
        ),
        const DsPrimaryButton(
          label: 'Chargement',
          isLoading: true,
          onPressed: null,
        ),
        const DsPrimaryButton(label: 'Désactivé', onPressed: null),
        DsSecondaryButton(
          label: 'Secondary',
          icon: DsIcons.filter,
          onPressed: () {},
        ),
        const DsSecondaryButton(label: 'Désactivé', onPressed: null),
        DsGhostButton(
          label: 'Ghost',
          icon: DsIcons.moreHorizontal,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _CardsAndIndicatorsShowcase extends StatelessWidget {
  const _CardsAndIndicatorsShowcase({required this.colors});

  final DsColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            SizedBox(
              width: 220,
              child: DsMetricCard(
                label: 'Maraudes réalisées',
                value: '128',
                icon: DsIcons.check,
                delta: '+12%',
                trend: DsMetricTrend.up,
              ),
            ),
            SizedBox(
              width: 220,
              child: DsMetricCard(
                label: 'Désistements',
                value: '4',
                icon: DsIcons.circleAlert,
                delta: '-2',
                trend: DsMetricTrend.down,
              ),
            ),
            SizedBox(
              width: 220,
              child: DsCard(
                child: Text(
                  'Une DsCard simple, pour tout contenu libre.',
                  style: DsTypography.body.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.sm,
          runSpacing: DsSpacing.sm,
          children: const [
            DsBadge(label: 'Bénévole', variant: DsSemanticVariant.primary),
            DsBadge(label: 'Tourneur', variant: DsSemanticVariant.secondary),
            DsBadge(label: 'Admin', variant: DsSemanticVariant.neutral),
          ],
        ),
        const SizedBox(height: DsSpacing.sm),
        Wrap(
          spacing: DsSpacing.sm,
          runSpacing: DsSpacing.sm,
          children: const [
            DsStatusChip(label: 'Brouillon', status: DsChipStatus.draft),
            DsStatusChip(label: 'Ouverte', status: DsChipStatus.active),
            DsStatusChip(label: 'À confirmer', status: DsChipStatus.pending),
            DsStatusChip(label: 'Terminée', status: DsChipStatus.completed),
            DsStatusChip(label: 'Annulée', status: DsChipStatus.cancelled),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Row(
          children: [
            const DsAvatar(initials: 'AB', size: DsAvatarSize.sm),
            const SizedBox(width: DsSpacing.sm),
            const DsAvatar(initials: 'CD', size: DsAvatarSize.md),
            const SizedBox(width: DsSpacing.sm),
            const DsAvatar(initials: 'EF', size: DsAvatarSize.lg),
            const SizedBox(width: DsSpacing.sm),
            const DsAvatar(initials: 'GH', size: DsAvatarSize.lg, square: true),
            const SizedBox(width: DsSpacing.xl),
            DsNotificationBadge(
              count: 5,
              child: Icon(DsIcons.bell, color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormsShowcase extends StatelessWidget {
  const _FormsShowcase({
    required this.filterSelected,
    required this.onFilterChanged,
    required this.dropdownValue,
    required this.onDropdownChanged,
    required this.textController,
  });

  final bool filterSelected;
  final ValueChanged<bool> onFilterChanged;
  final String? dropdownValue;
  final ValueChanged<String> onDropdownChanged;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DsSpacing.xl,
          runSpacing: DsSpacing.lg,
          children: [
            SizedBox(
              width: 280,
              child: DsTextField(
                label: 'Nom',
                hintText: 'Camille Rousseau',
                controller: textController,
              ),
            ),
            const SizedBox(
              width: 280,
              child: DsTextField(
                label: 'E-mail',
                hintText: 'nom@example.org',
                errorText: 'Adresse e-mail invalide',
              ),
            ),
            const SizedBox(width: 280, child: DsSearchBar()),
            SizedBox(
              width: 220,
              child: DsDropdown<String>(
                label: 'Rôle',
                value: dropdownValue,
                onChanged: onDropdownChanged,
                items: const [
                  DsDropdownItem(
                    value: 'volunteer',
                    label: 'Bénévole',
                    icon: DsIcons.user,
                  ),
                  DsDropdownItem(
                    value: 'promoter',
                    label: 'Tourneur',
                    icon: DsIcons.building,
                  ),
                  DsDropdownItem(
                    value: 'admin',
                    label: 'Admin',
                    icon: DsIcons.settings,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.sm,
          children: [
            DsFilterChip(
              label: 'Ouvertes',
              selected: filterSelected,
              onSelected: onFilterChanged,
              count: 4,
            ),
            DsFilterChip(
              label: 'Terminées',
              selected: !filterSelected,
              onSelected: (v) => onFilterChanged(!v),
              count: 12,
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationShowcase extends StatelessWidget {
  const _NavigationShowcase({
    required this.navIndex,
    required this.onNavSelected,
  });

  final int navIndex;
  final ValueChanged<int> onNavSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DsNavigationRail — vitrine de style uniquement, ne remplace pas '
          'la navigation réelle de AppShell.',
          style: DsTypography.caption.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DsSpacing.md),
        Container(
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: DsNavigationRail(
            selectedIndex: navIndex,
            onSelected: onNavSelected,
            items: const [
              DsNavigationRailItem(
                label: 'Tableau de bord',
                icon: DsIcons.home,
              ),
              DsNavigationRailItem(label: 'Maraudes', icon: DsIcons.heart),
              DsNavigationRailItem(label: 'Bénévoles', icon: DsIcons.users),
              DsNavigationRailItem(
                label: 'Organisations',
                icon: DsIcons.building,
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpacing.xl),
        Text(
          'DsCalendarCell',
          style: DsTypography.caption.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        Row(
          children: const [
            DsCalendarCell(day: 3),
            SizedBox(width: DsSpacing.sm),
            DsCalendarCell(day: 12, state: DsCalendarCellState.today),
            SizedBox(width: DsSpacing.sm),
            DsCalendarCell(day: 18, state: DsCalendarCellState.selected),
            SizedBox(width: DsSpacing.sm),
            DsCalendarCell(day: 21, state: DsCalendarCellState.hasEvent),
            SizedBox(width: DsSpacing.sm),
            DsCalendarCell(day: 27, state: DsCalendarCellState.weekend),
            SizedBox(width: DsSpacing.sm),
            DsCalendarCell(day: 30, state: DsCalendarCellState.disabled),
          ],
        ),
      ],
    );
  }
}

class _FeedbackShowcase extends StatelessWidget {
  const _FeedbackShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            SizedBox(
              width: 260,
              height: 260,
              child: DsCard(
                child: const DsEmptyState(
                  illustration: DsEmptyBoxIllustration(),
                  title: 'Aucune maraude',
                  message: 'Il n\'y a rien à afficher pour le moment.',
                ),
              ),
            ),
            SizedBox(
              width: 260,
              height: 260,
              child: DsCard(
                child: const DsEmptyState(
                  illustration: DsSearchIllustration(),
                  title: 'Aucun résultat',
                  message: 'Essayez avec d\'autres filtres.',
                ),
              ),
            ),
            SizedBox(
              width: 260,
              height: 260,
              child: DsCard(
                child: const DsEmptyState(
                  illustration: DsAllDoneIllustration(),
                  title: 'Tout est à jour',
                  message: 'Rien ne nécessite votre attention.',
                ),
              ),
            ),
            SizedBox(
              width: 260,
              height: 260,
              child: DsCard(
                child: const DsLoadingState(label: 'Chargement des maraudes'),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.md,
          children: [
            DsSecondaryButton(
              label: 'Ouvrir un dialogue',
              onPressed: () => showDsDialog(
                context: context,
                title: 'Supprimer la maraude ?',
                content: const Text(
                  'Cette action est définitive et supprimera les candidatures, '
                  'la collecte et le bilan associés.',
                ),
                actions: [
                  DsGhostButton(
                    label: 'Annuler',
                    onPressed: () => Navigator.pop(context),
                  ),
                  DsPrimaryButton(
                    label: 'Supprimer',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            DsSecondaryButton(
              label: 'Ouvrir une feuille',
              onPressed: () => showDsBottomSheet(
                context: context,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrer les maraudes',
                      style: DsTypography.h3.copyWith(
                        color: Theme.of(
                          context,
                        ).extension<DsTokens>()!.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: DsSpacing.md),
                    const DsFilterChip(
                      label: 'Ouvertes',
                      selected: true,
                      onSelected: _noop,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static void _noop(bool _) {}
}

class _DomainCardsShowcase extends StatelessWidget {
  const _DomainCardsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            for (final data in dsMockMaraudes)
              SizedBox(width: 300, child: DsMaraudeCard(data: data)),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            for (final data in dsMockInvitations)
              SizedBox(
                width: 340,
                child: DsInvitationCard(data: data, onResend: () {}),
              ),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            for (final data in dsMockVolunteers)
              SizedBox(width: 300, child: DsVolunteerCard(data: data)),
          ],
        ),
        const SizedBox(height: DsSpacing.xl),
        Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            for (final data in dsMockOrganisations)
              SizedBox(width: 300, child: DsOrganisationCard(data: data)),
          ],
        ),
      ],
    );
  }
}
