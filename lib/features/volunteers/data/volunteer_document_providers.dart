import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final volunteerDocumentRepositoryProvider =
    Provider<VolunteerDocumentRepository>(
      (ref) => VolunteerDocumentRepository(ref.watch(supabaseClientProvider)),
    );

final myVolunteerDocumentsProvider = FutureProvider<List<VolunteerDocument>>((
  ref,
) {
  ref.watch(authStateProvider);
  return ref.watch(volunteerDocumentRepositoryProvider).fetchMyDocuments();
});

final volunteerDocumentsProvider =
    FutureProvider.family<List<VolunteerDocument>, String>((ref, userId) {
      ref.watch(authStateProvider);
      return ref
          .watch(volunteerDocumentRepositoryProvider)
          .fetchDocuments(userId);
    });

final pendingVolunteerDocumentsProvider =
    FutureProvider<List<PendingVolunteerDocument>>((ref) {
      ref.watch(authStateProvider);
      return ref
          .watch(volunteerDocumentRepositoryProvider)
          .fetchPendingDocuments();
    });
