import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_private_profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart'
    show VolunteerCreditSummary;
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:club_sandwich/shared/widgets/document_template_download_link.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final userContext = ref.watch(currentUserContextProvider).value;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        children: [
          Text(
            userContext?.role == AppUserRole.promoter
                ? 'Mon compte'
                : 'Mon profil',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (userContext?.organizationName != null)
            Text(userContext!.organizationName!),
          const SizedBox(height: 20),
          profile.when(
            loading: () => const AppLoadingState(label: 'Chargement du profil'),
            error: (_, _) => AppErrorState(
              message: 'Impossible de charger votre profil.',
              onRetry: () => ref.invalidate(currentProfileProvider),
            ),
            data: (value) => value == null
                ? const AppEmptyState(
                    title: 'Profil introuvable',
                    message:
                        'Votre profil n’est pas disponible pour le moment.',
                    icon: Icons.person_off_outlined,
                  )
                : _ProfileForm(profile: value),
          ),
          if (userContext?.role == AppUserRole.volunteer) ...[
            const SizedBox(height: 16),
            const _VolunteerPrivateInformation(),
            const SizedBox(height: 16),
            const _VolunteerStatisticsCard(),
          ],
        ],
      ),
    );
  }
}

class _VolunteerPrivateInformation extends ConsumerWidget {
  const _VolunteerPrivateInformation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentVolunteerPrivateProfileProvider)
        .when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: AppLoadingState(label: 'Chargement des informations'),
            ),
          ),
          error: (_, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AppErrorState(
                message: 'Informations complémentaires indisponibles.',
                onRetry: () =>
                    ref.invalidate(currentVolunteerPrivateProfileProvider),
              ),
            ),
          ),
          data: (value) => _VolunteerPrivateForm(
            profile: value ?? const VolunteerPrivateProfile(),
          ),
        );
  }
}

class _VolunteerPrivateForm extends ConsumerStatefulWidget {
  const _VolunteerPrivateForm({required this.profile});
  final VolunteerPrivateProfile profile;

  @override
  ConsumerState<_VolunteerPrivateForm> createState() =>
      _VolunteerPrivateFormState();
}

class _VolunteerPrivateFormState extends ConsumerState<_VolunteerPrivateForm> {
  late final TextEditingController _additionalInformation;
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;
  late final TextEditingController _certifications;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _additionalInformation = TextEditingController(
      text: widget.profile.additionalInformation ?? '',
    );
    _emergencyName = TextEditingController(
      text: widget.profile.emergencyContactName ?? '',
    );
    _emergencyPhone = TextEditingController(
      text: widget.profile.emergencyContactPhone ?? '',
    );
    _certifications = TextEditingController(
      text: widget.profile.certifications.join(', '),
    );
  }

  @override
  void dispose() {
    _additionalInformation.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _certifications.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateCurrentVolunteerProfile(
            additionalInformation: _additionalInformation.text,
            emergencyContactName: _emergencyName.text,
            emergencyContactPhone: _emergencyPhone.text,
            certifications: _certifications.text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false),
          );
      ref.invalidate(currentVolunteerPrivateProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informations enregistrées.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(
                error,
                'Impossible d’enregistrer ces informations.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informations complémentaires',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Ces informations confidentielles sont accessibles uniquement '
            'par vous et les administrateurs Club Sandwich.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _additionalInformation,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Informations complémentaires',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyName,
            decoration: const InputDecoration(
              labelText: 'Contact d’urgence — nom',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emergencyPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact d’urgence — téléphone',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _certifications,
            decoration: const InputDecoration(
              labelText: 'Certifications',
              helperText: 'Séparez les certifications par une virgule.',
            ),
          ),
          const SizedBox(height: 16),
          Text('Mes documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const _MyDocumentsSection(),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MyDocumentsSection extends ConsumerWidget {
  const _MyDocumentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(myVolunteerDocumentsProvider);
    return documents.when(
      loading: () => const AppLoadingState(label: 'Chargement des documents'),
      error: (_, _) => AppErrorState(
        message: 'Documents indisponibles.',
        onRetry: () => ref.invalidate(myVolunteerDocumentsProvider),
      ),
      data: (items) {
        final identity = items
            .where((item) => item.type == VolunteerDocumentType.identity)
            .firstOrNull;
        final socialSecurity = items
            .where((item) => item.type == VolunteerDocumentType.socialSecurity)
            .firstOrNull;
        final contract = items
            .where((item) => item.type == VolunteerDocumentType.contract)
            .firstOrNull;
        final other = items
            .where((item) => item.type == VolunteerDocumentType.other)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MyDocumentTile(
                  type: VolunteerDocumentType.identity,
                  document: identity,
                ),
                _MyDocumentTile(
                  type: VolunteerDocumentType.socialSecurity,
                  document: socialSecurity,
                ),
                for (final document in other)
                  _MyDocumentTile(
                    type: VolunteerDocumentType.other,
                    document: document,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'Contrat de bénévolat',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const DocumentTemplateDownloadLink(
              templateKey: DocumentTemplateKey.volunteerContract,
            ),
            const SizedBox(height: 4),
            _MyDocumentTile(
              type: VolunteerDocumentType.contract,
              document: contract,
            ),
          ],
        );
      },
    );
  }
}

