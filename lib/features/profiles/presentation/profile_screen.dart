import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_secondary_button.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_avatar.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_metric_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
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
import 'package:club_sandwich/shared/widgets/inline_document_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final userContext = ref.watch(currentUserContextProvider).value;
    // Wrapped in a local DsTheme.light regardless of the ambient theme:
    // several widget tests pump ProfileScreen without the app-wide theme.
    return Theme(
      data: DsTheme.light,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<DsTokens>()!.colors;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              children: [
                Text(
                  userContext?.role == AppUserRole.promoter
                      ? 'Mon compte'
                      : 'Mon profil',
                  style: DsTypography.h2.copyWith(color: colors.textPrimary),
                ),
                if (userContext?.organizationName != null)
                  Text(
                    userContext!.organizationName!,
                    style: DsTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                const SizedBox(height: DsSpacing.lg),
                profile.when(
                  loading: () =>
                      const AppLoadingState(label: 'Chargement du profil'),
                  error: (_, _) => AppErrorState(
                    message: 'Impossible de charger votre profil.',
                    onRetry: () => ref.invalidate(currentProfileProvider),
                  ),
                  data: (value) => value == null
                      ? const _EmptyProfile()
                      : _ProfileForm(profile: value),
                ),
                if (userContext?.role == AppUserRole.volunteer) ...[
                  const SizedBox(height: DsSpacing.md),
                  const _VolunteerPrivateInformation(),
                  const SizedBox(height: DsSpacing.md),
                  const _VolunteerStatisticsCard(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClubSandwichMascot(size: 96),
            const SizedBox(height: DsSpacing.lg),
            Text(
              'Profil introuvable',
              style: DsTypography.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              'Votre profil n’est pas disponible pour le moment.',
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
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
          loading: () => const DsCard(
            child: AppLoadingState(label: 'Chargement des informations'),
          ),
          error: (_, _) => DsCard(
            child: AppErrorState(
              message: 'Informations complémentaires indisponibles.',
              onRetry: () =>
                  ref.invalidate(currentVolunteerPrivateProfileProvider),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Informations complémentaires',
            style: DsTypography.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Ces informations confidentielles sont accessibles uniquement '
            'par vous et les administrateurs Club Sandwich.',
            style: DsTypography.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpacing.md),
          TextField(
            controller: _additionalInformation,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Informations complémentaires',
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: _emergencyName,
            decoration: const InputDecoration(
              labelText: 'Contact d’urgence — nom',
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: _emergencyPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact d’urgence — téléphone',
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: _certifications,
            decoration: const InputDecoration(
              labelText: 'Certifications',
              helperText: 'Séparez les certifications par une virgule.',
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            'Mes documents',
            style: DsTypography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          const _MyDocumentsSection(),
          const SizedBox(height: DsSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: DsPrimaryButton(
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              label: 'Enregistrer',
            ),
          ),
        ],
      ),
    );
  }
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
        final colors = Theme.of(context).extension<DsTokens>()!.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MyDocumentTile(
              type: VolunteerDocumentType.identity,
              document: identity,
            ),
            const SizedBox(height: DsSpacing.sm),
            _MyDocumentTile(
              type: VolunteerDocumentType.socialSecurity,
              document: socialSecurity,
            ),
            for (final document in other) ...[
              const SizedBox(height: DsSpacing.sm),
              _MyDocumentTile(
                type: VolunteerDocumentType.other,
                document: document,
              ),
            ],
            const SizedBox(height: DsSpacing.md),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: DsSpacing.md),
            Text(
              'Contrat de bénévolat',
              style: DsTypography.body.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final icon = switch (document?.status) {
      VolunteerDocumentStatus.approved => DsIcons.circleCheck,
      VolunteerDocumentStatus.rejected => DsIcons.circleX,
      VolunteerDocumentStatus.pending when document?.hasFile == true =>
        DsIcons.clock,
      _ => DsIcons.upload,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DsSecondaryButton(
          onPressed: _uploading ? null : _upload,
          isLoading: _uploading,
          icon: icon,
          label: document?.hasFile == true
              ? '$label — ${_statusLabel(document!)}'
              : 'Joindre $label',
        ),
        if (document?.storagePath case final path?)
          InlineDocumentPreview(
            storagePath: path,
            title: label,
            loadSignedUrl: () =>
                ref.read(volunteerDocumentRepositoryProvider).signedUrl(path),
          ),
        if (document?.status == VolunteerDocumentStatus.rejected &&
            document?.rejectionReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              document!.rejectionReason!,
              style: DsTypography.caption.copyWith(color: colors.error),
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
  bool _uploadingAvatar = false;

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

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    if (file!.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La photo ne doit pas dépasser 5 Mo.')),
      );
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .uploadCurrentAvatar(bytes: file.bytes!, contentType: contentType);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil enregistrée.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’enregistrer la photo.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return DsCard(
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Informations',
              style: DsTypography.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                DsAvatar(
                  initials: _profileInitials(widget.profile),
                  imageUrl: widget.profile.avatarUrl,
                  size: DsAvatarSize.lg,
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Photo de profil',
                        style: DsTypography.body.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG ou WebP · 5 Mo maximum',
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                DsSecondaryButton(
                  onPressed: _uploadingAvatar ? null : _uploadAvatar,
                  isLoading: _uploadingAvatar,
                  icon: Icons.add_a_photo_outlined,
                  label: widget.profile.avatarUrl == null
                      ? 'Ajouter'
                      : 'Modifier',
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: _required,
            ),
            const SizedBox(height: DsSpacing.sm),
            TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: _required,
            ),
            const SizedBox(height: DsSpacing.sm),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            const SizedBox(height: DsSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: DsPrimaryButton(
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                label: 'Enregistrer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _profileInitials(Profile profile) {
  final values = [
    profile.firstName,
    profile.lastName,
  ].map((value) => value.trim()).where((value) => value.isNotEmpty).take(2);
  final initials = values.map((value) => value.characters.first).join();
  return initials.isEmpty ? '?' : initials;
}

class _VolunteerStatisticsCard extends ConsumerWidget {
  const _VolunteerStatisticsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(volunteerStatisticsProvider);
    final creditSummary = ref.watch(volunteerCreditSummaryProvider);
    return statistics.when(
      loading: () => const DsCard(
        child: AppLoadingState(label: 'Chargement des statistiques'),
      ),
      error: (_, _) => DsCard(
        child: AppErrorState(
          message: 'Statistiques indisponibles.',
          onRetry: () => ref.invalidate(volunteerStatisticsProvider),
        ),
      ),
      data: (value) => value == null
          ? Builder(
              builder: (context) {
                final colors = Theme.of(context).extension<DsTokens>()!.colors;
                return Text(
                  'Aucune statistique disponible.',
                  style: DsTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                );
              },
            )
          : _StatisticsContent(
              value: value,
              creditSummary: creditSummary.value,
            ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.value, this.creditSummary});
  final VolunteerStatistics value;
  final VolunteerCreditSummary? creditSummary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mon activité',
          style: DsTypography.h3.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: DsSpacing.sm),
        _MetricsRow(
          metrics: [
            ('Membre depuis', _date(value.memberSince)),
            ('Maraudes réalisées', '${value.maraudesCompleted}'),
            ('Heures de bénévolat', value.volunteeringHours.toStringAsFixed(1)),
            ('Invitations obtenues', '${value.invitationsObtained}'),
            (
              'Impact collectif',
              '${value.collectiveWeightKg.toStringAsFixed(1)} kg',
            ),
          ],
        ),
        if (creditSummary != null) ...[
          const SizedBox(height: DsSpacing.md),
          Text(
            'Mes crédits d’invitation',
            style: DsTypography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          _MetricsRow(
            metrics: [
              ('Crédits disponibles', '${creditSummary!.available}'),
              ('Crédits gagnés', '${creditSummary!.earned}'),
              ('Crédits consommés', '${creditSummary!.consumed}'),
            ],
          ),
        ],
        if (value.roles.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.md),
          Text(
            'Rôles exercés',
            style: DsTypography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              for (final role in value.roles.entries)
                DsBadge(label: '${_roleLabel(role.key)} : ${role.value}'),
            ],
          ),
        ],
        const SizedBox(height: DsSpacing.sm),
        Text(
          'Ces informations sont indicatives et ne constituent ni un score '
          'ni un classement.',
          style: DsTypography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.metrics});
  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DsSpacing.sm,
    runSpacing: DsSpacing.sm,
    children: [
      for (final (label, value) in metrics)
        SizedBox(
          width: 160,
          child: DsMetricCard(label: label, value: value),
        ),
    ],
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
