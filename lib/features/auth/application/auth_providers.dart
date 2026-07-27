import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/data/auth_repository.dart';
import 'package:club_sandwich/features/auth/data/user_account_repository.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

final currentAuthUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user ??
      ref.watch(authRepositoryProvider).currentUser;
});

final userAccountRepositoryProvider = Provider<UserAccountRepository>(
  (ref) => UserAccountRepository(ref.watch(supabaseClientProvider)),
);

final currentUserContextProvider = FutureProvider<CurrentUserContext?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userAccountRepositoryProvider).fetchCurrentContext();
});

final managedUsersProvider = FutureProvider<List<ManagedUser>>(
  (ref) => ref.watch(userAccountRepositoryProvider).fetchManagedUsers(),
);
