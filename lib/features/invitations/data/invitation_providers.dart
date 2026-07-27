import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/invitations/data/invitation_repository.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(ref.watch(supabaseClientProvider)),
);

final invitationCampaignsProvider = FutureProvider<List<InvitationCampaign>>(
  (ref) => ref.watch(invitationRepositoryProvider).fetchCampaigns(),
);

final invitationCandidatesProvider =
    FutureProvider.family<List<InvitationCandidate>, String>(
      (ref, campaignId) =>
          ref.watch(invitationRepositoryProvider).fetchCandidates(campaignId),
    );
