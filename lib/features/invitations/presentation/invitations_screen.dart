import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart'
    show ConcertViewMode;
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_calendar.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/features/venues/presentation/venue_search_field.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart'
    show VolunteerConfirmationStatus;
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final userContext = ref.watch(currentUserContextProvider).value;
    final campaigns = ref.watch(invitationCampaignsProvider);
    final viewMode = ref.watch(invitationViewModeProvider);
    final role = userContext?.role ?? AppUserRole.volunteer;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          userContext?.role == AppUserRole.admin ||
              userContext?.role == AppUserRole.promoter
          ? FloatingActionButton.extended(
              onPressed: () => _createCampaign(context, ref, userContext!),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle campagne'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(_subtitle(userContext?.role)),
          ),
          MaraudeViewToolbar(
            title: userContext?.role == AppUserRole.promoter
                ? 'Mes invitations'
                : 'Invitations',
            viewMode: viewMode,
            onViewChanged: (mode) =>
                ref.read(invitationViewModeProvider.notifier).select(mode),
            selectorKey: const ValueKey('invitation-view-selector'),
          ),
          Expanded(
            child: campaigns.when(
              loading: () =>
                  const AppLoadingState(label: 'Chargement des invitations'),
              error: (_, _) => AppErrorState(
                message: 'Impossible de charger les invitations.',
                onRetry: () => ref.invalidate(invitationCampaignsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const AppEmptyState(
                      title: 'Aucune invitation',
                      message:
                          'Aucune campagne d’invitations n’est disponible.',
                      icon: Icons.confirmation_number_outlined,
                    )
                  : viewMode == ConcertViewMode.list
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      children: [
                        for (final campaign in items)
                          _CampaignCard(campaign: campaign, role: role),
                      ],
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      child: MaraudeCalendar(
                        month: _displayedMonth,
                        items: items
                            .where((campaign) => campaign.eventDate != null)
                            .map(_invitationCalendarItem)
                            .toList(growable: false),
                        onPreviousMonth: () => _changeMonth(-1),
                        onNextMonth: () => _changeMonth(1),
                        onToday: _goToCurrentMonth,
                        onOpen: (id) => _openCampaign(context, items, id, role),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _displayedMonth = DateTime(now.year, now.month));
  }

  void _openCampaign(
    BuildContext context,
    List<InvitationCampaign> campaigns,
    String campaignId,
    AppUserRole role,
  ) {
    final campaign = campaigns.firstWhere((item) => item.id == campaignId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: AlertDialog(
          content: SizedBox(
            width: 480,
            child: _CampaignCard(campaign: campaign, role: role),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCampaign(
    BuildContext context,
    WidgetRef ref,
    CurrentUserContext userContext,
  ) async {
    final organizations = userContext.role == AppUserRole.admin
        ? await ref.read(organizationsProvider.future)
        : const <Organization>[];
    if (!context.mounted) return;
    final draft = await showDialog<InvitationCampaignDraft>(
      context: context,
      builder: (_) => _CampaignDialog(
        fixedOrganizationId: userContext.organizationId,
        organizations: organizations
            .where((item) => item.kind == OrganizationKind.promoter)
            .toList(growable: false),
      ),
    );
    if (draft == null) return;
    try {
      await ref.read(invitationRepositoryProvider).create(draft);
      ref.invalidate(invitationCampaignsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campagne d’invitations créée.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible de créer cette campagne.'),
            ),
          ),
        );
      }
    }
  }
}

MaraudeCalendarItem _invitationCalendarItem(InvitationCampaign campaign) {
  return MaraudeCalendarItem(
    id: campaign.id,
    artist: campaign.title,
    date: campaign.eventDate!,
    venueName: campaign.venue?.name ?? 'Salle non renseignée',
    selectedVolunteerCount: campaign.attributedPlacesCount,
    statusLabel: campaign.status.label,
    tone: _invitationCalendarTone(campaign.status),
    countLabel: 'places attribuées',
    countTarget: campaign.availablePlaces,
  );
}

MaraudeCalendarTone _invitationCalendarTone(InvitationCampaignStatus status) =>
    switch (status) {
      InvitationCampaignStatus.draft => MaraudeCalendarTone.neutral,
      InvitationCampaignStatus.open => MaraudeCalendarTone.blue,
      InvitationCampaignStatus.closed => MaraudeCalendarTone.green,
      InvitationCampaignStatus.cancelled => MaraudeCalendarTone.error,
    };

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.campaign, required this.role});
  final InvitationCampaign campaign;
  final AppUserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(campaign.status.label)),
              ],
            ),
            if (campaign.organizationName != null)
              Text(campaign.organizationName!),
            const SizedBox(height: 8),
            _CampaignVenue(campaign: campaign),
            if (campaign.description != null) ...[
              const SizedBox(height: 8),
              Text(campaign.description!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '${_countLabel(campaign.remainingPlaces, 'place')} '
                  'restante${campaign.remainingPlaces > 1 ? 's' : ''}',
                ),
                Text(
                  '${campaign.attributedPlacesCount} '
                  '${campaign.attributedPlacesCount == 1 ? 'place attribuée' : 'places attribuées'}',
                ),
                if (campaign.applicationDeadline != null)
                  Text(
                    'Clôture : ${_date(campaign.applicationDeadline!.toLocal())}',
                  ),
                if (campaign.eventDate != null)
                  Text('Événement : ${_date(campaign.eventDate!)}'),
              ],
            ),
            const SizedBox(height: 14),
            if (role == AppUserRole.volunteer)
              _VolunteerCampaignAction(campaign: campaign)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => UncontrolledProviderScope(
                          container: ProviderScope.containerOf(context),
                          child: _CandidatesDialog(campaign: campaign),
                        ),
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Voir les candidatures'),
                    ),
                    if (campaign.status == InvitationCampaignStatus.draft)
                      OutlinedButton.icon(
                        key: ValueKey('open-invitation-${campaign.id}'),
                        onPressed: () => _changeStatus(
                          context,
                          ref,
                          InvitationCampaignStatus.open,
                        ),
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Ouvrir la campagne'),
                      ),
                    if (campaign.status == InvitationCampaignStatus.open)
                      OutlinedButton.icon(
                        key: ValueKey('close-invitation-${campaign.id}'),
                        onPressed: () => _changeStatus(
                          context,
                          ref,
                          InvitationCampaignStatus.closed,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Clôturer la campagne'),
                      ),
                    if (campaign.status == InvitationCampaignStatus.draft ||
                        campaign.status == InvitationCampaignStatus.open)
                      OutlinedButton.icon(
                        key: ValueKey('cancel-invitation-${campaign.id}'),
                        onPressed: () => _changeStatus(
                          context,
                          ref,
                          InvitationCampaignStatus.cancelled,
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler la campagne'),
                      ),
                    OutlinedButton.icon(
                      key: ValueKey('delete-invitation-${campaign.id}'),
                      onPressed: () => _deleteCampaign(context, ref),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Supprimer la campagne'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    InvitationCampaignStatus status,
  ) async {
    final verb = switch (status) {
      InvitationCampaignStatus.open => 'ouvrir',
      InvitationCampaignStatus.closed => 'clôturer',
      InvitationCampaignStatus.cancelled => 'annuler',
      InvitationCampaignStatus.draft => 'modifier',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(switch (status) {
          InvitationCampaignStatus.open => 'Ouvrir cette campagne ?',
          InvitationCampaignStatus.closed => 'Clôturer cette campagne ?',
          InvitationCampaignStatus.cancelled => 'Annuler cette campagne ?',
          InvitationCampaignStatus.draft => 'Modifier cette campagne ?',
        }),
        content: Text(
          'Confirmez-vous que vous souhaitez $verb la campagne '
          '« ${campaign.title} » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(invitationRepositoryProvider)
          .setCampaignStatus(campaign.id, status);
      ref.invalidate(invitationCampaignsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Campagne ${status.label.toLowerCase()}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de modifier cette campagne.'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteCampaign(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette campagne ?'),
        content: const Text(
          'La campagne et toutes les candidatures associées seront '
          'définitivement supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(invitationRepositoryProvider).deleteCampaign(campaign.id);
      ref.invalidate(invitationCampaignsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Campagne supprimée.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de supprimer cette campagne.'),
          ),
        ),
      );
    }
  }
}

class _VolunteerCampaignAction extends ConsumerStatefulWidget {
  const _VolunteerCampaignAction({required this.campaign});
  final InvitationCampaign campaign;

  @override
  ConsumerState<_VolunteerCampaignAction> createState() =>
      _VolunteerCampaignActionState();
}

class _VolunteerCampaignActionState
    extends ConsumerState<_VolunteerCampaignAction> {
  bool _saving = false;
  bool _plusOne = false;
  final _plusOneNameController = TextEditingController();

  @override
  void dispose() {
    _plusOneNameController.dispose();
    super.dispose();
  }

  Future<void> _act() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(invitationRepositoryProvider);
      final application = widget.campaign.ownApplication;
      if (application == null) {
        await repository.apply(
          widget.campaign.id,
          plusOne: _plusOne,
          plusOneName: _plusOneNameController.text,
        );
      } else if (application.status == InvitationApplicationStatus.pending) {
        await repository.withdraw(application.id);
      } else if (application.awaitsConfirmation) {
        await repository.confirm(application.id);
      }
      ref.invalidate(invitationCampaignsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Cette action n’a pas abouti.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPlusOne(InvitationApplication application) async {
    var plusOne = application.plusOne;
    final nameController = TextEditingController(
      text: application.plusOneName ?? '',
    );
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Accompagnant (+1)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: plusOne,
                onChanged: (value) =>
                    setDialogState(() => plusOne = value ?? false),
                title: const Text('Je viens accompagné.e (+1)'),
              ),
              if (plusOne)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l’accompagnant (facultatif)',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    final plusOneName = nameController.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
    if (updated != true || !mounted) return;
    try {
      await ref
          .read(invitationRepositoryProvider)
          .setPlusOne(
            application.id,
            plusOne: plusOne,
            plusOneName: plusOneName,
          );
      ref.invalidate(invitationCampaignsProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible de mettre à jour votre +1.'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.campaign.ownApplication;
    final creditCount = ref.watch(volunteerCreditCountProvider);
    if (application != null && application.isValidated) {
      return Text(
        'Invitation validée.${_plusOneSuffix(application)}',
        style: Theme.of(context).textTheme.titleSmall,
      );
    }
    if (application != null && application.awaitsConfirmation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invitation attribuée.${_plusOneSuffix(application)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            application.confirmationDueAt == null
                ? 'Confirmez votre participation pour la valider.'
                : 'Confirmez votre participation avant le '
                      '${formatFrenchDateTime(application.confirmationDueAt!)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const ValueKey('confirm-invitation-button'),
              onPressed: _saving ? null : _act,
              child: Text(_saving ? 'Enregistrement…' : 'Confirmer ma place'),
            ),
          ),
        ],
      );
    }
    if (application != null &&
        application.status != InvitationApplicationStatus.pending) {
      return Text(
        application.status.label,
        style: Theme.of(context).textTheme.titleSmall,
      );
    }
    final credits = creditCount.value;
    final isEligible = application != null || (credits != null && credits >= 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (application == null) ...[
          Text(
            credits == null
                ? 'Vérification de vos crédits…'
                : '$credits / 3 crédits nécessaires',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const ValueKey('apply-plus-one-checkbox'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _plusOne,
            onChanged: (value) => setState(() => _plusOne = value ?? false),
            title: const Text('Je viens accompagné.e (+1)'),
          ),
          if (_plusOne)
            TextField(
              key: const ValueKey('apply-plus-one-name-field'),
              controller: _plusOneNameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l’accompagnant (facultatif)',
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (application != null &&
            application.status == InvitationApplicationStatus.pending) ...[
          Text(
            application.plusOne
                ? 'Vous venez avec un +1'
                      '${application.plusOneName == null || application.plusOneName!.isEmpty ? '' : ' (${application.plusOneName})'}.'
                : 'Vous venez sans accompagnant.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _editPlusOne(application),
              child: const Text('Modifier mon +1'),
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed:
                _saving ||
                    !isEligible ||
                    widget.campaign.status != InvitationCampaignStatus.open
                ? null
                : _act,
            child: Text(
              _saving
                  ? 'Enregistrement…'
                  : application == null
                  ? 'Je candidate'
                  : 'Je me désiste',
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidatesDialog extends ConsumerWidget {
  const _CandidatesDialog({required this.campaign});
  final InvitationCampaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(invitationCandidatesProvider(campaign.id));
    return AlertDialog(
      title: Text(campaign.title),
      content: SizedBox(
        key: const ValueKey('candidates-dialog-content'),
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CampaignVenue(campaign: campaign),
            const Divider(height: 24),
            candidates.when(
              loading: () => const SizedBox(
                height: 160,
                child: AppLoadingState(label: 'Chargement des candidatures'),
              ),
              error: (_, _) => SizedBox(
                height: 160,
                child: AppErrorState(
                  message: 'Impossible de charger les candidatures.',
                  onRetry: () =>
                      ref.invalidate(invitationCandidatesProvider(campaign.id)),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text('Aucune candidature.')),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 440),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final candidate = items[index];
                          return _CandidateTile(
                            campaignId: campaign.id,
                            candidate: candidate,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _CandidateTile extends ConsumerStatefulWidget {
  const _CandidateTile({required this.campaignId, required this.candidate});
  final String campaignId;
  final InvitationCandidate candidate;

  @override
  ConsumerState<_CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends ConsumerState<_CandidateTile> {
  bool _saving = false;

  Future<void> _setStatus(InvitationApplicationStatus status) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(invitationRepositoryProvider)
          .setCandidateStatus(widget.candidate.applicationId, status);
      ref.invalidate(invitationCandidatesProvider(widget.campaignId));
      ref.invalidate(invitationCampaignsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_candidateStatusMessage(status))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible de modifier cette attribution.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeAttribution() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer l’attribution ?'),
        content: Text(
          'L’invitation attribuée à ${widget.candidate.displayName} '
          'repassera en attente de décision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer l’attribution'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _setStatus(InvitationApplicationStatus.pending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  candidate.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (candidate.plusOne)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(
                      candidate.plusOneName == null ||
                              candidate.plusOneName!.isEmpty
                          ? '+1'
                          : '+1 · ${candidate.plusOneName}',
                    ),
                  ),
                ),
              Chip(label: Text(_candidateChipLabel(candidate))),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('Membre depuis ${_date(candidate.memberSince)}'),
              Text(
                '${_countLabel(candidate.maraudeCount, 'maraude')} réalisée'
                '${candidate.maraudeCount > 1 ? 's' : ''}',
              ),
              Text(_countLabel(candidate.withdrawalCount, 'désistement')),
              Text(
                '${_countLabel(candidate.invitationCount, 'invitation')} '
                'obtenue${candidate.invitationCount > 1 ? 's' : ''}',
              ),
              Text(
                candidate.lastInvitationAt == null
                    ? 'Dernière invitation : —'
                    : 'Dernière invitation : '
                          '${_date(candidate.lastInvitationAt!)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(candidate.displayName),
                    content: Text(
                      '${_countLabel(candidate.maraudeCount, 'maraude')} '
                      'réalisée${candidate.maraudeCount > 1 ? 's' : ''}\n'
                      '${_countLabel(candidate.withdrawalCount, 'désistement')}\n'
                      '${_countLabel(candidate.invitationCount, 'invitation')} '
                      'obtenue${candidate.invitationCount > 1 ? 's' : ''}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
                      ),
                    ],
                  ),
                ),
                child: const Text('Voir le profil'),
              ),
              if (candidate.canManage) ...[
                if (candidate.status == InvitationApplicationStatus.selected)
                  OutlinedButton(
                    onPressed: _saving ? null : _removeAttribution,
                    child: const Text('Retirer l’attribution'),
                  )
                else ...[
                  FilledButton.tonal(
                    onPressed: _saving
                        ? null
                        : () =>
                              _setStatus(InvitationApplicationStatus.selected),
                    child: const Text('Attribuer'),
                  ),
                  if (candidate.status == InvitationApplicationStatus.pending)
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _setStatus(
                              InvitationApplicationStatus.notSelected,
                            ),
                      child: const Text('Ne pas attribuer'),
                    ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({
    required this.fixedOrganizationId,
    required this.organizations,
  });
  final String? fixedOrganizationId;
  final List<Organization> organizations;

  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _places = TextEditingController(text: '0');
  String? _organizationId;
  Venue? _selectedVenue;
  DateTime? _eventDate;
  InvitationCampaignStatus _status = InvitationCampaignStatus.open;

  @override
  void initState() {
    super.initState();
    _organizationId =
        widget.fixedOrganizationId ??
        (widget.organizations.isEmpty ? null : widget.organizations.first.id);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _places.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nouvelle campagne d’invitations'),
    content: SizedBox(
      width: 540,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.fixedOrganizationId == null)
                DropdownButtonFormField<String>(
                  initialValue: _organizationId,
                  decoration: const InputDecoration(labelText: 'Organisation'),
                  items: [
                    for (final organization in widget.organizations)
                      DropdownMenuItem(
                        value: organization.id,
                        child: Text(organization.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _organizationId = value),
                  validator: (value) =>
                      value == null ? 'L’organisation est obligatoire.' : null,
                ),
              const SizedBox(height: 12),
              VenueSearchField(
                inputKey: const ValueKey('invitation-venue-field'),
                onChanged: (venue) => setState(() => _selectedVenue = venue),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('invitation-event-date-field'),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _eventDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) setState(() => _eventDate = selected);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _eventDate == null
                        ? 'Date de l’événement'
                        : _date(_eventDate!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('invitation-title-field'),
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _places,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de places',
                ),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < 0
                      ? 'Saisissez un nombre positif ou nul.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<InvitationCampaignStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'État'),
                items: [
                  for (final status in [
                    InvitationCampaignStatus.draft,
                    InvitationCampaignStatus.open,
                  ])
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: (value) => setState(() => _status = value!),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        key: const ValueKey('invitation-submit-button'),
        onPressed: () {
          if (!_key.currentState!.validate() ||
              _organizationId == null ||
              _selectedVenue == null) {
            return;
          }
          Navigator.pop(
            context,
            InvitationCampaignDraft(
              organizationId: _organizationId!,
              venueId: _selectedVenue!.id,
              title: _title.text,
              description: _description.text,
              availablePlaces: int.parse(_places.text),
              eventDate: _eventDate,
              status: _status,
            ),
          );
        },
        child: const Text('Créer'),
      ),
    ],
  );
}

class _CampaignVenue extends StatelessWidget {
  const _CampaignVenue({required this.campaign});

  final InvitationCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final venue = campaign.venue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.location_on_outlined, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: venue == null
              ? const Text('Salle non renseignée')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      venue.formattedAddress,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _subtitle(AppUserRole? role) => switch (role) {
  AppUserRole.promoter =>
    'Créez les campagnes et suivez les décisions de Club Sandwich.',
  AppUserRole.volunteer =>
    'Candidatez aux places offertes par les partenaires.',
  _ => 'Attribuez les places parmi les candidatures reçues.',
};

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _countLabel(int count, String singular) =>
    '$count $singular${count > 1 ? 's' : ''}';

String _plusOneSuffix(InvitationApplication application) =>
    application.plusOne ? ' Avec +1.' : '';

String _candidateChipLabel(InvitationCandidate candidate) {
  if (candidate.status != InvitationApplicationStatus.selected) {
    return candidate.status.label;
  }
  return candidate.confirmationStatus == VolunteerConfirmationStatus.confirmed
      ? 'Invitation validée'
      : 'En attente de confirmation';
}

String _candidateStatusMessage(InvitationApplicationStatus status) =>
    switch (status) {
      InvitationApplicationStatus.pending =>
        'L’attribution a été retirée et la candidature remise en attente.',
      InvitationApplicationStatus.selected => 'Invitation attribuée.',
      InvitationApplicationStatus.notSelected =>
        'La candidature n’a pas été retenue.',
      InvitationApplicationStatus.withdrawn => 'Désistement enregistré.',
    };

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}
