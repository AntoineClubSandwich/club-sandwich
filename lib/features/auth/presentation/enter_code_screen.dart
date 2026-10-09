import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/presentation/widgets/auth_card_layout.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Fallback entry point for when an invite/recovery link never works —
/// most often because a corporate mail gateway visited it first and burnt
/// the one-time token before the person's own click. The same e-mail
/// carries a 6-digit code the link doesn't expose to that kind of
/// automated prefetch, since nothing but the person can type it in here.
class EnterCodeScreen extends ConsumerStatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  ConsumerState<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends ConsumerState<EnterCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmailCode(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
          );
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = describeError(
            error,
            'Ce code n’est plus valide. Demandez-en un nouveau.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthCardLayout(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.pin_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Entrer un code reçu par e-mail',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            const Text(
              'Si le lien de votre e-mail d’invitation ou de '
              'réinitialisation ne fonctionne pas, utilisez le code à 6 '
              'chiffres fourni dans ce même e-mail.',
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('enter-code-email'),
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('enter-code-code'),
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Code à 6 chiffres',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length != 6
                        ? 'Saisissez le code à 6 chiffres.'
                        : null,
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _submit();
                    },
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              key: const ValueKey('enter-code-submit'),
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continuer'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : () => context.go('/login'),
              child: const Text('Retour à la connexion'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
  final separator = email.indexOf('@');
  final lastDot = email.lastIndexOf('.');
  if (separator <= 0 ||
      separator == email.length - 1 ||
      lastDot <= separator + 1 ||
      lastDot == email.length - 1) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
}