class _MyDocumentTile extends ConsumerStatefulWidget {
  const _MyDocumentTile({required this.type, this.document});
  final VolunteerDocumentType type;
  final VolunteerDocument? document;

  @override
  ConsumerState<_MyDocumentTile> createState() => _MyDocumentTileState();
}

class _MyDocumentTileState extends ConsumerState<_MyDocumentTile> {
  bool _uploading = false;

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    final extension = (file!.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    final userId = ref.read(currentUserContextProvider).value?.profileId;
    if (userId == null) return;
    setState(() => _uploading = true);
    try {
      final repository = ref.read(volunteerDocumentRepositoryProvider);
      final path = await repository.uploadFile(
        targetUserId: userId,
        bytes: file.bytes!,
        extension: extension,
        contentType: contentType,
      );
      await repository.submitMyDocument(
        type: widget.type,
        storagePath: path,
        documentId: widget.document?.id,
      );
      ref.invalidate(myVolunteerDocumentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document enregistré.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’envoyer ce document.'),
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
    final document = widget.document;
    final label = document?.displayLabel ?? widget.type.label;
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (document?.status) {
      VolunteerDocumentStatus.approved => (
        Icons.check_circle_outline,
        Colors.green,
      ),
      VolunteerDocumentStatus.rejected => (Icons.error_outline, colors.error),
      VolunteerDocumentStatus.pending when document?.hasFile == true => (
        Icons.hourglass_top_outlined,
        Colors.orange,
      ),
      _ => (Icons.upload_file, colors.outline),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: color),
          label: Text(
            document?.hasFile == true
                ? '$label — ${_statusLabel(document!)}'
                : 'Joindre $label',
          ),
        ),
        if (document?.status == VolunteerDocumentStatus.rejected &&
            document?.rejectionReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              document!.rejectionReason!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }

  String _statusLabel(VolunteerDocument document) {
    if (widget.type == VolunteerDocumentType.contract &&
        document.status == VolunteerDocumentStatus.pending) {
      return 'En attente de contre-signature';
    }
    return document.status.label;
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});
  final Profile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  final _key = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.profile.firstName);
    _lastName = TextEditingController(text: widget.profile.lastName);
    _phone = TextEditingController(text: widget.profile.phone ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateCurrentProfile(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’enregistrer le profil.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Informations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _VolunteerStatisticsCard extends ConsumerWidget {
  const _VolunteerStatisticsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(volunteerStatisticsProvider);
    final creditSummary = ref.watch(volunteerCreditSummaryProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: statistics.when(
          loading: () =>
              const AppLoadingState(label: 'Chargement des statistiques'),
          error: (_, _) => AppErrorState(
            message: 'Statistiques indisponibles.',
            onRetry: () => ref.invalidate(volunteerStatisticsProvider),
          ),
          data: (value) => value == null
              ? const Text('Aucune statistique disponible.')
              : _StatisticsContent(
                  value: value,
                  creditSummary: creditSummary.value,
                ),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.value, this.creditSummary});
  final VolunteerStatistics value;
  final VolunteerCreditSummary? creditSummary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Mon activité', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Metric('Membre depuis', _date(value.memberSince)),
          _Metric('Maraudes réalisées', '${value.maraudesCompleted}'),
          _Metric(
            'Heures de bénévolat',
            value.volunteeringHours.toStringAsFixed(1),
          ),
          _Metric('Invitations obtenues', '${value.invitationsObtained}'),
          _Metric(
            'Impact collectif',
            '${value.collectiveWeightKg.toStringAsFixed(1)} kg',
          ),
        ],
      ),
      if (creditSummary != null) ...[
        const SizedBox(height: 16),
        Text(
          'Mes crédits d’invitation',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric('Crédits disponibles', '${creditSummary!.available}'),
            _Metric('Crédits gagnés', '${creditSummary!.earned}'),
            _Metric('Crédits consommés', '${creditSummary!.consumed}'),
          ],
        ),
      ],
      if (value.roles.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Rôles exercés', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final role in value.roles.entries)
              Chip(label: Text('${_roleLabel(role.key)} : ${role.value}')),
          ],
        ),
      ],
      const SizedBox(height: 10),
      Text(
        'Ces informations sont indicatives et ne constituent ni un score '
        'ni un classement.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 160),
    child: Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

String _roleLabel(String value) => switch (value) {
  'team_leader' => 'Chef.fe d’équipe',
  'communication' => 'Communication',
  'logistics' => 'Logistique',
  _ => 'Récolte et distribution',
};

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}
