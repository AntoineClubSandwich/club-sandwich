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
    return Scaffold(
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
            return const AppEmptyState(
              title: 'Aucune organisation',
              message: 'Aucune organisation tourneur n’est enregistrée.',
              icon: Icons.business_outlined,
            );
          }
          final selectedId = _selectedId ?? promoters.first.id;
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 840) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                  children: [
                    _Header(count: promoters.length),
                    const SizedBox(height: 16),
                    for (final organization in promoters)
                      Card(
                        child: ListTile(
                          title: Text(organization.name),
                          subtitle: Text(
                            organization.contactEmail ??
                                organization.phone ??
                                'Aucun contact principal',
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
                        const SizedBox(height: 16),
                        for (final organization in promoters)
                          Card(
                            color: organization.id == selectedId
                                ? Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer
                                : null,
                            child: ListTile(
                              selected: organization.id == selectedId,
                              title: Text(organization.name),
                              subtitle: Text(organization.slug),
                              onTap: () =>
                                  setState(() => _selectedId = organization.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Organisations', style: Theme.of(context).textTheme.headlineMedium),
      Text('$count organisation${count > 1 ? 's' : ''} tourneur'),
    ],
  );
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
        if (value == null) return const Center(child: Text('Introuvable.'));
        final organization = value.organization;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    organization.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                PopupMenuButton<String>(
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
            const SizedBox(height: 12),
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
              action: TextButton.icon(
                onPressed: () => onAddContact(organization),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
              children: value.contacts.isEmpty
                  ? const [Text('Aucun contact.')]
                  : [
                      for (final contact in value.contacts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(
                            contact.displayName.isEmpty
                                ? 'Contact'
                                : contact.displayName,
                          ),
                          subtitle: Text(
                            [
                              contact.jobTitle,
                              contact.email,
                              contact.phone,
                            ].whereType<String>().join(' · '),
                          ),
                        ),
                    ],
            ),
            _SectionCard(
              title: 'Documents',
              action: TextButton.icon(
                onPressed: () => onAddDocument(organization),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
              children: value.documents.isEmpty
                  ? const [Text('Aucun document.')]
                  : [
                      for (final document in value.documents)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(document.name),
                          subtitle: SelectableText(document.url),
                        ),
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
                  spacing: 12,
                  runSpacing: 12,
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
  Widget build(BuildContext context) => Card(
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
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text('$label : ${_blank(value) ?? '—'}'),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.insights_outlined, size: 18),
    label: Text('$label : $value'),
  );
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
