import 'dart:async';

import 'package:club_sandwich/features/collections/data/maraude_collection_providers.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/collections/presentation/maraude_collection_form_dialog.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/maraude_chat_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_message.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_report.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_report_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_operational_report_card.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_role_mission_sheet.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_profile.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteer_documents_panel.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class ConcertDetailScreen extends ConsumerWidget {
  const ConcertDetailScreen({required this.concertId, super.key});

  final String concertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concert = ref.watch(concertDetailsProvider(concertId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: concert.when(
        loading: () => const AppLoadingState(label: 'Chargement de la maraude'),
        error: (error, stackTrace) => _DetailError(
          onRetry: () => ref.invalidate(concertDetailsProvider(concertId)),
        ),
        data: (value) {
          if (value == null) return const _ConcertNotFound();
          return _ConcertDetails(concert: value);
        },
      ),
    );
  }
}

enum _MaraudeWorkspace {
  summary('Synthèse', Icons.dashboard_outlined),
  team('Équipe', Icons.groups_outlined),
  operations('Opérations', Icons.local_shipping_outlined),
  attendance('Présences et crédits', Icons.fact_check_outlined),
  report('Bilan', Icons.summarize_outlined),
  discussion('Discussion', Icons.chat_bubble_outline);

  const _MaraudeWorkspace(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _ConcertDetails extends ConsumerStatefulWidget {
  const _ConcertDetails({required this.concert});

  final Concert concert;

  @override
  ConsumerState<_ConcertDetails> createState() => _ConcertDetailsState();
}

class _ConcertDetailsState extends ConsumerState<_ConcertDetails> {
  _MaraudeWorkspace _selectedWorkspace = _MaraudeWorkspace.summary;

  Concert get concert => widget.concert;

  @override
  Widget build(BuildContext context) {
    final volunteerSection = ref.watch(
      concertVolunteerSectionProvider(concert.id),
    );
    final currentAccount = ref.watch(currentUserContextProvider).value;
    final loadedVolunteerData = volunteerSection.value;
    final volunteerData =
        currentAccount == null ||
            (loadedVolunteerData?.currentUserId == currentAccount.profileId &&
                loadedVolunteerData?.activeRole == currentAccount.role)
        ? loadedVolunteerData
        : null;
    final canManageMaraude = volunteerData?.isAdmin ?? false;
    final canManageConcert = volunteerData?.canManageConcert ?? false;
    final ownApplication = volunteerData?.ownApplication;
    final isSelectedVolunteer =
        ownApplication?.status == ConcertVolunteerStatus.selected &&
        ownApplication?.confirmationStatus ==
            VolunteerConfirmationStatus.confirmed;
    final canEditOperationalReport =
        canManageMaraude ||
        (isSelectedVolunteer &&
            ownApplication?.teamRole == MaraudeRole.teamLeader &&
            concert.maraudeStatus == MaraudeStatus.inProgress);
    final canCompleteMaraude =
        !canManageMaraude &&
        isSelectedVolunteer &&
        ownApplication?.teamRole == MaraudeRole.teamLeader;
    final canEditOperationalPhoto =
        !canEditOperationalReport &&
        isSelectedVolunteer &&
        ownApplication?.teamRole == MaraudeRole.communication;
    final canViewReport =
        concert.maraudeStatus == MaraudeStatus.completed &&
        volunteerData != null &&
        (volunteerData.isAdmin ||
            (volunteerData.activeRole == AppUserRole.promoter &&
                canManageConcert) ||
            (ownApplication?.status == ConcertVolunteerStatus.selected &&
                ownApplication?.confirmationStatus ==
                    VolunteerConfirmationStatus.confirmed));
    final isVolunteer = volunteerData?.activeRole == AppUserRole.volunteer;
    final workspaces = <_MaraudeWorkspace>[
      _MaraudeWorkspace.summary,
      _MaraudeWorkspace.team,
      _MaraudeWorkspace.operations,
      if (canManageMaraude && concert.maraudeStatus == MaraudeStatus.completed)
        _MaraudeWorkspace.attendance,
      if (canViewReport) _MaraudeWorkspace.report,
      if (volunteerData?.isAdmin == true ||
          (ownApplication?.status == ConcertVolunteerStatus.selected &&
              ownApplication?.confirmationStatus ==
                  VolunteerConfirmationStatus.confirmed))
        _MaraudeWorkspace.discussion,
    ];
    final selectedWorkspace = workspaces.contains(_selectedWorkspace)
        ? _selectedWorkspace
        : _MaraudeWorkspace.summary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final availableWidth =
            constraints.maxWidth.clamp(0, 1200).toDouble() -
            horizontalPadding * 2;
        const spacing = 16.0;
        final sectionWidth = availableWidth >= 800
            ? (availableWidth - spacing) / 2
            : availableWidth;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailHeader(
                    concert: concert,
                    onEdit: canManageConcert ? () => _edit(context, ref) : null,
                    onDelete: canManageMaraude
                        ? () => _delete(context, ref)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _MaraudeProgress(
                    concert: concert,
                    ownApplication: ownApplication,
                    isVolunteer: isVolunteer,
                  ),
                  const SizedBox(height: 16),
                  _NextActionCard(
                    concert: concert,
                    ownApplication: ownApplication,
                    isAdmin: canManageMaraude,
                    isVolunteer: isVolunteer,
                    onOpen: (workspace) =>
                        setState(() => _selectedWorkspace = workspace),
                    onOpenMission: (role) =>
                        showMaraudeRoleMissionSheet(context, role),
                  ),
                  if (isVolunteer &&
                      ownApplication?.confirmationStatus ==
                          VolunteerConfirmationStatus.confirmed &&
                      ownApplication?.teamRole != null) ...[
                    const SizedBox(height: 16),
                    MaraudeRoleMissionCard(role: ownApplication!.teamRole!),
                  ],
                  const SizedBox(height: 16),
                  _WorkspaceNavigation(
                    workspaces: workspaces,
                    selected: selectedWorkspace,
                    onSelected: (workspace) =>
                        setState(() => _selectedWorkspace = workspace),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      if (selectedWorkspace == _MaraudeWorkspace.summary) ...[
                        SizedBox(
                          width: sectionWidth,
                          child: _InformationSection(concert: concert),
                        ),
                        SizedBox(
                          width: sectionWidth,
                          child: _VenueSection(concert: concert),
                        ),
                        SizedBox(
                          width: sectionWidth,
                          child: _ContactsSection(concert: concert),
                        ),
                        if (isVolunteer &&
                            ownApplication?.status !=
                                ConcertVolunteerStatus.selected)
                          SizedBox(
                            width: availableWidth,
                            child: _VolunteersSection(
                              concertId: concert.id,
                              maraudeStatus: concert.maraudeStatus,
                            ),
                          ),
                      ],
                      if (selectedWorkspace == _MaraudeWorkspace.team)
                        SizedBox(
                          width: availableWidth,
                          child: _VolunteersSection(
                            concertId: concert.id,
                            maraudeStatus: concert.maraudeStatus,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.team)
                        SizedBox(
                          width: sectionWidth,
                          child: const _PlaceholderSection(
                            title: 'Documents',
                            icon: Icons.folder_outlined,
                            message: 'Aucun document disponible.',
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.operations)
                        SizedBox(
                          width: sectionWidth,
                          child: _MaraudeSection(
                            concert: concert,
                            canManage: canManageMaraude,
                            canComplete: canCompleteMaraude,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.attendance &&
                          canManageMaraude &&
                          concert.maraudeStatus == MaraudeStatus.completed)
                        SizedBox(
                          width: availableWidth,
                          child: _AttendanceSection(
                            concertId: concert.id,
                            maraudeStatus: concert.maraudeStatus,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.operations)
                        SizedBox(
                          width: sectionWidth,
                          child: _CollectionsSection(
                            concert: concert,
                            canEdit: canEditOperationalReport,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.operations &&
                          (concert.maraudeStatus == MaraudeStatus.inProgress ||
                              concert.maraudeStatus ==
                                  MaraudeStatus.completed ||
                              concert.operationalReport != null))
                        SizedBox(
                          width: sectionWidth,
                          child: MaraudeOperationalReportCard(
                            concert: concert,
                            canEdit: canEditOperationalReport,
                            canEditPhoto: canEditOperationalPhoto,
                            canManagePhotoGallery:
                                canManageMaraude || canEditOperationalPhoto,
                            currentUserId: volunteerData?.currentUserId,
                            isAdmin: canManageMaraude,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.report &&
                          canViewReport)
                        SizedBox(
                          width: availableWidth,
                          child: _MaraudeReportSection(
                            concert: concert,
                            volunteerCounts: volunteerData.counts,
                            canEditComment: volunteerData.isAdmin,
                            applications: volunteerData.applications,
                            currentUserId: volunteerData.currentUserId,
                            isAdmin: volunteerData.isAdmin,
                          ),
                        ),
                      if (selectedWorkspace == _MaraudeWorkspace.discussion)
                        SizedBox(
                          width: availableWidth,
                          child: _MaraudeChatSection(concertId: concert.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertForm(
        initialConcert: concert,
        onSubmit: (draft) => ref
            .read(concertRepositoryProvider)
            .updateConcert(concert.id, draft),
      ),
    );
    if (updated != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(concertDetailsProvider(concert.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Maraude modifiée.')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await deleteConcertWithConfirmation(context, ref, concert);
    if (deleted && context.mounted) context.go('/maraudes');
  }
}

class _WorkspaceNavigation extends StatelessWidget {
  const _WorkspaceNavigation({
    required this.workspaces,
    required this.selected,
    required this.onSelected,
  });

  final List<_MaraudeWorkspace> workspaces;
  final _MaraudeWorkspace selected;
  final ValueChanged<_MaraudeWorkspace> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sections de la maraude',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final workspace in workspaces)
            ChoiceChip(
              key: ValueKey('maraude-workspace-${workspace.name}'),
              avatar: Icon(workspace.icon, size: 18),
              label: Text(workspace.label),
              selected: selected == workspace,
              onSelected: (_) => onSelected(workspace),
            ),
        ],
      ),
    );
  }
}

class _MaraudeProgress extends StatelessWidget {
  const _MaraudeProgress({
    required this.concert,
    required this.ownApplication,
    required this.isVolunteer,
  });

  final Concert concert;
  final ConcertVolunteerApplication? ownApplication;
  final bool isVolunteer;

  static const _steps = [
    'Candidature',
    'Confirmation',
    'Préparation',
    'En cours',
    'Bilan',
    'Archivée',
  ];

  int get _currentStep {
    if (concert.maraudeStatus == MaraudeStatus.completed ||
        concert.maraudeStatus == MaraudeStatus.cancelled) {
      return 5;
    }
    if (concert.maraudeStatus == MaraudeStatus.inProgress) return 3;
    if (!isVolunteer) {
      return concert.maraudeStatus == MaraudeStatus.teamReady ? 2 : 0;
    }
    if (ownApplication?.confirmationStatus ==
        VolunteerConfirmationStatus.confirmed) {
      return 2;
    }
    if (ownApplication?.status == ConcertVolunteerStatus.selected) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;
    final colors = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Avancement',
      icon: Icons.route_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Row(
              children: [
                CircularProgressIndicator(value: (current + 1) / _steps.length),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Étape ${current + 1} sur ${_steps.length}'),
                      Text(
                        _steps[current],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < _steps.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        index < current
                            ? Icons.check_circle
                            : index == current
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: index <= current
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _steps[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: index == current
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: index <= current
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Divider(
                      color: index < current
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.concert,
    required this.ownApplication,
    required this.isAdmin,
    required this.isVolunteer,
    required this.onOpen,
    required this.onOpenMission,
  });

  final Concert concert;
  final ConcertVolunteerApplication? ownApplication;
  final bool isAdmin;
  final bool isVolunteer;
  final ValueChanged<_MaraudeWorkspace> onOpen;
  final ValueChanged<MaraudeRole> onOpenMission;

  @override
  Widget build(BuildContext context) {
    final action = _action;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prochaine action',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.onPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  action.$1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                ),
                if (action.$2 != null) ...[
                  const SizedBox(height: 4),
                  Text(action.$2!, style: TextStyle(color: colors.onPrimary)),
                ],
              ],
            );
            final button = FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.onPrimary,
                foregroundColor: colors.primary,
              ),
              onPressed: () {
                final missionRole = action.$5;
                if (missionRole != null) {
                  onOpenMission(missionRole);
                } else {
                  onOpen(action.$3);
                }
              },
              child: Text(action.$4),
            );
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.bolt_outlined, color: colors.onPrimary),
                      const SizedBox(width: 12),
                      Expanded(child: description),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: button),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_outlined, color: colors.onPrimary),
                const SizedBox(width: 12),
                Expanded(child: description),
                const SizedBox(width: 12),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  (String, String?, _MaraudeWorkspace, String, MaraudeRole?) get _action {
    if (!isAdmin && !isVolunteer) {
      if (concert.maraudeStatus == MaraudeStatus.inProgress) {
        return (
          'Suivre le déroulement de la maraude',
          'Consultez les informations opérationnelles disponibles.',
          _MaraudeWorkspace.operations,
          'Consulter',
          null,
        );
      }
      if (concert.maraudeStatus == MaraudeStatus.completed) {
        return (
          'Consulter la maraude terminée',
          'Retrouvez les informations générales de cette maraude.',
          _MaraudeWorkspace.summary,
          'Consulter',
          null,
        );
      }
      return (
        'Suivre la constitution de l’équipe',
        'Consultez les candidatures et l’équipe retenue.',
        _MaraudeWorkspace.team,
        'Voir l’équipe',
        null,
      );
    }
    if (concert.maraudeStatus == MaraudeStatus.completed) {
      if (isAdmin) {
        return (
          'Valider les présences et attribuer les crédits',
          'Les crédits ne sont créés qu’après votre validation.',
          _MaraudeWorkspace.attendance,
          'Vérifier',
          null,
        );
      }
      return (
        'Consulter le bilan de la maraude',
        'Votre crédit apparaîtra après validation par un administrateur.',
        _MaraudeWorkspace.report,
        'Voir le bilan',
        null,
      );
    }
    if (concert.maraudeStatus == MaraudeStatus.inProgress) {
      return (
        isAdmin
            ? 'Suivre la collecte et le déroulement'
            : 'Poursuivre la maraude',
        'Les informations non relevées resteront indiquées comme non renseignées.',
        _MaraudeWorkspace.operations,
        'Ouvrir',
        null,
      );
    }
    if (ownApplication?.status == ConcertVolunteerStatus.selected &&
        ownApplication?.confirmationStatus ==
            VolunteerConfirmationStatus.pending) {
      return (
        'Confirmer votre participation',
        ownApplication?.confirmationDueAt == null
            ? 'Consultez votre rôle et votre fiche de mission.'
            : 'Confirmation attendue avant le '
                  '${formatFrenchDateTime(ownApplication!.confirmationDueAt!)}.',
        _MaraudeWorkspace.team,
        'Confirmer',
        null,
      );
    }
    if (ownApplication?.status == ConcertVolunteerStatus.selected &&
        ownApplication?.confirmationStatus ==
            VolunteerConfirmationStatus.confirmed) {
      return switch (ownApplication?.teamRole) {
        MaraudeRole.teamLeader => (
          'Préparer le démarrage de la maraude',
          'Vous êtes chef d’équipe : vérifiez les informations utiles avant de démarrer.',
          _MaraudeWorkspace.operations,
          'Préparer',
          null,
        ),
        MaraudeRole.communication => (
          'Préparer votre mission de communication',
          'Votre participation est confirmée comme chargé.e de communication.',
          _MaraudeWorkspace.operations,
          'Voir ma mission',
          MaraudeRole.communication,
        ),
        MaraudeRole.logistics => (
          'Préparer votre mission de logistique',
          'Votre participation est confirmée comme chargé.e de logistique.',
          _MaraudeWorkspace.operations,
          'Voir ma mission',
          MaraudeRole.logistics,
        ),
        MaraudeRole.collectionDistribution => (
          'Préparer la collecte et la distribution',
          'Votre participation est confirmée pour la récolte et la distribution.',
          _MaraudeWorkspace.operations,
          'Voir ma mission',
          MaraudeRole.collectionDistribution,
        ),
        null => (
          'Votre participation est confirmée',
          'Votre rôle doit encore être précisé par l’équipe organisatrice.',
          _MaraudeWorkspace.team,
          'Consulter',
          null,
        ),
      };
    }
    if (isAdmin) {
      return (
        'Constituer et confirmer l’équipe',
        'Un chef d’équipe confirmé est obligatoire avant le démarrage.',
        _MaraudeWorkspace.team,
        'Gérer l’équipe',
        null,
      );
    }
    return (
      ownApplication == null
          ? 'Proposer votre participation'
          : 'Suivre votre candidature',
      ownApplication == null
          ? 'Consultez les informations puis proposez-vous dans l’espace équipe.'
          : 'Consultez l’état de votre candidature dans l’espace équipe.',
      _MaraudeWorkspace.team,
      'Consulter',
      null,
    );
  }
}

class _MaraudeSection extends ConsumerStatefulWidget {
  const _MaraudeSection({
    required this.concert,
    required this.canManage,
    required this.canComplete,
  });

  final Concert concert;
  final bool canManage;
  final bool canComplete;

  @override
  ConsumerState<_MaraudeSection> createState() => _MaraudeSectionState();
}

class _MaraudeSectionState extends ConsumerState<_MaraudeSection> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final concert = widget.concert;
    return _SectionCard(
      title: 'Maraude',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('État', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          _MaraudeStatusChip(status: concert.maraudeStatus),
          const Divider(height: 24),
          _DetailRow(
            label: 'Début',
            value: concert.actualStartAt == null
                ? '—'
                : formatFrenchDateTime(concert.actualStartAt!),
          ),
          _DetailRow(
            label: 'Fin',
            value: concert.actualEndAt == null
                ? '—'
                : formatFrenchDateTime(concert.actualEndAt!),
            showDivider: widget.canManage,
          ),
          if (widget.canManage &&
              concert.maraudeStatus != MaraudeStatus.completed &&
              concert.maraudeStatus != MaraudeStatus.cancelled) ...[
            DropdownButtonFormField<MaraudeStatus>(
              key: const ValueKey('maraude-status-selector'),
              initialValue: concert.maraudeStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modifier l’état'),
              items: [
                for (final status in MaraudeStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (status) {
                      if (status != null && status != concert.maraudeStatus) {
                        _setStatus(status);
                      }
                    },
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('correct-maraude-timing'),
              onPressed: _isSubmitting ? null : _correctTiming,
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('Corriger les horaires'),
            ),
          ],
          if (widget.canManage &&
              (concert.maraudeStatus == MaraudeStatus.completed ||
                  concert.maraudeStatus == MaraudeStatus.cancelled)) ...[
            const Text(
              'L’état est archivé et ne peut plus être modifié.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (concert.maraudeStatus == MaraudeStatus.cancelled &&
                concert.cancellationReason != null) ...[
              const SizedBox(height: 8),
              Text('Motif : ${concert.cancellationReason}'),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('correct-maraude-timing'),
              onPressed: _isSubmitting ? null : _correctTiming,
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('Corriger les horaires'),
            ),
          ],
          if ((widget.canManage || widget.canComplete) &&
              (concert.maraudeStatus == MaraudeStatus.open ||
                  concert.maraudeStatus == MaraudeStatus.teamReady)) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('start-maraude-team-leader'),
              onPressed: _isSubmitting
                  ? null
                  : () => _setStatus(MaraudeStatus.inProgress),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                widget.canManage
                    ? 'Démarrer à la place du chef'
                    : 'Démarrer la maraude',
              ),
            ),
          ],
          if ((widget.canManage || widget.canComplete) &&
              concert.maraudeStatus == MaraudeStatus.inProgress) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('complete-maraude-team-leader'),
              onPressed: _isSubmitting ? null : _complete,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                widget.canManage
                    ? 'Clôturer à la place du chef'
                    : 'Terminer la maraude',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la maraude ?'),
        content: const Text(
          'La maraude sera clôturée. Les présences devront ensuite être '
          'validées par un administrateur avant l’attribution des crédits. '
          'Si aucun compte rendu n’est enregistré, les quantités seront '
          'marquées comme non renseignées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _setStatus(MaraudeStatus.completed);
  }

  Future<void> _correctTiming() async {
    final correction = await showDialog<_MaraudeTimingCorrection>(
      context: context,
      builder: (context) => _MaraudeTimingDialog(
        startAt: widget.concert.actualStartAt,
        endAt: widget.concert.actualEndAt,
      ),
    );
    if (correction == null || !mounted) return;
    await _changeStatus(
      action: () => ref
          .read(concertRepositoryProvider)
          .correctMaraudeTiming(
            widget.concert.id,
            startAt: correction.startAt,
            endAt: correction.endAt,
          ),
      successMessage: 'Horaires corrigés.',
      errorMessage: 'Impossible de corriger les horaires.',
    );
  }

  Future<void> _setStatus(MaraudeStatus status) async {
    await _changeStatus(
      action: () => ref
          .read(concertRepositoryProvider)
          .setMaraudeStatus(widget.concert.id, status),
      successMessage: 'État de la maraude mis à jour.',
      errorMessage: 'Impossible de modifier l’état de la maraude.',
    );
  }

  Future<void> _changeStatus({
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      ref.invalidate(concertsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(error, errorMessage))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _AttendanceSection extends ConsumerStatefulWidget {
  const _AttendanceSection({
    required this.concertId,
    required this.maraudeStatus,
  });

  final String concertId;
  final MaraudeStatus maraudeStatus;

  @override
  ConsumerState<_AttendanceSection> createState() => _AttendanceSectionState();
}

class _AttendanceSectionState extends ConsumerState<_AttendanceSection> {
  final Set<String> _updatingMembers = {};
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(maraudeAttendanceProvider(widget.concertId));
    return _SectionCard(
      title: 'Présences et crédits',
      icon: Icons.fact_check_outlined,
      child: attendance.when(
        loading: () => const AppLoadingState(label: 'Chargement des présences'),
        error: (_, _) => AppErrorState(
          message: 'Impossible de charger les présences.',
          onRetry: () =>
              ref.invalidate(maraudeAttendanceProvider(widget.concertId)),
        ),
        data: _buildAttendance,
      ),
    );
  }

  Widget _buildAttendance(MaraudeAttendanceData data) {
    if (data.members.isEmpty) {
      return const Text('Aucun bénévole sélectionné.');
    }

    final validationAvailable =
        data.canValidate &&
        widget.maraudeStatus == MaraudeStatus.completed &&
        data.pendingCount == 0 &&
        !data.isValidated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Indiquez les bénévoles présents, puis confirmez pour attribuer '
          'leurs crédits d’invitation.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('${data.members.length} sélectionnés')),
            Chip(label: Text('Présents : ${data.presentCount}')),
            Chip(label: Text('Absents : ${data.absentCount}')),
            Chip(label: Text('En attente : ${data.pendingCount}')),
          ],
        ),
        const SizedBox(height: 12),
        for (final member in data.members) ...[
          _AttendanceMemberRow(
            member: member,
            isUpdating: _updatingMembers.contains(member.applicationId),
            onChanged: (status) => _setAttendance(member, status),
          ),
          if (member != data.members.last) const Divider(height: 24),
        ],
        if (data.canValidate) ...[
          const Divider(height: 28),
          if (data.isValidated)
            const Row(
              children: [
                Icon(Icons.verified_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Présences validées. Les crédits des bénévoles présents '
                    'ont été attribués.',
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              key: const ValueKey('validate-maraude-attendance'),
              onPressed: validationAvailable && !_isValidating
                  ? _validate
                  : null,
              icon: _isValidating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: const Text('Valider les présences et les crédits'),
            ),
          if (data.pendingCount > 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Renseignez toutes les présences avant de les valider.',
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _setAttendance(
    MaraudeAttendanceMember member,
    VolunteerAttendanceStatus status,
  ) async {
    setState(() => _updatingMembers.add(member.applicationId));
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .setAttendanceStatus(member.applicationId, status);
      _invalidate();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Présence mise à jour.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de modifier cette présence.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingMembers.remove(member.applicationId));
      }
    }
  }

  Future<void> _validate() async {
    setState(() => _isValidating = true);
    try {
      final awarded = await ref
          .read(concertVolunteerRepositoryProvider)
          .validateAttendance(widget.concertId);
      _invalidate();
      ref.invalidate(volunteerCreditCountProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$awarded crédit${awarded > 1 ? 's' : ''} attribué'
            '${awarded > 1 ? 's' : ''}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de valider les présences.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  void _invalidate() {
    ref.invalidate(maraudeAttendanceProvider(widget.concertId));
    ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
    ref.invalidate(concertDetailsProvider(widget.concertId));
    ref.invalidate(concertsProvider);
  }
}

class _AttendanceMemberRow extends StatelessWidget {
  const _AttendanceMemberRow({
    required this.member,
    required this.isUpdating,
    required this.onChanged,
  });

  final MaraudeAttendanceMember member;
  final bool isUpdating;
  final ValueChanged<VolunteerAttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final isConfirmed =
        member.confirmationStatus == VolunteerConfirmationStatus.confirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.displayName,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(member.teamRole?.label ?? 'Rôle non attribué'),
        const SizedBox(height: 10),
        DropdownButtonFormField<VolunteerAttendanceStatus>(
          key: ValueKey('attendance-${member.applicationId}'),
          initialValue: member.attendanceStatus,
          decoration: const InputDecoration(labelText: 'Présence'),
          items: [
            for (final status in VolunteerAttendanceStatus.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: !isConfirmed || isUpdating
              ? null
              : (status) {
                  if (status != null && status != member.attendanceStatus) {
                    onChanged(status);
                  }
                },
        ),
        if (!isConfirmed)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'La participation doit être confirmée avant de renseigner '
              'la présence.',
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Dernière modification'
            '${member.lastModifiedByName == null ? '' : ' par ${member.lastModifiedByName}'}'
            ' · ${formatFrenchDateTime(member.lastModifiedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _MaraudeTimingCorrection {
  const _MaraudeTimingCorrection({this.startAt, this.endAt});
  final DateTime? startAt;
  final DateTime? endAt;
}

class _MaraudeTimingDialog extends StatefulWidget {
  const _MaraudeTimingDialog({this.startAt, this.endAt});
  final DateTime? startAt;
  final DateTime? endAt;

  @override
  State<_MaraudeTimingDialog> createState() => _MaraudeTimingDialogState();
}

class _MaraudeTimingDialogState extends State<_MaraudeTimingDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _end;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: _timingValue(widget.startAt));
    _end = TextEditingController(text: _timingValue(widget.endAt));
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  DateTime? _parse(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized.replaceFirst(' ', 'T'));
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _parse(value) == null ? 'Format attendu : AAAA-MM-JJ HH:MM' : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Corriger les horaires'),
    content: Form(
      key: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const ValueKey('maraude-start-correction'),
            controller: _start,
            decoration: const InputDecoration(
              labelText: 'Début',
              hintText: 'AAAA-MM-JJ HH:MM',
            ),
            validator: _validate,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('maraude-end-correction'),
            controller: _end,
            decoration: const InputDecoration(
              labelText: 'Fin',
              hintText: 'AAAA-MM-JJ HH:MM',
            ),
            validator: (value) {
              final formatError = _validate(value);
              if (formatError != null) return formatError;
              final start = _parse(_start.text);
              final end = _parse(value ?? '');
              if (start != null && end != null && end.isBefore(start)) {
                return 'La fin doit être postérieure au début.';
              }
              return null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_key.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _MaraudeTimingCorrection(
              startAt: _parse(_start.text),
              endAt: _parse(_end.text),
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

String _timingValue(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _MaraudeStatusChip extends StatelessWidget {
  const _MaraudeStatusChip({required this.status});

  final MaraudeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      MaraudeStatus.draft => (Icons.edit_note_outlined, colors.outline),
      MaraudeStatus.open => (Icons.campaign_outlined, colors.secondary),
      MaraudeStatus.teamReady => (Icons.groups_outlined, colors.primary),
      MaraudeStatus.inProgress => (Icons.play_circle_outline, colors.primary),
      MaraudeStatus.completed => (Icons.check_circle_outline, colors.tertiary),
      MaraudeStatus.cancelled => (Icons.cancel_outlined, colors.error),
    };

    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(status.label),
      side: BorderSide(color: color),
    );
  }
}

class _CollectionsSection extends ConsumerStatefulWidget {
  const _CollectionsSection({required this.concert, required this.canEdit});

  final Concert concert;
  final bool canEdit;

  @override
  ConsumerState<_CollectionsSection> createState() =>
      _CollectionsSectionState();
}

class _CollectionsSectionState extends ConsumerState<_CollectionsSection> {
  final Set<String> _deletingIds = {};

  bool get _canEdit => widget.canEdit;

  @override
  Widget build(BuildContext context) {
    final collections = widget.concert.collections;
    final summary = MaraudeCollectionSummary.fromCollections(collections);

    return _SectionCard(
      title: 'Collecte',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _CollectionSummaryValue(
                label: 'Types renseignés',
                value: '${summary.lotCount} / 6',
              ),
              _CollectionSummaryValue(
                label: 'Poids total (kg)',
                value: formatCollectionNumber(summary.totalWeightKg),
              ),
              _CollectionSummaryValue(
                label: 'Nombre total de pièces',
                value: formatCollectionNumber(summary.totalPieces),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pensez à demander quels sont les régimes alimentaires ou '
                  'restrictions alimentaires concernés.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (_canEdit) ...[
            const SizedBox(height: 16),
            if (widget.concert.maraudeStatus == MaraudeStatus.completed) ...[
              const Text(
                'Maraude archivée : les changements sont enregistrés comme '
                'des corrections administratives.',
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: collections.length >= 6 ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(
                  collections.length >= 6
                      ? '6 types renseignés'
                      : widget.concert.maraudeStatus == MaraudeStatus.completed
                      ? 'Ajouter une correction de collecte'
                      : 'Ajouter un type de plat',
                ),
              ),
            ),
          ] else if (widget.concert.maraudeStatus ==
              MaraudeStatus.completed) ...[
            const SizedBox(height: 16),
            const Text('Cette collecte est archivée en lecture seule.'),
          ],
          const Divider(height: 28),
          if (collections.isEmpty)
            const Text('Aucun type de plat renseigné.')
          else
            for (final collection in collections)
              _CollectionItem(
                collection: collection,
                canEdit: _canEdit,
                isDeleting: _deletingIds.contains(collection.id),
                onEdit: () => _openForm(collection),
                onDelete: () => _delete(collection),
              ),
        ],
      ),
    );
  }

  Future<void> _openForm([MaraudeCollection? collection]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => MaraudeCollectionFormDialog(
        initialCollection: collection,
        onSubmit: (draft) async {
          final repository = ref.read(maraudeCollectionRepositoryProvider);
          if (collection == null) {
            await repository.create(widget.concert.id, draft);
          } else {
            await repository.update(collection.id, draft);
          }
        },
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(concertDetailsProvider(widget.concert.id));
    ref.invalidate(concertsProvider);
    ref.invalidate(maraudeOverviewProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(collection == null ? 'Lot ajouté.' : 'Lot modifié.'),
      ),
    );
  }

  Future<void> _delete(MaraudeCollection collection) async {
    final description = collection.description?.trim();
    final title = description?.isNotEmpty == true
        ? description!
        : collection.category.label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce lot ?'),
        content: Text(
          'Le lot « $title » et ses quantités seront '
          'retirés définitivement de la collecte et du bilan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(collection.id));
    try {
      await ref.read(maraudeCollectionRepositoryProvider).delete(collection.id);
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      ref.invalidate(concertsProvider);
      ref.invalidate(maraudeOverviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lot supprimé.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de supprimer ce lot.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(collection.id));
    }
  }
}

class _CollectionSummaryValue extends StatelessWidget {
  const _CollectionSummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CollectionItem extends StatelessWidget {
  const _CollectionItem({
    required this.collection,
    required this.canEdit,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final MaraudeCollection collection;
  final bool canEdit;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final description = collection.description?.trim();
    final comment = collection.comment?.trim();
    return Card(
      key: ValueKey('collection-${collection.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description?.isNotEmpty == true
                        ? description!
                        : collection.category.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${formatCollectionNumber(collection.quantity)} '
                        'plats',
                      ),
                      if (collection.averageWeightKg != null)
                        Text(
                          'Poids moyen : '
                          '${formatCollectionNumber(collection.averageWeightKg!)} kg',
                        ),
                      if (collection.weightKg != null)
                        Text(
                          'Poids total : '
                          '${formatCollectionNumber(collection.weightKg!)} kg',
                        ),
                    ],
                  ),
                  if (comment?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (isDeleting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (canEdit)
              PopupMenuButton<_CollectionAction>(
                tooltip: 'Actions du lot',
                onSelected: (action) {
                  switch (action) {
                    case _CollectionAction.edit:
                      onEdit();
                    case _CollectionAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _CollectionAction.edit,
                    child: Text('Modifier'),
                  ),
                  PopupMenuItem(
                    value: _CollectionAction.delete,
                    child: Text('Supprimer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _CollectionAction { edit, delete }

String _valueOrDash(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? '—' : trimmed;
}

class _MaraudeReportSection extends ConsumerStatefulWidget {
  const _MaraudeReportSection({
    required this.concert,
    required this.volunteerCounts,
    required this.canEditComment,
    required this.applications,
    required this.currentUserId,
    required this.isAdmin,
  });

  final Concert concert;
  final ConcertVolunteerCounts volunteerCounts;
  final bool canEditComment;
  final List<ConcertVolunteerApplication> applications;
  final String? currentUserId;
  final bool isAdmin;

  @override
  ConsumerState<_MaraudeReportSection> createState() =>
      _MaraudeReportSectionState();
}

class _MaraudeReportSectionState extends ConsumerState<_MaraudeReportSection> {
  bool _isExporting = false;

  MaraudeReport get _report =>
      MaraudeReport.fromConcert(widget.concert, widget.volunteerCounts);

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return _SectionCard(
      title: 'Bilan',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Général', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(label: 'Artiste', value: report.artist),
          _DetailRow(label: 'Salle', value: report.venueName ?? '—'),
          _DetailRow(label: 'Tourneur', value: report.promoterName ?? '—'),
          _DetailRow(
            label: 'Date',
            value: formatLongFrenchDate(report.concertDate),
          ),
          _DetailRow(
            label: 'Durée réelle',
            value: formatMaraudeDuration(report.actualDuration),
          ),
          if (report.cateringContactName != null &&
              report.cateringContactName!.trim().isNotEmpty)
            _DetailRow(
              label: 'Contact catering',
              value: report.cateringContactName!,
            ),
          const SizedBox(height: 8),
          Text('Équipe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Bénévoles sélectionnés',
            value: report.selectedCount.toString(),
          ),
          _DetailRow(label: 'Présents', value: report.presentCount.toString()),
          _DetailRow(
            label: 'Absents',
            value: report.absentCount.toString(),
            showDivider: widget.applications.isEmpty,
          ),
          if (widget.applications.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final application in widget.applications)
              _TeamRosterLine(application: application),
            const SizedBox(height: 12),
          ],
          Text('Collecte', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Nombre de lots',
            value: report.collectionSummary.lotCount.toString(),
          ),
          _DetailRow(
            label: 'Poids total',
            value:
                '${formatCollectionNumber(report.collectionSummary.totalWeightKg)} kg',
          ),
          _DetailRow(
            label: 'Quantité totale de pièces',
            value: formatCollectionNumber(report.collectionSummary.totalPieces),
            showDivider: report.distribution == null,
          ),
          if (report.distribution != null) ...[
            const SizedBox(height: 8),
            Text(
              'Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Lieu',
              value: _valueOrDash(report.distribution!.distributionLocation),
            ),
            _DetailRow(
              label: 'Bénéficiaires estimés',
              value:
                  report.distribution!.estimatedBeneficiaries?.toString() ??
                  '—',
            ),
            _DetailRow(
              label: 'Repas distribués',
              value: report.distribution!.distributedMeals?.toString() ?? '—',
            ),
            _DetailRow(
              label: 'Poids restant',
              value: report.distribution!.remainingWeightKg == null
                  ? '—'
                  : '${formatCollectionNumber(report.distribution!.remainingWeightKg!)} kg',
            ),
          ],
          const SizedBox(height: 8),
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          MaraudePhotoGallery(
            concertId: widget.concert.id,
            canUpload: false,
            isUploading: false,
            onUpload: () {},
            currentUserId: widget.currentUserId,
            isAdmin: widget.isAdmin,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commentaire de fin',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.canEditComment)
                IconButton(
                  key: const ValueKey('edit-closing-comment'),
                  tooltip: 'Modifier le commentaire de fin',
                  onPressed: _editClosingComment,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_valueOrDash(report.closingComment)),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('export-maraude-report'),
              onPressed: _isExporting ? null : _export,
              icon: _isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter le bilan'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editClosingComment() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ClosingCommentDialog(
        initialValue: widget.concert.closingComment,
        onSubmit: (value) => ref
            .read(concertRepositoryProvider)
            .updateClosingComment(widget.concert.id, value),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(concertDetailsProvider(widget.concert.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Commentaire de fin enregistré.')),
    );
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      await ref.read(maraudeReportPdfServiceProvider).export(_report);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export du bilan lancé.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible d’exporter le bilan.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _TeamRosterLine extends StatelessWidget {
  const _TeamRosterLine({required this.application});

  final ConcertVolunteerApplication application;

  @override
  Widget build(BuildContext context) {
    final role = application.teamRole;
    final attendance = application.effectiveAttendanceStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              role == null
                  ? application.displayName
                  : '${application.displayName} — ${role.label}',
            ),
          ),
          if (attendance != null)
            Text(
              attendance.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _ClosingCommentDialog extends StatefulWidget {
  const _ClosingCommentDialog({required this.onSubmit, this.initialValue});

  final String? initialValue;
  final Future<void> Function(String? value) onSubmit;

  @override
  State<_ClosingCommentDialog> createState() => _ClosingCommentDialogState();
}

class _ClosingCommentDialogState extends State<_ClosingCommentDialog> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Commentaire de fin'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('closing-comment-field'),
              controller: _controller,
              enabled: !_isSubmitting,
              autofocus: true,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                hintText: 'Optionnel',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = describeError(
          error,
          'Impossible d’enregistrer le commentaire de fin.',
        );
      });
    }
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.concert,
    required this.onEdit,
    required this.onDelete,
  });

  final Concert concert;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/maraudes');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concert.artist,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InlineInformation(
                    icon: Icons.location_on_outlined,
                    text: concert.venueName ?? '—',
                  ),
                  _InlineInformation(
                    icon: Icons.calendar_today_outlined,
                    text: formatLongFrenchDate(concert.date),
                  ),
                  _MaraudeStatusChip(status: concert.maraudeStatus),
                ],
              ),
            ],
          ),
        ),
        if (onEdit != null || onDelete != null)
          PopupMenuButton<_DetailAction>(
            tooltip: 'Actions',
            onSelected: (action) {
              switch (action) {
                case _DetailAction.edit:
                  onEdit?.call();
                case _DetailAction.delete:
                  onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                const PopupMenuItem(
                  value: _DetailAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: _DetailAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

enum _DetailAction { edit, delete }

class _InformationSection extends StatelessWidget {
  const _InformationSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final cateringClosesAt = concert.cateringClosesAt;
    return _SectionCard(
      title: 'Informations',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _DetailRow(label: 'Artiste', value: concert.artist),
          _DetailRow(label: 'Date', value: formatLongFrenchDate(concert.date)),
          _DetailRow(
            label: 'Producteur',
            value: concert.promoterOrganizationName ?? '—',
          ),
          _DetailRow(label: 'Notes', value: concert.notes ?? '—'),
          _DetailRow(
            label: 'Fermeture du catering',
            value: cateringClosesAt == null
                ? '—'
                : formatDatabaseTime(cateringClosesAt),
          ),
          _DetailRow(
            label: 'Arrivée recommandée',
            value: cateringClosesAt == null
                ? '—'
                : recommendedArrivalFromDatabase(cateringClosesAt),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _VenueSection extends StatelessWidget {
  const _VenueSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final venue = concert.venue;
    return _SectionCard(
      title: 'Salle',
      icon: Icons.location_on_outlined,
      child: Column(
        children: [
          _DetailRow(label: 'Nom', value: venue?.name ?? '—'),
          _DetailRow(label: 'Adresse', value: venue?.publicAddressLine1 ?? '—'),
          _DetailRow(
            label: 'Complément',
            value: venue?.publicAddressLine2 ?? '—',
          ),
          _DetailRow(label: 'Ville', value: venue?.city ?? '—'),
          _DetailRow(label: 'Code postal', value: venue?.postalCode ?? '—'),
          const Divider(height: 24),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informations d’accès disponibles selon vos autorisations.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ApplicationFilter {
  all('Tous'),
  selected('Sélectionnés'),
  pending('En attente'),
  withdrawn('Désistés'),
  notSelected('Non sélectionnés');

  const _ApplicationFilter(this.label);

  final String label;
}

extension on _ApplicationFilter {
  bool matches(ConcertVolunteerStatus status) {
    return switch (this) {
      _ApplicationFilter.all => true,
      _ApplicationFilter.selected => status == ConcertVolunteerStatus.selected,
      _ApplicationFilter.pending => status == ConcertVolunteerStatus.pending,
      _ApplicationFilter.withdrawn =>
        status == ConcertVolunteerStatus.withdrawn,
      _ApplicationFilter.notSelected =>
        status == ConcertVolunteerStatus.notSelected,
    };
  }
}

class _VolunteersSection extends ConsumerStatefulWidget {
  const _VolunteersSection({
    required this.concertId,
    required this.maraudeStatus,
  });

  final String concertId;
  final MaraudeStatus maraudeStatus;

  @override
  ConsumerState<_VolunteersSection> createState() => _VolunteersSectionState();
}

class _VolunteersSectionState extends ConsumerState<_VolunteersSection> {
  static const _minimumTeamSize = 3;

  bool _isSubmitting = false;
  bool _isSavingTeam = false;
  bool _teamDirty = false;
  int _mobileTeamView = 0;
  final Set<String> _updatingApplications = {};
  final Map<String, MaraudeRole> _draftTeamRoles = {};
  String? _serverTeamSignature;
  final TextEditingController _searchController = TextEditingController();
  _ApplicationFilter _filter = _ApplicationFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(
      concertVolunteerSectionProvider(widget.concertId),
    );
    final currentAccount = ref.watch(currentUserContextProvider).value;

    return _SectionCard(
      title: 'Bénévoles',
      icon: Icons.groups_outlined,
      child: section.when(
        loading: () => const AppLoadingState(label: 'Chargement des bénévoles'),
        error: (_, _) => AppErrorState(
          message: 'Impossible de charger les candidatures.',
          onRetry: () =>
              ref.invalidate(concertVolunteerSectionProvider(widget.concertId)),
        ),
        data: (data) {
          if (currentAccount != null &&
              (data.currentUserId != currentAccount.profileId ||
                  data.activeRole != currentAccount.role)) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(ConcertVolunteerSectionData data) {
    _synchronizeTeamDraft(data.applications);
    final visibleApplications = _visibleApplications(data.applications);
    final ownApplication =
        data.activeRole == AppUserRole.volunteer &&
            data.currentUserId != null &&
            data.ownApplication?.userId == data.currentUserId
        ? data.ownApplication
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _applicationCountLabel(data.counts.applicationCount),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_selectedCountLabel(data.counts.selectedCount)),
        const SizedBox(height: 20),
        if (data.activeRole == AppUserRole.volunteer) ...[
          if (ownApplication == null &&
              data.canApply &&
              _applicationWindowIsOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _apply,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Je me propose'),
              ),
            )
          else if (ownApplication != null)
            _OwnApplication(
              application: ownApplication,
              isSubmitting: _isSubmitting,
              onWithdraw:
                  _canWithdraw(ownApplication.status, widget.maraudeStatus)
                  ? _withdraw
                  : null,
              onConfirm:
                  _applicationWindowIsOpen &&
                      ownApplication.status ==
                          ConcertVolunteerStatus.selected &&
                      ownApplication.confirmationStatus ==
                          VolunteerConfirmationStatus.pending
                  ? _confirmParticipation
                  : null,
              onReapply:
                  _applicationWindowIsOpen &&
                      data.canApply &&
                      ownApplication.status == ConcertVolunteerStatus.withdrawn
                  ? _reapply
                  : null,
            ),
          const SizedBox(height: 16),
          _VolunteerRosterPreview(concertId: widget.concertId),
        ],
        if (data.isAdmin && _canEditTeam) ...[
          const Divider(height: 32),
          _buildTeamBuilder(data, visibleApplications),
        ] else if (data.isAdmin) ...[
          const Divider(height: 32),
          const _LockedTeamNotice(),
          const SizedBox(height: 16),
          _PromoterApplications(applications: visibleApplications),
        ] else if (data.isPromoter && data.canViewApplications) ...[
          const Divider(height: 32),
          _PromoterApplications(applications: visibleApplications),
        ],
      ],
    );
  }

  bool get _canEditTeam =>
      widget.maraudeStatus == MaraudeStatus.open ||
      widget.maraudeStatus == MaraudeStatus.teamReady;

  bool get _applicationWindowIsOpen => _canEditTeam;

  Widget _buildTeamBuilder(
    ConcertVolunteerSectionData data,
    List<ConcertVolunteerApplication> visibleApplications,
  ) {
    final candidates = Column(
      key: const ValueKey('team-candidates-column'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Candidatures',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('volunteer-search-field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Rechercher',
            hintText: 'Nom, téléphone ou e-mail',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _ApplicationFilter.values)
              FilterChip(
                key: ValueKey('volunteer-filter-${filter.name}'),
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visibleApplications.isEmpty)
          const _FilteredApplicationsEmptyState()
        else
          for (final application in visibleApplications)
            _TeamCandidateCard(
              application: application,
              selectedRole: _draftTeamRoles[application.id],
              isUpdating: _updatingApplications.contains(application.id),
              isRoleAvailable: (role) => _isRoleAvailable(role, application.id),
              onSelect: () => _selectInDraft(application.id),
              onReject: () => _rejectApplication(application.id),
              onRemove: () => _removeFromDraft(application.id),
              onRoleChanged: (role) => _assignDraftRole(application.id, role),
            ),
      ],
    );

    final summary = _TeamBuilderSummary(
      applications: data.applications,
      roles: _draftTeamRoles,
      minimumTeamSize: _minimumTeamSize,
      isDirty: _teamDirty,
      isSaving: _isSavingTeam,
      onSave: _canSaveTeam ? _saveTeam : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            key: const ValueKey('team-builder-desktop'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: candidates),
              const SizedBox(width: 24),
              SizedBox(width: 320, child: summary),
            ],
          );
        }

        return Column(
          key: const ValueKey('team-builder-mobile'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              key: const ValueKey('team-mobile-tabs'),
              segments: const [
                ButtonSegment(value: 0, label: Text('Candidatures')),
                ButtonSegment(value: 1, label: Text('Équipe')),
              ],
              selected: {_mobileTeamView},
              onSelectionChanged: (selection) =>
                  setState(() => _mobileTeamView = selection.single),
            ),
            const SizedBox(height: 16),
            if (_mobileTeamView == 0) candidates else summary,
          ],
        );
      },
    );
  }

  bool get _canSaveTeam {
    return _teamDirty &&
        !_isSavingTeam &&
        _draftTeamRoles.length >= _minimumTeamSize &&
        _draftTeamRoles.values
                .where((role) => role == MaraudeRole.teamLeader)
                .length ==
            1;
  }

  void _synchronizeTeamDraft(List<ConcertVolunteerApplication> applications) {
    final serverMembers =
        applications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected,
            )
            .map(
              (application) =>
                  '${application.id}:${application.teamRole?.databaseValue}',
            )
            .toList()
          ..sort();
    final signature = serverMembers.join('|');
    if (_serverTeamSignature == signature || _teamDirty) return;

    _serverTeamSignature = signature;
    _draftTeamRoles
      ..clear()
      ..addEntries(
        applications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected,
            )
            .map(
              (application) => MapEntry(
                application.id,
                application.teamRole ?? MaraudeRole.collectionDistribution,
              ),
            ),
      );
  }

  List<ConcertVolunteerApplication> _visibleApplications(
    List<ConcertVolunteerApplication> applications,
  ) {
    final query = _normalizeVolunteerSearch(_searchController.text);
    final visible =
        applications.where((application) {
          final effectiveStatus = _draftTeamRoles.containsKey(application.id)
              ? ConcertVolunteerStatus.selected
              : application.status == ConcertVolunteerStatus.selected
              ? ConcertVolunteerStatus.notSelected
              : application.status;
          if (!_filter.matches(effectiveStatus)) return false;
          if (query.isEmpty) return true;

          final profile = application.profile;
          final searchableValue = _normalizeVolunteerSearch(
            [
              application.displayName,
              profile?.phone,
              profile?.email,
            ].whereType<String>().join(' '),
          );
          return searchableValue.contains(query);
        }).toList()..sort((left, right) {
          final leftSelected = _draftTeamRoles.containsKey(left.id);
          final rightSelected = _draftTeamRoles.containsKey(right.id);
          if (leftSelected != rightSelected) return leftSelected ? -1 : 1;
          return _compareApplications(left, right);
        });
    return visible;
  }

  bool _isRoleAvailable(MaraudeRole role, String applicationId) {
    if (role != MaraudeRole.teamLeader) return true;
    return !_draftTeamRoles.entries.any(
      (entry) =>
          entry.key != applicationId && entry.value == MaraudeRole.teamLeader,
    );
  }

  void _selectInDraft(String applicationId) {
    setState(() {
      _draftTeamRoles[applicationId] = MaraudeRole.collectionDistribution;
      _teamDirty = true;
    });
  }

  void _removeFromDraft(String applicationId) {
    setState(() {
      _draftTeamRoles.remove(applicationId);
      _teamDirty = true;
    });
  }

  void _assignDraftRole(String applicationId, MaraudeRole role) {
    if (!_isRoleAvailable(role, applicationId)) return;
    setState(() {
      _draftTeamRoles[applicationId] = role;
      _teamDirty = true;
    });
  }

  Future<void> _apply() async {
    if (!_applicationWindowIsOpen) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .apply(widget.concertId);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Votre candidature a été enregistrée.\n\n'
            'Vous serez informé si vous êtes sélectionné.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        describeError(
          error,
          'Impossible d’enregistrer votre candidature. Veuillez réessayer.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _withdraw() async {
    final section = ref
        .read(concertVolunteerSectionProvider(widget.concertId))
        .value;
    final application = section?.ownApplication;
    if (section == null ||
        application == null ||
        section.activeRole != AppUserRole.volunteer ||
        section.currentUserId == null ||
        application.userId != section.currentUserId ||
        !_canWithdraw(application.status, widget.maraudeStatus)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le désistement ?'),
        content: const Text(
          'Votre candidature restera dans l’historique avec le statut '
          '« Désisté ». Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Je me désiste'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .withdraw(application.id);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Désistement enregistré.')));
    } catch (error) {
      if (!mounted) return;
      _showError(
        describeError(error, 'Impossible d’enregistrer votre désistement.'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmParticipation() async {
    final section = ref
        .read(concertVolunteerSectionProvider(widget.concertId))
        .value;
    final application = section?.ownApplication;
    if (section == null ||
        application == null ||
        section.activeRole != AppUserRole.volunteer ||
        application.userId != section.currentUserId ||
        application.status != ConcertVolunteerStatus.selected ||
        application.confirmationStatus != VolunteerConfirmationStatus.pending ||
        application.teamRole == null) {
      return;
    }

    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirmer ma participation'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fiche de mission',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_ind_outlined),
                  title: Text(application.teamRole!.label),
                  subtitle: const Text(
                    'Ce rôle vous est attribué pour cette maraude.',
                  ),
                  trailing: TextButton(
                    key: const ValueKey('open-mission-sheet-confirm-dialog'),
                    onPressed: () => showMaraudeRoleMissionSheet(
                      context,
                      application.teamRole!,
                    ),
                    child: const Text('Voir la fiche complète'),
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('acknowledge-mission-role'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: acknowledged,
                  onChanged: (value) =>
                      setDialogState(() => acknowledged = value ?? false),
                  title: const Text(
                    'J’ai pris connaissance de ma fiche de mission.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const ValueKey('submit-participation-confirmation'),
              onPressed: acknowledged
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('Je confirme ma participation'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .confirmParticipation(widget.concertId, roleAcknowledged: true);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      ref.invalidate(maraudeAttendanceProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Participation confirmée.')));
    } catch (error) {
      if (!mounted) return;
      _showError(
        describeError(error, 'Impossible de confirmer votre participation.'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reapply() async {
    if (!_applicationWindowIsOpen) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .reapply(widget.concertId);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Disponibilité transmise.')));
    } catch (error) {
      if (!mounted) return;
      _showError(
        describeError(error, 'Impossible de renouveler votre disponibilité.'),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveTeam() async {
    setState(() => _isSavingTeam = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .saveTeam(
            widget.concertId,
            _draftTeamRoles.entries.map(
              (entry) => MaraudeTeamMemberDraft(
                applicationId: entry.key,
                role: entry.value,
              ),
            ),
          );
      _teamDirty = false;
      _serverTeamSignature = null;
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Équipe enregistrée.')));
    } catch (error) {
      if (!mounted) return;
      _showError(describeError(error, 'Impossible d’enregistrer l’équipe.'));
    } finally {
      if (mounted) setState(() => _isSavingTeam = false);
    }
  }

  Future<void> _rejectApplication(String applicationId) async {
    setState(() => _updatingApplications.add(applicationId));
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .setStatus(applicationId, ConcertVolunteerStatus.notSelected);
      _draftTeamRoles.remove(applicationId);
      _serverTeamSignature = null;
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Candidature refusée.')));
    } catch (error) {
      if (!mounted) return;
      _showError(
        describeError(error, 'Impossible de refuser cette candidature.'),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingApplications.remove(applicationId));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PromoterApplications extends StatelessWidget {
  const _PromoterApplications({required this.applications});

  final List<ConcertVolunteerApplication> applications;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const _FilteredApplicationsEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Candidatures',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final application in applications)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: application.profile?.avatarUrl == null
                    ? null
                    : NetworkImage(application.profile!.avatarUrl!),
                child: application.profile?.avatarUrl == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(application.displayName),
              subtitle: Text(application.status.label),
              trailing: application.teamRole == null
                  ? null
                  : Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(application.teamRole!.label),
                    ),
            ),
          ),
      ],
    );
  }
}

class _LockedTeamNotice extends StatelessWidget {
  const _LockedTeamNotice();

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      key: const ValueKey('locked-maraude-team'),
      margin: EdgeInsets.zero,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'La composition et les rôles de l’équipe sont verrouillés '
                'depuis le démarrage de la maraude.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canWithdraw(ConcertVolunteerStatus status, MaraudeStatus maraudeStatus) {
  final applicationWindowIsOpen =
      maraudeStatus == MaraudeStatus.open ||
      maraudeStatus == MaraudeStatus.teamReady;
  return applicationWindowIsOpen &&
      (status == ConcertVolunteerStatus.pending ||
          status == ConcertVolunteerStatus.selected);
}

class _OwnApplication extends StatelessWidget {
  const _OwnApplication({
    required this.application,
    required this.isSubmitting,
    required this.onWithdraw,
    required this.onConfirm,
    required this.onReapply,
  });

  final ConcertVolunteerApplication application;
  final bool isSubmitting;
  final VoidCallback? onWithdraw;
  final VoidCallback? onConfirm;
  final VoidCallback? onReapply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          application.status.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (application.status == ConcertVolunteerStatus.selected) ...[
          const SizedBox(height: 6),
          Text(
            application.confirmationStatus?.label ??
                'Confirmation à synchroniser',
          ),
          if (application.teamRole != null)
            Text('Rôle : ${application.teamRole!.label}'),
          if (application.confirmationStatus ==
                  VolunteerConfirmationStatus.pending &&
              application.confirmationDueAt != null)
            Text(
              'À confirmer avant le '
              '${formatFrenchDateTime(application.confirmationDueAt!)}',
            ),
          if (application.confirmationStatus ==
              VolunteerConfirmationStatus.confirmed)
            Text(
              'Présence : '
              '${application.effectiveAttendanceStatus?.label ?? 'À renseigner'}',
            ),
        ],
        if (onConfirm != null) ...[
          const SizedBox(height: 4),
          FilledButton(
            key: const ValueKey('confirm-concert-participation'),
            onPressed: isSubmitting ? null : onConfirm,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Je confirme ma participation'),
          ),
        ],
        if (onWithdraw != null) ...[
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: isSubmitting ? null : onWithdraw,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    onConfirm == null
                        ? 'Je me désiste'
                        : 'Je ne suis plus disponible',
                  ),
          ),
        ],
        if (onReapply != null) ...[
          const SizedBox(height: 4),
          FilledButton(
            key: const ValueKey('reapply-to-concert'),
            onPressed: isSubmitting ? null : onReapply,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Je suis de nouveau disponible'),
          ),
        ],
      ],
    );
  }
}

/// Lets a volunteer see who has already applied and who is already
/// selected before deciding whether to apply themselves — deliberately
/// limited to names, status and role (see
/// get_concert_volunteer_roster): no contact or personal information.
class _VolunteerRosterPreview extends ConsumerWidget {
  const _VolunteerRosterPreview({required this.concertId});

  final String concertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(concertVolunteerRosterProvider(concertId));
    return roster.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final selected = entries
            .where((entry) => entry.status == ConcertVolunteerStatus.selected)
            .toList(growable: false);
        final pending = entries
            .where((entry) => entry.status != ConcertVolunteerStatus.selected)
            .toList(growable: false);
        return Column(
          key: const ValueKey('volunteer-roster-preview'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qui s’est déjà positionné',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (selected.isNotEmpty) ...[
              Text(
                'Déjà sélectionnés',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final entry in selected) _RosterLine(entry: entry),
              const SizedBox(height: 8),
            ],
            if (pending.isNotEmpty) ...[
              Text(
                'Candidatures en attente',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              for (final entry in pending) _RosterLine(entry: entry),
            ],
          ],
        );
      },
    );
  }
}

class _RosterLine extends StatelessWidget {
  const _RosterLine({required this.entry});

  final ConcertVolunteerRosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final role = entry.teamRole;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        role == null
            ? entry.displayName
            : '${entry.displayName} — ${role.label}',
      ),
    );
  }
}

class _TeamBuilderSummary extends StatelessWidget {
  const _TeamBuilderSummary({
    required this.applications,
    required this.roles,
    required this.minimumTeamSize,
    required this.isDirty,
    required this.isSaving,
    required this.onSave,
  });

  final List<ConcertVolunteerApplication> applications;
  final Map<String, MaraudeRole> roles;
  final int minimumTeamSize;
  final bool isDirty;
  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final hasLeader = roles.containsValue(MaraudeRole.teamLeader);
    final hasMinimumSize = roles.length >= minimumTeamSize;
    final isValidTeam = hasMinimumSize && hasLeader;
    final teamApplications = applications.where(
      (application) => roles.containsKey(application.id),
    );
    final confirmedCount = teamApplications
        .where(
          (application) =>
              application.confirmationStatus ==
              VolunteerConfirmationStatus.confirmed,
        )
        .length;
    final pendingConfirmationCount = roles.length - confirmedCount;
    final colors = Theme.of(context).colorScheme;

    return Card.filled(
      key: const ValueKey('team-builder-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Équipe retenue',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${roles.length} / $minimumTeamSize bénévoles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$confirmedCount confirmé${confirmedCount > 1 ? 's' : ''} · '
              '$pendingConfirmationCount confirmation'
              '${pendingConfirmationCount > 1 ? 's' : ''} attendue'
              '${pendingConfirmationCount > 1 ? 's' : ''}',
            ),
            const Divider(height: 28),
            _TeamRoleSummary(
              label: 'Chef d’équipe',
              names: _namesForRole(MaraudeRole.teamLeader),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Communication',
              names: _namesForRole(MaraudeRole.communication),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Logistique',
              names: _namesForRole(MaraudeRole.logistics),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Récolte & distribution',
              names: _namesForRole(MaraudeRole.collectionDistribution),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Icon(
                  isValidTeam
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                  color: isValidTeam ? colors.primary : colors.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isValidTeam
                        ? 'Équipe complète : un chef et au moins deux autres bénévoles.'
                        : !hasMinimumSize
                        ? 'Ajoutez au moins $minimumTeamSize bénévoles.'
                        : 'Attribuez le rôle de chef d’équipe à une personne.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('save-maraude-team'),
              onPressed: onSave,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                !isDirty ? 'Équipe enregistrée' : 'Enregistrer l’équipe',
              ),
            ),
            if (!hasLeader) ...[
              const SizedBox(height: 8),
              const Text(
                'Aucun rôle Chef.fe d’équipe n’est attribué. '
                'Cette recommandation ne bloque pas l’enregistrement.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _namesForRole(MaraudeRole role) {
    final applicationsById = {
      for (final application in applications) application.id: application,
    };
    return roles.entries
        .where((entry) => entry.value == role)
        .map((entry) => applicationsById[entry.key]?.displayName ?? 'Bénévole')
        .toList(growable: false);
  }
}

class _TeamRoleSummary extends StatelessWidget {
  const _TeamRoleSummary({required this.label, required this.names});

  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(names.isEmpty ? '—' : names.join('\n')),
      ],
    );
  }
}

class _FilteredApplicationsEmptyState extends StatelessWidget {
  const _FilteredApplicationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text('Aucune candidature ne correspond.')),
    );
  }
}

class _ApplicationStatusChip extends StatelessWidget {
  const _ApplicationStatusChip({required this.status});

  final ConcertVolunteerStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor) = switch (status) {
      ConcertVolunteerStatus.selected => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      ConcertVolunteerStatus.pending => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      ConcertVolunteerStatus.withdrawn => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      ConcertVolunteerStatus.notSelected => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      label: Text(status.label, style: TextStyle(color: foregroundColor)),
    );
  }
}

class _TeamCandidateCard extends StatelessWidget {
  const _TeamCandidateCard({
    required this.application,
    required this.selectedRole,
    required this.isUpdating,
    required this.isRoleAvailable,
    required this.onSelect,
    required this.onReject,
    required this.onRemove,
    required this.onRoleChanged,
  });

  final ConcertVolunteerApplication application;
  final MaraudeRole? selectedRole;
  final bool isUpdating;
  final bool Function(MaraudeRole role) isRoleAvailable;
  final VoidCallback onSelect;
  final VoidCallback onReject;
  final VoidCallback onRemove;
  final ValueChanged<MaraudeRole> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final profile = application.profile;
    final statistics = application.statistics;
    final isSelected = selectedRole != null;
    final effectiveStatus = isSelected
        ? ConcertVolunteerStatus.selected
        : application.status == ConcertVolunteerStatus.selected
        ? ConcertVolunteerStatus.notSelected
        : application.status;

    return Card(
      key: ValueKey('volunteer-card-${application.id}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showVolunteerProfileDialog(context, application),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VolunteerAvatar(profile: profile),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _ApplicationStatusChip(status: effectiveStatus),
                              if (isSelected)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.how_to_reg_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    application.confirmationStatus?.label ??
                                        'Confirmation à synchroniser',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _CandidateFact(
                  label: 'Maraudes',
                  value: '${statistics.selectedApplications}',
                ),
                _CandidateFact(
                  label: 'Dernière participation',
                  value: _compactDateOrNone(statistics.lastSelectedDate),
                ),
                _CandidateFact(
                  label: 'Désistements',
                  value: statistics.withdrawnApplications == 0
                      ? 'Aucun'
                      : '${statistics.withdrawnApplications}',
                ),
                _CandidateFact(
                  label: 'Disponibilité',
                  value: switch (application.status) {
                    ConcertVolunteerStatus.withdrawn => 'Non disponible',
                    ConcertVolunteerStatus.selected =>
                      application.confirmationStatus?.label ??
                          'Confirmation à synchroniser',
                    _ => 'Disponible',
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('view-volunteer-profile-${application.id}'),
                onPressed: () =>
                    _showVolunteerProfileDialog(context, application),
                icon: const Icon(Icons.person_outline),
                label: const Text('Voir le profil'),
              ),
            ),
            const Divider(height: 28),
            if (!isSelected)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: ValueKey('select-volunteer-${application.id}'),
                    onPressed:
                        isUpdating ||
                            application.status ==
                                ConcertVolunteerStatus.withdrawn
                        ? null
                        : onSelect,
                    child: const Text('Sélectionner'),
                  ),
                  if (application.status == ConcertVolunteerStatus.pending)
                    OutlinedButton(
                      key: ValueKey('reject-volunteer-${application.id}'),
                      onPressed: isUpdating ? null : onReject,
                      child: const Text('Refuser'),
                    ),
                ],
              )
            else ...[
              Text(
                'Rôle dans la maraude',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              RadioGroup<MaraudeRole>(
                groupValue: selectedRole,
                onChanged: (value) {
                  if (value != null && isRoleAvailable(value)) {
                    onRoleChanged(value);
                  }
                },
                child: Column(
                  children: [
                    for (final role in MaraudeRole.values)
                      RadioListTile<MaraudeRole>(
                        key: ValueKey(
                          'team-role-${application.id}-${role.name}',
                        ),
                        value: role,
                        enabled:
                            !isUpdating &&
                            (isRoleAvailable(role) || selectedRole == role),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(role.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('remove-volunteer-${application.id}'),
                  onPressed: isUpdating ? null : onRemove,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Retirer de l’équipe'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateFact extends StatelessWidget {
  const _CandidateFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _VolunteerAvatar extends StatelessWidget {
  const _VolunteerAvatar({required this.profile, this.size = 48});

  final VolunteerProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();
    return ClipOval(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: SizedBox.square(
          dimension: size,
          child: avatarUrl?.isNotEmpty == true
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person_outline),
                )
              : const Icon(Icons.person_outline),
        ),
      ),
    );
  }
}

Future<void> _showVolunteerProfileDialog(
  BuildContext context,
  ConcertVolunteerApplication application,
) {
  final profile = application.profile;
  final statistics = application.statistics;
  final container = ProviderScope.containerOf(context);
  Future<Map<String, dynamic>?> fetchPrivateInformation() => container
      .read(concertVolunteerRepositoryProvider)
      .fetchPrivateVolunteerInformation(application.userId);
  return showDialog<void>(
    context: context,
    builder: (context) => UncontrolledProviderScope(
      container: container,
      child: AlertDialog(
        title: const Text('Profil bénévole'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _VolunteerAvatar(profile: profile, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        application.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileDetailRow(
                  label: 'Date de naissance',
                  value: profile?.birthDate == null
                      ? 'Non renseignée'
                      : formatLongFrenchDate(profile!.birthDate!),
                ),
                _ProfileDetailRow(
                  label: 'Téléphone',
                  value: _optionalValue(profile?.phone),
                ),
                _ProfileDetailRow(
                  label: 'E-mail',
                  value: _optionalValue(profile?.email),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expérience',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(_totalApplicationsLabel(statistics.totalApplications)),
                const SizedBox(height: 6),
                Text(_selectedMissionsLabel(statistics.selectedApplications)),
                const SizedBox(height: 6),
                Text(
                  _notSelectedMissionsLabel(statistics.notSelectedApplications),
                ),
                const SizedBox(height: 6),
                Text(_withdrawalsLabel(statistics.withdrawnApplications)),
                const SizedBox(height: 16),
                _ProfileDetailRow(
                  label: 'Dernière participation',
                  value: statistics.lastSelectedDate == null
                      ? 'Aucune'
                      : formatLongFrenchDate(statistics.lastSelectedDate!),
                ),
                if (statistics.selectionRate != null) ...[
                  Text('Taux de sélection : ${statistics.selectionRate} %'),
                  const SizedBox(height: 6),
                  Text('Taux de désistement : ${statistics.withdrawalRate} %'),
                ],
                const Divider(height: 32),
                Text(
                  'Contact d’urgence',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _ProfileDetailRow(
                  label: 'Nom',
                  value: _optionalValue(profile?.emergencyContactName),
                ),
                _ProfileDetailRow(
                  label: 'Téléphone',
                  value: _optionalValue(profile?.emergencyContactPhone),
                  showDivider: false,
                ),
                const Divider(height: 32),
                _PrivateInformationSection(fetch: fetchPrivateInformation),
                const Divider(height: 32),
                Text(
                  'Documents',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                VolunteerDocumentsPanel(userId: application.userId),
                const Divider(height: 32),
                Text(
                  'Historique des maraudes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (statistics.history.isEmpty)
                  const Text('Aucun historique.')
                else
                  for (final entry in statistics.history)
                    _VolunteerHistoryCard(entry: entry),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    ),
  );
}

class _PrivateInformationSection extends StatefulWidget {
  const _PrivateInformationSection({required this.fetch});

  final Future<Map<String, dynamic>?> Function() fetch;

  @override
  State<_PrivateInformationSection> createState() =>
      _PrivateInformationSectionState();
}

class _PrivateInformationSectionState
    extends State<_PrivateInformationSection> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch();
  }

  void _retry() {
    setState(() => _future = widget.fetch());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(label: 'Chargement des informations');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Impossible de charger les informations confidentielles.',
            onRetry: _retry,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Text('Aucune information complémentaire renseignée.');
        }
        final certifications =
            (data['certifications'] as List<dynamic>? ?? const []).join(', ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations confidentielles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ProfileDetailRow(
              label: 'Informations complémentaires',
              value: _optionalValue(data['additional_information'] as String?),
            ),
            _ProfileDetailRow(
              label: 'Certifications',
              value: certifications.isEmpty
                  ? 'Non renseignées'
                  : certifications,
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class _VolunteerHistoryCard extends StatelessWidget {
  const _VolunteerHistoryCard({required this.entry});

  final VolunteerHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      key: ValueKey('volunteer-history-${entry.concertId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatLongFrenchDate(entry.concertDate),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              entry.artist,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.venueName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.status.label),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

String _applicationCountLabel(int count) {
  return '$count ${count == 1 ? 'candidature' : 'candidatures'}';
}

String _selectedCountLabel(int count) {
  return '$count ${count == 1 ? 'bénévole sélectionné' : 'bénévoles sélectionnés'}';
}

String _totalApplicationsLabel(int count) {
  return '$count ${count == 1 ? 'candidature' : 'candidatures'}';
}

String _selectedMissionsLabel(int count) {
  return '$count ${count == 1 ? 'maraude sélectionnée' : 'maraudes sélectionnées'}';
}

String _notSelectedMissionsLabel(int count) {
  return '$count ${count == 1 ? 'non-sélection' : 'non-sélections'}';
}

String _withdrawalsLabel(int count) {
  return '$count ${count == 1 ? 'désistement' : 'désistements'}';
}

int _compareApplications(
  ConcertVolunteerApplication first,
  ConcertVolunteerApplication second,
) {
  final statusComparison = _statusOrder(
    first.status,
  ).compareTo(_statusOrder(second.status));
  if (statusComparison != 0) return statusComparison;
  return _normalizeVolunteerSearch(
    first.displayName,
  ).compareTo(_normalizeVolunteerSearch(second.displayName));
}

int _statusOrder(ConcertVolunteerStatus status) {
  return switch (status) {
    ConcertVolunteerStatus.selected => 0,
    ConcertVolunteerStatus.pending => 1,
    ConcertVolunteerStatus.withdrawn => 2,
    ConcertVolunteerStatus.notSelected => 3,
  };
}

String _normalizeVolunteerSearch(String value) {
  var normalized = value.trim().toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  for (final replacement in replacements.entries) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }
  return normalized;
}

String _compactDateOrNone(DateTime? value) {
  if (value == null) return 'Aucune';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _optionalValue(String? value) {
  final trimmed = value?.trim();
  return trimmed?.isNotEmpty == true ? trimmed! : 'Non renseigné';
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final hasCateringContact = [
      concert.cateringContactName,
      concert.cateringContactPhone,
      concert.cateringContactEmail,
    ].any((value) => value?.trim().isNotEmpty == true);

    return _SectionCard(
      title: 'Contacts sur place',
      icon: Icons.contact_phone_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactDetails(
            title: 'Contact tourneur',
            emptyMessage: 'Aucun contact tourneur renseigné.',
            name: concert.promoterContactName,
            phone: concert.promoterContactPhone,
            email: concert.promoterContactEmail,
          ),
          if (hasCateringContact) ...[
            const Divider(height: 32),
            _ContactDetails(
              title: 'Contact catering',
              emptyMessage: 'Aucun contact catering renseigné.',
              name: concert.cateringContactName,
              phone: concert.cateringContactPhone,
              email: concert.cateringContactEmail,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({
    required this.title,
    required this.emptyMessage,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String title;
  final String emptyMessage;
  final String? name;
  final String? phone;
  final String? email;

  bool get _isEmpty => name == null && phone == null && email == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_isEmpty)
          Text(emptyMessage)
        else ...[
          _DetailRow(label: 'Nom', value: name ?? '—'),
          _DetailRow(label: 'Téléphone', value: phone ?? '—'),
          _DetailRow(label: 'E-mail', value: email ?? '—', showDivider: false),
        ],
      ],
    );
  }
}

class _MaraudeChatSection extends ConsumerStatefulWidget {
  const _MaraudeChatSection({required this.concertId});
  final String concertId;

  @override
  ConsumerState<_MaraudeChatSection> createState() =>
      _MaraudeChatSectionState();
}

class _MaraudeChatSectionState extends ConsumerState<_MaraudeChatSection> {
  static const _refreshInterval = Duration(seconds: 5);

  final _controller = TextEditingController();
  bool _sending = false;
  bool _updatingSound = false;
  Timer? _refreshTimer;
  Set<String>? _knownMessageIds;
  String get _lastReadPreferenceKey =>
      'maraude_chat_last_read_${widget.concertId}';
  DateTime? _lastReadAt;
  bool _lastReadRestored = false;
  int _unreadCount = 0;
  bool _unreadCountCaptured = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        ref.invalidate(maraudeMessagesProvider(widget.concertId));
      }
    });
    ref.read(maraudeChatSoundProvider).restore().then((_) {
      if (mounted) setState(() {});
    });
    _restoreLastRead();
  }

  Future<void> _restoreLastRead() async {
    try {
      final stored = await SharedPreferencesAsync().getString(
        _lastReadPreferenceKey,
      );
      if (!mounted) return;
      setState(() {
        _lastReadAt = stored == null ? null : DateTime.tryParse(stored);
        _lastReadRestored = true;
      });
    } catch (_) {
      if (mounted) setState(() => _lastReadRestored = true);
    }
    _maybeCaptureUnreadCount();
  }

  Future<void> _persistLastRead(DateTime value) async {
    _lastReadAt = value;
    try {
      await SharedPreferencesAsync().setString(
        _lastReadPreferenceKey,
        value.toIso8601String(),
      );
    } catch (_) {
      // La discussion reste marquée lue pour la session même si
      // l’écriture échoue.
    }
  }

  /// Unread messages are counted once, the first time both the message
  /// list and the persisted "last read" marker are available — this is
  /// what the badge displays for the whole visit. Every list update
  /// after that keeps the persisted marker current (the user is looking
  /// at the screen, so anything that arrives is implicitly seen) without
  /// changing the displayed count.
  void _maybeCaptureUnreadCount() {
    if (_unreadCountCaptured || !_lastReadRestored) return;
    final messages = ref.read(maraudeMessagesProvider(widget.concertId));
    final items = messages.value;
    if (items == null) return;
    final currentUserId = ref.read(currentAuthUserProvider)?.id;
    final lastReadAt = _lastReadAt;
    final unread = items.where((message) {
      return message.userId != currentUserId &&
          (lastReadAt == null || message.createdAt.isAfter(lastReadAt));
    }).length;
    _unreadCountCaptured = true;
    if (mounted) setState(() => _unreadCount = unread);
    _persistLatest(items);
  }

  void _persistLatest(List<MaraudeMessage> messages) {
    if (messages.isEmpty) return;
    final latest = messages
        .map((message) => message.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    if (_lastReadAt == null || latest.isAfter(_lastReadAt!)) {
      unawaited(_persistLastRead(latest));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(maraudeChatRepositoryProvider)
          .send(widget.concertId, _controller.text);
      _controller.clear();
      ref.invalidate(maraudeMessagesProvider(widget.concertId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’envoyer le message.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(maraudeMessagesProvider(widget.concertId));
    ref.listen(maraudeMessagesProvider(widget.concertId), (_, next) {
      next.whenData(_notifyForNewMessages);
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Badge(
                  isLabelVisible: _unreadCount > 0,
                  label: Text('$_unreadCount'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                Text(
                  'Discussion de l’équipe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                OutlinedButton.icon(
                  onPressed: _updatingSound ? null : _toggleSound,
                  icon: Icon(
                    ref.watch(maraudeChatSoundProvider).enabled
                        ? Icons.volume_up_outlined
                        : Icons.volume_off_outlined,
                  ),
                  label: Text(
                    ref.watch(maraudeChatSoundProvider).enabled
                        ? 'Son activé'
                        : 'Activer le son',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            messages.when(
              loading: () =>
                  const AppLoadingState(label: 'Chargement de la discussion'),
              error: (_, _) => AppErrorState(
                message: 'Impossible de charger la discussion.',
                onRetry: () =>
                    ref.invalidate(maraudeMessagesProvider(widget.concertId)),
              ),
              data: (items) => items.isEmpty
                  ? const Text('Aucun message. Lancez la discussion.')
                  : Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.authorName),
                            subtitle: Text(item.message),
                            trailing: Text(
                              '${item.createdAt.hour.toString().padLeft(2, '0')}:'
                              '${item.createdAt.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('maraude-chat-message'),
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'Message',
                suffixIcon: IconButton(
                  key: const ValueKey('send-maraude-chat-message'),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ],
        ),
      ),
    );
  }

  void _notifyForNewMessages(List<MaraudeMessage> messages) {
    _maybeCaptureUnreadCount();

    final currentIds = messages.map((message) => message.id).toSet();
    final knownIds = _knownMessageIds;
    _knownMessageIds = currentIds;
    if (knownIds != null) {
      final hasNewMessage = messages.any(
        (message) => !knownIds.contains(message.id),
      );
      if (hasNewMessage) {
        ref.read(maraudeChatSoundProvider).notify();
      }
    }

    if (_unreadCountCaptured) _persistLatest(messages);
  }

  Future<void> _toggleSound() async {
    final sound = ref.read(maraudeChatSoundProvider);
    setState(() => _updatingSound = true);
    try {
      if (sound.enabled) {
        sound.disable();
      } else {
        await sound.enable();
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSound = false);
      }
    }
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(message)],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(value),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

class _InlineInformation extends StatelessWidget {
  const _InlineInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      message: 'Impossible de charger cette maraude.',
      onRetry: onRetry,
    );
  }
}

class _ConcertNotFound extends StatelessWidget {
  const _ConcertNotFound();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: 'Maraude introuvable',
      message: 'Cette maraude n’existe pas ou n’est pas accessible.',
      icon: Icons.search_off,
      action: FilledButton(
        onPressed: () => context.go('/maraudes'),
        child: const Text('Retour aux maraudes'),
      ),
    );
  }
}
