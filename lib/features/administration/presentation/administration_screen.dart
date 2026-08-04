import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/shared/data/document_template_providers.dart';
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:club_sandwich/shared/widgets/document_template_download_link.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdministrationScreen extends ConsumerWidget {
  const AdministrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(managedUsersProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _invite(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Inviter un utilisateur'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: [
          Text(
            'Administration',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text('Utilisateurs et accès à la plateforme.'),
          const SizedBox(height: 20),
          users.when(
            loading: () =>
                const AppLoadingState(label: 'Chargement des utilisateurs'),
            error: (_, _) => AppErrorState(
              message: 'Impossible de charger les utilisateurs.',
              onRetry: () => ref.invalidate(managedUsersProvider),
            ),
            data: (items) => items.isEmpty
                ? const AppEmptyState(
                    title: 'Aucun utilisateur',
                    message: 'Aucun utilisateur n’est encore enregistré.',
                    icon: Icons.manage_accounts_outlined,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 980
                        ? _UsersTable(users: items)
                        : Column(
                            children: [
                              for (final user in items) _UserCard(user: user),
                            ],
                          ),
                  ),
          ),
          const SizedBox(height: 24),
          const _DocumentTemplatesSection(),
        ],
      ),
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final organizations = await ref.read(organizationsProvider.future);
    if (!context.mounted) return;
    final draft = await showDialog<UserInvitationDraft>(
      context: context,
      builder: (_) => _InviteUserDialog(
        organizations: organizations
            .where((item) => item.kind == OrganizationKind.promoter)
            .toList(growable: false),
      ),
    );
    if (draft == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SendingInvitationDialog(),
    );
    try {
      final delivery = await ref
          .read(userAccountRepositoryProvider)
          .inviteUser(
            draft,
            redirectTo: Uri.base.resolve('/activate').toString(),
          );
      ref.invalidate(managedUsersProvider);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        if (!delivery.emailSent && delivery.activationUrl != null) {
          await _showActivationLink(context, delivery.activationUrl!);
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation envoyée.')));
      }
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(
                error,
                'Impossible d’envoyer l’invitation. '
                'Vérifiez l’adresse et réessayez.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showActivationLink(
    BuildContext context,
    String activationUrl,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Compte créé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La limite temporaire d’envoi d’e-mails est atteinte. '
              'Transmettez ce lien d’activation au bénévole :',
            ),
            const SizedBox(height: 12),
            SelectableText(activationUrl),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: activationUrl));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier le lien'),
          ),
        ],
      ),
    );
  }
}

class _SendingInvitationDialog extends StatelessWidget {
  const _SendingInvitationDialog();

  @override
  Widget build(BuildContext context) => const AlertDialog(
    content: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 16),
        Text('Envoi de l’invitation…'),
      ],
    ),
  );
}

class _DocumentTemplatesSection extends StatelessWidget {
  const _DocumentTemplatesSection();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modèles de documents',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Modèles vierges consultables par les bénévoles et les tourneurs.',
          ),
          const SizedBox(height: 12),
          const _TemplateRow(
            templateKey: DocumentTemplateKey.volunteerContract,
          ),
          const SizedBox(height: 8),
          const _TemplateRow(
            templateKey: DocumentTemplateKey.organizationConvention,
          ),
        ],
      ),
    ),
  );
}

class _TemplateRow extends ConsumerStatefulWidget {
  const _TemplateRow({required this.templateKey});
  final DocumentTemplateKey templateKey;

  @override
  ConsumerState<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends ConsumerState<_TemplateRow> {
  bool _uploading = false;

  Future<void> _replace() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final repository = ref.read(documentTemplateRepositoryProvider);
      final path = await repository.uploadFile(
        key: widget.templateKey,
        bytes: file!.bytes!,
        extension: 'pdf',
        contentType: 'application/pdf',
      );
      await repository.setTemplate(key: widget.templateKey, storagePath: path);
      ref.invalidate(documentTemplateProvider(widget.templateKey));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Modèle enregistré.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’enregistrer ce modèle.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = ref.watch(documentTemplateProvider(widget.templateKey));
    final hasTemplate = template.maybeWhen(
      data: (value) => value != null,
      orElse: () => false,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        SizedBox(width: 280, child: Text(widget.templateKey.label)),
        if (hasTemplate)
          DocumentTemplateDownloadLink(templateKey: widget.templateKey),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _replace,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(hasTemplate ? 'Remplacer' : 'Déposer'),
        ),
      ],
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({required this.users});
  final List<ManagedUser> users;

  @override
  Widget build(BuildContext context) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nom')),
          DataColumn(label: Text('Rôle')),
          DataColumn(label: Text('Organisation')),
          DataColumn(label: Text('Statut')),
          DataColumn(label: Text('Invitation')),
          DataColumn(label: Text('Dernière connexion')),
          DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final user in users)
            DataRow(
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(user.displayName), Text(user.email)],
                  ),
                ),
                DataCell(Text(user.role.label)),
                DataCell(Text(user.organizationName ?? '—')),
                DataCell(Chip(label: Text(user.status.label))),
                DataCell(Text(_date(user.invitedAt))),
                DataCell(Text(_date(user.lastSignInAt))),
                DataCell(_UserActions(user: user)),
              ],
            ),
        ],
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final ManagedUser user;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(child: Text(user.displayName.characters.first)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(user.email),
                Text('${user.role.label} · ${user.organizationName ?? '—'}'),
                Text(user.status.label),
              ],
            ),
          ),
          _UserActions(user: user),
        ],
      ),
    ),
  );
}

class _UserActions extends ConsumerStatefulWidget {
  const _UserActions({required this.user});
  final ManagedUser user;

  @override
  ConsumerState<_UserActions> createState() => _UserActionsState();
}

