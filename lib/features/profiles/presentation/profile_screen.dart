import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart';
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Impossible de charger le profil.'),
              ),
            ),
            data: (value) => value == null
                ? const Text('Profil introuvable.')
                : _ProfileForm(profile: value),
          ),
          if (userContext?.role == AppUserRole.volunteer) ...[
            const SizedBox(height: 16),
            const _VolunteerStatisticsCard(),
          ],
        ],
      ),
    );
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d’enregistrer le profil.')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: statistics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Statistiques indisponibles.'),
          data: (value) => value == null
              ? const Text('Aucune statistique disponible.')
              : _StatisticsContent(value: value),
        ),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.value});
  final VolunteerStatistics value;

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
            '${value.collectiveWeightKg.toStringAsFixed(1)} kg · '
                '${value.collectiveMeals} repas',
          ),
        ],
      ),
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
