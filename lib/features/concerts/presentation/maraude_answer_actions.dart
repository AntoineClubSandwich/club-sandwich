import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-tap answer to an open maraude straight from its card — the same
/// "Je me propose" / "Je ne suis pas disponible" choice as the maraude's
/// detail screen, without having to open it first.
class MaraudeAnswerActions extends ConsumerStatefulWidget {
  const MaraudeAnswerActions({required this.maraude, super.key});

  final MaraudeOverview maraude;

  @override
  ConsumerState<MaraudeAnswerActions> createState() =>
      _MaraudeAnswerActionsState();
}

class _MaraudeAnswerActionsState extends ConsumerState<MaraudeAnswerActions> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isUnavailable = widget.maraude.isOwnUnavailable;
    return Wrap(
      spacing: DsSpacing.sm,
      runSpacing: DsSpacing.sm,
      children: [
        FilledButton(
          key: ValueKey('card-apply-${widget.maraude.concertId}'),
          onPressed: _isSubmitting ? null : _apply,
          child: const Text('Je me propose'),
        ),
        if (isUnavailable)
          TextButton(
            key: ValueKey('card-clear-unavailable-${widget.maraude.concertId}'),
            onPressed: _isSubmitting ? null : () => _setUnavailable(false),
            child: const Text('Annuler mon indisponibilité'),
          )
        else
          OutlinedButton(
            key: ValueKey('card-set-unavailable-${widget.maraude.concertId}'),
            onPressed: _isSubmitting ? null : () => _setUnavailable(true),
            child: const Text('Je ne suis pas disponible'),
          ),
      ],
    );
  }

  Future<void> _apply() => _submit(
    (repository) => repository.apply(widget.maraude.concertId),
    success:
        'Votre volontariat a été enregistré.\n\n'
        'Vous serez informé si vous êtes sélectionné.',
    failure: 'Impossible d’enregistrer votre volontariat. Veuillez réessayer.',
  );

  Future<void> _setUnavailable(bool unavailable) => _submit(
    (repository) => repository.setUnavailable(
      widget.maraude.concertId,
      unavailable: unavailable,
    ),
    success: unavailable
        ? 'Indisponibilité enregistrée.'
        : 'Indisponibilité retirée.',
    failure: 'Impossible d’enregistrer votre réponse.',
  );

  Future<void> _submit(
    Future<void> Function(ConcertVolunteerRepository repository) action, {
    required String success,
    required String failure,
  }) async {
    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(ref.read(concertVolunteerRepositoryProvider));
      ref.invalidate(maraudeOverviewProvider);
      ref.invalidate(concertVolunteerSectionProvider(widget.maraude.concertId));
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, failure))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
