import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:flutter/material.dart';
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: FilledButton.icon(
                onPressed: () => ref.invalidate(managedUsersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun utilisateur.'),
                    ),
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
    if (draft == null) return;
    try {
      await ref
          .read(userAccountRepositoryProvider)
          .inviteUser(
            draft,
            redirectTo: Uri.base.resolve('/activate').toString(),
          );
      ref.invalidate(managedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation envoyée.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d’envoyer l’invitation. Vérifiez l’adresse et réessayez.',
            ),
          ),
        );
      }
    }
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

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _email.dispose();
    super.dispose();
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
              onChanged: (value) => setState(() {
                _role = value!;
                if (_role != AppUserRole.promoter) _organizationId = null;
              }),
            ),
            if (_role == AppUserRole.promoter) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('invite-organization'),
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
