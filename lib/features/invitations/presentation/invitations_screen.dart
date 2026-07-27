import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userContext = ref.watch(currentUserContextProvider).value;
    final campaigns = ref.watch(invitationCampaignsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          userContext?.role == AppUserRole.admin ||
              userContext?.role == AppUserRole.promoter
          ? FloatingActionButton.extended(
              onPressed: () => _createCampaign(context, ref, userContext!),
              icon: const Icon(Icons.add),
              label: const Text('Ouvrir des invitations'),
            )
          : null,
      body: campaigns.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(invitationCampaignsProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
          children: [
            Text(
              userContext?.role == AppUserRole.promoter
                  ? 'Mes invitations'
                  : 'Invitations',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(_subtitle(userContext?.role)),
            const SizedBox(height: 20),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune campagne d’invitations.'),
                ),
              )
            else
              for (final campaign in items)
                _CampaignCard(
                  campaign: campaign,
                  role: userContext?.role ?? AppUserRole.volunteer,
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
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de créer cette campagne.')),
        );
      }
    }
  }
}

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
            if (campaign.description != null) ...[
              const SizedBox(height: 8),
              Text(campaign.description!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${campaign.availablePlaces} place(s)'),
                Text('${campaign.applicationCount} candidature(s)'),
                Text('${campaign.selectedCount} attribuée(s)'),
                if (campaign.applicationDeadline != null)
                  Text(
                    'Clôture : ${_date(campaign.applicationDeadline!.toLocal())}',
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (role == AppUserRole.volunteer)
              _VolunteerCampaignAction(campaign: campaign)
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
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
              ),
          ],
        ),
      ),
    );
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

  Future<void> _act() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(invitationRepositoryProvider);
      final application = widget.campaign.ownApplication;
      if (application == null) {
        await repository.apply(widget.campaign.id);
      } else if (application.status == InvitationApplicationStatus.pending) {
        await repository.withdraw(application.id);
      }
      ref.invalidate(invitationCampaignsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cette action n’a pas abouti.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.campaign.ownApplication;
    if (application != null &&
        application.status != InvitationApplicationStatus.pending) {
      return Text(
        application.status.label,
        style: Theme.of(context).textTheme.titleSmall,
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed:
            _saving || widget.campaign.status != InvitationCampaignStatus.open
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
        width: 760,
        height: 520,
        child: candidates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text('Impossible de charger les candidatures.'),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('Aucune candidature.'))
              : ListView.separated(
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
    } finally {
      if (mounted) setState(() => _saving = false);
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
              Chip(label: Text(candidate.status.label)),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('Membre depuis ${_date(candidate.memberSince)}'),
              Text('${candidate.maraudeCount} maraude(s)'),
              Text('${candidate.withdrawalCount} désistement(s)'),
              Text('${candidate.invitationCount} invitation(s) obtenue(s)'),
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
                      '${candidate.maraudeCount} maraude(s)\n'
                      '${candidate.withdrawalCount} désistement(s)\n'
                      '${candidate.invitationCount} invitation(s) obtenue(s)',
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
                FilledButton.tonal(
                  onPressed: _saving
                      ? null
                      : () => _setStatus(InvitationApplicationStatus.selected),
                  child: const Text('Attribuer'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () =>
                            _setStatus(InvitationApplicationStatus.notSelected),
                  child: const Text('Ne pas attribuer'),
                ),
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
    title: const Text('Ouvrir des invitations'),
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
              TextFormField(
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
        onPressed: () {
          if (!_key.currentState!.validate() || _organizationId == null) return;
          Navigator.pop(
            context,
            InvitationCampaignDraft(
              organizationId: _organizationId!,
              title: _title.text,
              description: _description.text,
              availablePlaces: int.parse(_places.text),
              status: _status,
            ),
          );
        },
        child: const Text('Créer'),
      ),
    ],
  );
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

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}
