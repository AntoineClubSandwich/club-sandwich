import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      ref.read(passwordRecoveryProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour.')));
      context.go('/dashboard');
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = describeError(
            error,
            'Impossible de mettre à jour le mot de passe. Le lien est '
            'peut-être expiré.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_reset_outlined,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nouveau mot de passe',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('reset-password-password'),
                        controller: _password,
                        autofocus: true,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nouveau mot de passe',
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Utilisez au moins 8 caractères.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('reset-password-confirmation'),
                        controller: _confirmation,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe',
                        ),
                        validator: (value) => value != _password.text
                            ? 'Les mots de passe ne correspondent pas.'
                            : null,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const ValueKey('reset-password-submit'),
                        onPressed: _saving ? null : _submit,
                        child: Text(
                          _saving
                              ? 'Enregistrement…'
                              : 'Mettre à jour le mot de passe',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
