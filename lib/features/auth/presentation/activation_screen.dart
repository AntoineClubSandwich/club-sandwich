import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/presentation/widgets/auth_card_layout.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _key = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentAuthUserProvider);
    _firstName.text = user?.userMetadata?['first_name'] as String? ?? '';
    _lastName.text = user?.userMetadata?['last_name'] as String? ?? '';
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_key.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      await ref
          .read(userAccountRepositoryProvider)
          .activateCurrentUser(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
          );
      final activatedContext = await ref.refresh(
        currentUserContextProvider.future,
      );
      if (activatedContext?.status != UserAccountStatus.active) {
        throw StateError('Le compte n’est pas actif après son activation.');
      }
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Compte activé.')));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) context.go('/dashboard');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(
                error,
                'L’activation a échoué. Le lien est peut-être expiré.',
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
  Widget build(BuildContext context) => Scaffold(
    body: AuthCardLayout(
      maxWidth: 520,
      pagePadding: const EdgeInsets.all(20),
      cardPadding: const EdgeInsets.all(24),
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bienvenue sur Club Sandwich',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            const Text(
              'Définissez votre mot de passe et complétez votre profil.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('activation-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              validator: (value) => value == null || value.length < 8
                  ? 'Utilisez au moins 8 caractères.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
              ),
              validator: (value) => value != _password.text
                  ? 'Les mots de passe ne correspondent pas.'
                  : null,
            ),
            const SizedBox(height: 12),
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
              decoration: const InputDecoration(
                labelText: 'Téléphone (optionnel)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _activate,
              child: Text(_saving ? 'Activation…' : 'Activer mon compte'),
            ),
          ],
        ),
      ),
    ),
  );
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
}
