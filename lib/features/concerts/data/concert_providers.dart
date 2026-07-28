import 'dart:async';

import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final maraudeOverviewProvider =
    FutureProvider.autoDispose<List<MaraudeOverview>>(
      (ref) => ref.watch(concertRepositoryProvider).fetchMaraudeOverview(),
    );

enum ConcertViewMode { list, agenda }

class ConcertViewModeNotifier extends Notifier<ConcertViewMode> {
  static const _preferenceKey = 'concerts_view_mode';
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

final concertViewModeProvider =
    NotifierProvider<ConcertViewModeNotifier, ConcertViewMode>(
      ConcertViewModeNotifier.new,
    );
