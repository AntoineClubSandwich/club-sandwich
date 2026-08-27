import 'dart:async';

import 'package:club_sandwich/core/supabase/realtime_invalidation.dart';
import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart'
    show ConcertViewMode;
import 'package:club_sandwich/features/invitations/data/invitation_repository.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(ref.watch(supabaseClientProvider)),
);

final invitationCampaignsProvider = FutureProvider<List<InvitationCampaign>>((
  ref,
) {
  ref.watch(authStateProvider);
  final repository = ref.watch(invitationRepositoryProvider);
  watchRealtimeInvalidation(
    ref: ref,
    client: repository.client,
    channelName: 'invitation-campaigns',
    watches: const [
      RealtimeWatch('invitation_campaigns'),
      RealtimeWatch('invitation_applications'),
    ],
  );
  return repository.fetchCampaigns();
});

final invitationCandidatesProvider =
    FutureProvider.family<List<InvitationCandidate>, String>((ref, campaignId) {
      ref.watch(authStateProvider);
      final repository = ref.watch(invitationRepositoryProvider);
      watchRealtimeInvalidation(
        ref: ref,
        client: repository.client,
        channelName: 'invitation-candidates-$campaignId',
        watches: [
          RealtimeWatch(
            'invitation_applications',
            filterColumn: 'campaign_id',
            filterValue: campaignId,
          ),
        ],
      );
      return repository.fetchCandidates(campaignId);
    });

class InvitationViewModeNotifier extends Notifier<ConcertViewMode> {
  static const _preferenceKey = 'invitations_view_mode';
  bool _selectionMade = false;

  @override
  ConcertViewMode build() {
    unawaited(_restore());
    return ConcertViewMode.list;
  }

  void select(ConcertViewMode mode) {
    _selectionMade = true;
    state = mode;
    unawaited(_persist(mode));
  }

  Future<void> _restore() async {
    try {
      final stored = await SharedPreferencesAsync().getString(_preferenceKey);
      if (!ref.mounted || _selectionMade) return;
      state = stored == ConcertViewMode.agenda.name
          ? ConcertViewMode.agenda
          : ConcertViewMode.list;
    } catch (_) {
      // Une préférence locale indisponible ne doit jamais bloquer l’écran.
    }
  }

  Future<void> _persist(ConcertViewMode mode) async {
    try {
      await SharedPreferencesAsync().setString(_preferenceKey, mode.name);
    } catch (_) {
      // La vue courante reste mémorisée en session si le stockage échoue.
    }
  }
}

final invitationViewModeProvider =
    NotifierProvider<InvitationViewModeNotifier, ConcertViewMode>(
      InvitationViewModeNotifier.new,
    );
