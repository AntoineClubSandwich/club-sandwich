import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final concertRepositoryProvider = Provider<ConcertRepository>(
  (ref) => ConcertRepository(ref.watch(supabaseClientProvider)),
);

final concertsProvider = FutureProvider<List<Concert>>(
  (ref) => ref.watch(concertRepositoryProvider).fetchConcerts(),
);

final concertDetailsProvider = FutureProvider.family<Concert?, String>(
  (ref, concertId) =>
      ref.watch(concertRepositoryProvider).fetchConcert(concertId),
);
