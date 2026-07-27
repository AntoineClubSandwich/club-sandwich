import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/collections/data/maraude_collection_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maraudeCollectionRepositoryProvider =
    Provider<MaraudeCollectionRepository>(
      (ref) => MaraudeCollectionRepository(ref.watch(supabaseClientProvider)),
    );
