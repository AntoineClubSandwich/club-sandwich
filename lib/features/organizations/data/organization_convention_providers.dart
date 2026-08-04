import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_convention_repository.dart';
import 'package:club_sandwich/features/organizations/domain/organization_convention.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final organizationConventionRepositoryProvider =
    Provider<OrganizationConventionRepository>(
      (ref) =>
          OrganizationConventionRepository(ref.watch(supabaseClientProvider)),
    );

final organizationConventionProvider =
    FutureProvider.family<OrganizationConvention?, String>((
      ref,
      organizationId,
    ) {
      ref.watch(authStateProvider);
      return ref
          .watch(organizationConventionRepositoryProvider)
          .fetch(organizationId);
    });
