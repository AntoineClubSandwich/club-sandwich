import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final documentTemplateRepositoryProvider = Provider<DocumentTemplateRepository>(
  (ref) => DocumentTemplateRepository(ref.watch(supabaseClientProvider)),
);

final documentTemplateProvider =
    FutureProvider.family<DocumentTemplate?, DocumentTemplateKey>((ref, key) {
      return ref.watch(documentTemplateRepositoryProvider).fetch(key);
    });
