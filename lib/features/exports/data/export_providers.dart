import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/exports/data/export_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exportRepositoryProvider = Provider<ExportRepository>(
  (ref) => ExportRepository(ref.watch(supabaseClientProvider)),
);