class _UserActionsState extends ConsumerState<_UserActions> {
  bool _saving = false;

  Future<void> _perform(String action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(userAccountRepositoryProvider);
      switch (action) {
        case 'resend':
          await repository.resendInvitation(
            widget.user.profileId,
            redirectTo: Uri.base.resolve('/activate').toString(),
          );
        case 'disable':
          await repository.setDisabled(widget.user.profileId, disabled: true);
        case 'reactivate':
          await repository.setDisabled(widget.user.profileId, disabled: false);
        case 'edit':
          final organizations = await ref.read(organizationsProvider.future);
          if (!mounted) return;
          final update = await showDialog<_UserRoleUpdate>(
            context: context,
            builder: (_) => _EditUserDialog(
              user: widget.user,
              organizations: organizations
                  .where((item) => item.kind == OrganizationKind.promoter)
                  .toList(growable: false),
            ),
          );
          if (update == null) return;
          await repository.updateUser(
            profileId: widget.user.profileId,
            role: update.role,
            organizationId: update.organizationId,
          );
      }
      ref.invalidate(managedUsersProvider);
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

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    enabled: !_saving,
    tooltip: 'Actions utilisateur',
    onSelected: _perform,
    itemBuilder: (_) => [
      if (widget.user.status == UserAccountStatus.invited)
        const PopupMenuItem(
          value: 'resend',
          child: Text('Renvoyer l’invitation'),
        ),
      if (widget.user.status != UserAccountStatus.disabled)
        const PopupMenuItem(value: 'disable', child: Text('Désactiver'))
      else
        const PopupMenuItem(value: 'reactivate', child: Text('Réactiver')),
      const PopupMenuItem(
        value: 'edit',
        child: Text('Modifier le rôle ou l’organisation'),
      ),
    ],
  );
}

class _InviteUserDialog extends StatefulWidget {
  const _InviteUserDialog({required this.organizations});
  final List<Organization> organizations;

  @override
  State<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<_InviteUserDialog> {
  final _key = GlobalKey<FormState>();
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  AppUserRole _role = AppUserRole.volunteer;
  String? _organizationId;
  bool _organizationAutoMatched = false;

  @override
  void initState() {
    super.initState();
    _email.addListener(_maybeAutoSelectOrganization);
  }

  @override
  void dispose() {
    _email.removeListener(_maybeAutoSelectOrganization);
    _lastName.dispose();
    _firstName.dispose();
    _email.dispose();
    super.dispose();
  }

  void _maybeAutoSelectOrganization() {
    if (_role != AppUserRole.promoter) return;
    // Only auto-fill: never override an organization the admin picked
    // themselves, whether or not it came from a previous auto-match.
    if (_organizationId != null && !_organizationAutoMatched) return;
    final email = _email.text.trim();
    Organization? match;
    for (final organization in widget.organizations) {
      if (organization.matchesEmailDomain(email)) {
        match = organization;
        break;
      }
    }
    setState(() {
      _organizationId = match?.id;
      _organizationAutoMatched = match != null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Inviter un utilisateur'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('invite-last-name'),
              controller: _lastName,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('invite-first-name'),
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('invite-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppUserRole>(
              key: const ValueKey('invite-role'),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(
                  value: AppUserRole.volunteer,
                  child: Text('Bénévole'),
                ),
                DropdownMenuItem(
                  value: AppUserRole.promoter,
                  child: Text('Tourneur'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _role = value!;
                  if (_role != AppUserRole.promoter) {
                    _organizationId = null;
                    _organizationAutoMatched = false;
                  }
                });
                if (_role == AppUserRole.promoter) {
                  _maybeAutoSelectOrganization();
                }
              },
            ),
            if (_role == AppUserRole.promoter) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('invite-organization'),
                initialValue: _organizationId,
                decoration: InputDecoration(
                  labelText: 'Organisation',
                  helperText: _organizationAutoMatched
                      ? 'Pré-sélectionnée d’après le domaine de l’adresse '
                            'e-mail.'
                      : null,
                ),
                items: [
                  for (final organization in widget.organizations)
                    DropdownMenuItem(
                      value: organization.id,
                      child: Text(organization.name),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _organizationId = value;
                  _organizationAutoMatched = false;
                }),
                validator: (value) => value == null
                    ? 'L’organisation est obligatoire pour un tourneur.'
                    : null,
              ),
            ],
          ],
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
            UserInvitationDraft(
              firstName: _firstName.text,
              lastName: _lastName.text,
              email: _email.text.trim(),
              role: _role,
              organizationId: _organizationId,
            ),
          );
        },
        child: const Text('Envoyer l’invitation'),
      ),
    ],
  );
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user, required this.organizations});
  final ManagedUser user;
  final List<Organization> organizations;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late AppUserRole _role;
  String? _organizationId;

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _organizationId = widget.user.organizationId;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.user.displayName),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<AppUserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: [
              for (final role in AppUserRole.values)
                DropdownMenuItem(value: role, child: Text(role.label)),
            ],
            onChanged: (value) => setState(() {
              _role = value!;
              if (_role != AppUserRole.promoter) _organizationId = null;
            }),
          ),
          if (_role == AppUserRole.promoter) ...[
            const SizedBox(height: 12),
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
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _role == AppUserRole.promoter && _organizationId == null
            ? null
            : () => Navigator.pop(
                context,
                _UserRoleUpdate(role: _role, organizationId: _organizationId),
              ),
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _UserRoleUpdate {
  const _UserRoleUpdate({required this.role, this.organizationId});
  final AppUserRole role;
  final String? organizationId;
}

String _date(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}

String? _emailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'L’adresse e-mail est obligatoire.';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'Saisissez une adresse e-mail valide.';
}
