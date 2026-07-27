import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/distributions/data/maraude_distribution_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maraudeDistributionRepositoryProvider =
    Provider<MaraudeDistributionRepository>(
      (ref) => MaraudeDistributionRepository(ref.watch(supabaseClientProvider)),
    );
