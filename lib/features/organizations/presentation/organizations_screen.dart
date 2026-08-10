import 'package:club_sandwich/design_system/components/buttons/ds_ghost_button.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_avatar.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/organizations/presentation/organization_convention_panel.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() =>
      _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final organizations = ref.watch(organizationsProvider);
    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editOrganization(),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
        body: organizations.when(
          loading: () =>
              const AppLoadingState(label: 'Chargement des organisations'),
          error: (_, _) => AppErrorState(
            message: 'Impossible de charger les organisations.',
            onRetry: () => ref.invalidate(organizationsProvider),
          ),
          data: (items) {
            final promoters = items
                .where((item) => item.kind == OrganizationKind.promoter)
                .toList(growable: false);
            if (promoters.isEmpty) {
              return const _EmptyOrganizations();
            }
            final selectedId = _selectedId ?? promoters.first.id;
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 840) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                    children: [
                      _Header(count: promoters.length),
                      const SizedBox(height: DsSpacing.lg),
                      for (final organization in promoters)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpacing.md),
                          child: _OrganizationListItem(
                            organization: organization,
                            onTap: () => _showMobileDetails(organization),
                          ),
                        ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 320,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _Header(count: promoters.length),
                          const SizedBox(height: DsSpacing.lg),
                          for (final organization in promoters)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.md,
                              ),
                              child: _OrganizationListItem(
                                organization: organization,
                                selected: organization.id == selectedId,
                                onTap: () => setState(
                                  () => _selectedId = organization.id,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final colors = Theme.of(
                          context,
                        ).extension<DsTokens>()!.colors;
                        return VerticalDivider(width: 1, color: colors.border);
                      },
                    ),
                    Expanded(
                      child: _OrganizationDetailsPane(
                        organizationId: selectedId,
                        onEdit: _editOrganization,
                        onDelete: _deleteOrganization,
                        onAddContact: _addContact,
                        onAddDocument: _addDocument,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showMobileDetails(Organization organization) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: _OrganizationDetailsPane(
            organizationId: organization.id,
            onEdit: _editOrganization,
            onDelete: _deleteOrganization,
            onAddContact: _addContact,
            onAddDocument: _addDocument,
          ),
        ),
      ),
    );
  }

  Future<void> _editOrganization([Organization? organization]) async {
    final draft = await showDialog<OrganizationDraft>(
      context: context,
      builder: (_) => _OrganizationFormDialog(organization: organization),
    );
    if (draft == null) return;
    try {
      final repository = ref.read(organizationRepositoryProvider);
      final saved = organization == null
          ? await repository.create(draft)
          : await repository.update(organization.id, draft);
      ref.invalidate(organizationsProvider);
      ref.invalidate(organizationDetailsProvider(saved.id));
      if (mounted) setState(() => _selectedId = saved.id);
    } catch (error) {
      if (mounted) {
        _message(
          describeError(error, 'Impossible d’enregistrer cette organisation.'),
        );
      }
    }
  }

  Future<void> _deleteOrganization(Organization organization) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’organisation ?'),
        content: const Text(
          'Ses contacts et documents seront supprimés. Cette action échouera '
          'si des utilisateurs ou des données métier y sont encore rattachés.',
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
    if (confirmed != true) return;
    try {
      await ref.read(organizationRepositoryProvider).delete(organization.id);
      ref.invalidate(organizationsProvider);
      if (mounted) setState(() => _selectedId = null);
    } catch (error) {
      if (mounted) {
        _message(
          describeError(
            error,
            'Cette organisation est encore utilisée et ne peut pas être '
            'supprimée.',
          ),
        );
      }
    }
  }

  Future<void> _addContact(Organization organization) async {
    final values = await showDialog<List<String?>>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (values == null) return;
    try {
      await ref
          .read(organizationRepositoryProvider)
          .addContact(
            organization.id,
            firstName: values[0]!,
            lastName: values[1]!,
            jobTitle: values[2],
            email: values[3],
            phone: values[4],
          );
      ref.invalidate(organizationDetailsProvider(organization.id));
    } catch (error) {
      if (mounted) {
        _message(describeError(error, 'Impossible d’ajouter ce contact.'));
      }
    }
  }

  Future<void> _addDocument(Organization organization) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _DocumentDialog(),
    );
    if (values == null) return;
    try {
      await ref
          .read(organizationRepositoryProvider)
          .addDocument(organization.id, name: values[0], url: values[1]);
      ref.invalidate(organizationDetailsProvider(organization.id));
    } catch (error) {
      if (mounted) {
        _message(describeError(error, 'Impossible d’ajouter ce document.'));
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Organisations',
          style: DsTypography.h2.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          '$count organisation${count > 1 ? 's' : ''} tourneur',
          style: DsTypography.body.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyOrganizations extends StatelessWidget {
  const _EmptyOrganizations();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClubSandwichMascot(size: 96, color: MascotColor.orange),
            const SizedBox(height: DsSpacing.lg),
            Text(
              'Aucune organisation',
              style: DsTypography.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              'Aucune organisation tourneur n’est enregistrée.',
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationListItem extends StatelessWidget {
  const _OrganizationListItem({
    required this.organization,
    required this.onTap,
    this.selected = false,
  });

  final Organization organization;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final subtitle =
        organization.contactEmail ??
        organization.phone ??
        'Aucun contact principal';
    return Container(
      decoration: selected
          ? BoxDecoration(
              border: Border(left: BorderSide(color: colors.primary, width: 4)),
            )
          : null,
      child: DsCard(
        onTap: onTap,
        elevated: selected,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    organization.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Icon(DsIcons.chevronRight, size: 18, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _OrganizationDetailsPane extends ConsumerWidget {
  const _OrganizationDetailsPane({
    required this.organizationId,
    required this.onEdit,
    required this.onDelete,
    required this.onAddContact,
    required this.onAddDocument,
  });

  final String organizationId;
  final ValueChanged<Organization> onEdit;
  final ValueChanged<Organization> onDelete;
  final ValueChanged<Organization> onAddContact;
  final ValueChanged<Organization> onAddDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(organizationDetailsProvider(organizationId));
    return details.when(
      loading: () =>
          const AppLoadingState(label: 'Chargement de l’organisation'),
      error: (_, _) => AppErrorState(
        message: 'Impossible de charger cette organisation.',
        onRetry: () =>
            ref.invalidate(organizationDetailsProvider(organizationId)),
      ),
      data: (value) {
        final colors = Theme.of(context).extension<DsTokens>()!.colors;
        if (value == null) {
          return Center(
            child: Text(
              'Introuvable.',
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
          );
        }
        final organization = value.organization;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    organization.name,
                    style: DsTypography.h2.copyWith(color: colors.textPrimary),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colors.textSecondary),
                  onSelected: (action) => action == 'edit'
                      ? onEdit(organization)
                      : onDelete(organization),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            _SectionCard(
              title: 'Informations',
              children: [
                _Value('Adresse', organization.address),
                _Value('E-mail', organization.contactEmail),
                _Value('Téléphone', organization.phone),
                _Value('Site web', organization.websiteUrl),
                _Value('Notes', organization.notes),
              ],
            ),
            _SectionCard(
              title: 'Contacts',
              action: DsGhostButton(
                icon: DsIcons.plus,
                label: 'Ajouter',
                onPressed: () => onAddContact(organization),
              ),
              children: value.contacts.isEmpty
                  ? [_EmptySectionLabel('Aucun contact.')]
                  : [
                      for (final contact in value.contacts)
                        _ContactRow(contact: contact),
                    ],
            ),
            _SectionCard(
              title: 'Documents',
              action: DsGhostButton(
                icon: DsIcons.plus,
                label: 'Ajouter',
                onPressed: () => onAddDocument(organization),
              ),
              children: value.documents.isEmpty
                  ? [_EmptySectionLabel('Aucun document.')]
                  : [
                      for (final document in value.documents)
                        _DocumentRow(document: document),
                    ],
            ),
            _SectionCard(
              title: 'Convention de partenariat',
              children: [
                OrganizationConventionPanel(organizationId: organization.id),
              ],
            ),
            _SectionCard(
              title: 'Concerts, historique et statistiques',
              children: [
                Wrap(
                  spacing: DsSpacing.sm,
                  runSpacing: DsSpacing.sm,
                  children: [
                    _Metric('Concerts', value.concertCount.toString()),
                    _Metric(
                      'Maraudes terminées',
                      value.completedMaraudeCount.toString(),
                    ),
                    _Metric(
                      'Poids collecté',
                      '${value.totalWeightKg.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OrganizationFormDialog extends StatefulWidget {
  const _OrganizationFormDialog({this.organization});
  final Organization? organization;

  @override
  State<_OrganizationFormDialog> createState() =>
      _OrganizationFormDialogState();
}

class _OrganizationFormDialogState extends State<_OrganizationFormDialog> {
  final _key = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final value = widget.organization;
    _controllers = [
      TextEditingController(text: value?.name ?? ''),
      TextEditingController(text: value?.slug ?? ''),
      TextEditingController(text: value?.emailDomain ?? ''),
      TextEditingController(text: value?.contactEmail ?? ''),
      TextEditingController(text: value?.phone ?? ''),
      TextEditingController(text: value?.address ?? ''),
      TextEditingController(text: value?.websiteUrl ?? ''),
      TextEditingController(text: value?.notes ?? ''),
    ];
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.organization == null
          ? 'Nouvelle organisation'
          : 'Modifier l’organisation',
    ),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(0, 'Nom', required: true, autofocus: true),
              _field(1, 'Identifiant (slug)', required: true),
              _field(
                2,
                'Domaine e-mail (ex. auguri.fr)',
                helper:
                    'Un compte Tourneur invité avec une adresse de ce '
                    'domaine se voit proposer cette organisation '
                    'automatiquement.',
                validator: _domainValidator,
              ),
              _field(3, 'Adresse e-mail'),
              _field(4, 'Téléphone'),
              _field(5, 'Adresse'),
              _field(6, 'Site web'),
              _field(7, 'Notes', maxLines: 3),
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
          if (!_key.currentState!.validate()) return;
          Navigator.pop(
            context,
            OrganizationDraft(
              name: _controllers[0].text,
              slug: _controllers[1].text,
              emailDomain: _controllers[2].text,
              contactEmail: _controllers[3].text,
              phone: _controllers[4].text,
              address: _controllers[5].text,
              websiteUrl: _controllers[6].text,
              notes: _controllers[7].text,
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );

  Widget _field(
    int index,
    String label, {
    bool required = false,
    bool autofocus = false,
    int maxLines = 1,
    String? helper,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _controllers[index],
      autofocus: autofocus,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, helperText: helper),
      validator:
          validator ??
          (required
              ? (value) => value == null || value.trim().isEmpty
                    ? '$label est obligatoire.'
                    : null
              : null),
    ),
  );
}

String? _domainValidator(String? value) {
  final domain = value?.trim() ?? '';
  if (domain.isEmpty) return null;
  final isValidDomain = RegExp(
    r'^[a-z0-9.-]+\.[a-z]{2,}$',
  ).hasMatch(domain.toLowerCase());
  return isValidDomain
      ? null
      : 'Saisissez un domaine valide, ex. auguri.fr (sans @).';
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _controllers = List.generate(5, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter un contact'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in [
            'Prénom',
            'Nom',
            'Fonction',
            'E-mail',
            'Téléphone',
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _controllers[entry.$1],
                decoration: InputDecoration(labelText: entry.$2),
              ),
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
        onPressed: () => Navigator.pop(
          context,
          _controllers.map((controller) => _blank(controller.text)).toList(),
        ),
        child: const Text('Ajouter'),
      ),
    ],
  );
}

class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog();
  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajouter un document'),
    content: Form(
      key: _key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Lien'),
            validator: _required,
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
          if (_key.currentState!.validate()) {
            Navigator.pop(context, [_name.text.trim(), _url.text.trim()]);
          }
        },
        child: const Text('Ajouter'),
      ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.action,
  });
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: DsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: DsTypography.h3.copyWith(color: colors.textPrimary),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: DsSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _EmptySectionLabel extends StatelessWidget {
  const _EmptySectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Text(
      text,
      style: DsTypography.body.copyWith(color: colors.textSecondary),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: RichText(
        text: TextSpan(
          style: DsTypography.body.copyWith(color: colors.textPrimary),
          children: [
            TextSpan(
              text: '$label : ',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: _blank(value) ?? '—'),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DsBadge(label: '$label : $value');
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final OrganizationContact contact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final subtitle = [
      contact.jobTitle,
      contact.email,
      contact.phone,
    ].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        children: [
          DsAvatar(
            initials: contact.displayName.isEmpty
                ? '?'
                : contact.displayName.characters.first.toUpperCase(),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.displayName.isEmpty ? 'Contact' : contact.displayName,
                  style: DsTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});
  final OrganizationDocument document;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(DsIcons.fileDown, size: 18, color: colors.textSecondary),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  document.name,
                  style: DsTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SelectableText(
                  document.url,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _blank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}
