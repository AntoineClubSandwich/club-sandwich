import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/organizations/data/membership_repository.dart';
import 'package:club_sandwich/features/organizations/data/organization_repository.dart';
import 'package:club_sandwich/features/organizations/domain/membership.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>(
  (ref) => OrganizationRepository(ref.watch(supabaseClientProvider)),
);

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(ref.watch(supabaseClientProvider)),
);

final organizationsProvider = FutureProvider<List<Organization>>(
  (ref) => ref.watch(organizationRepositoryProvider).fetchOrganizations(),
);

final membershipsProvider = FutureProvider.family<List<Membership>, String>((
  ref,
  organizationId,
) {
  return ref
      .watch(membershipRepositoryProvider)
      .fetchForOrganization(organizationId);
});

final organizationDetailsProvider =
    FutureProvider.family<OrganizationDetails?, String>((ref, organizationId) {
      return ref
          .watch(organizationRepositoryProvider)
          .fetchDetails(organizationId);
    });
