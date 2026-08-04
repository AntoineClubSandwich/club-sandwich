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

/// Tracks whether the current session came from a password-recovery link.
///
/// Supabase establishes a *real* authenticated session as soon as the
/// recovery link is opened, so the router can't just check "is
/// authenticated" to decide whether to show the reset-password screen —
/// it would send the user straight to the dashboard. This latches to
/// `true` on the `passwordRecovery` event and stays there (ignoring
/// unrelated events like token refreshes) until [clear] is called once
/// the new password has actually been saved.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateProvider, (previous, next) {
      final event = next.value?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        state = true;
      } else if (event == AuthChangeEvent.signedOut) {
        state = false;
      }
    });
    return false;
  }

  void clear() => state = false;
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, bool>(
      PasswordRecoveryNotifier.new,
    );

final userAccountRepositoryProvider = Provider<UserAccountRepository>(
  (ref) => UserAccountRepository(ref.watch(supabaseClientProvider)),
);

final currentUserContextProvider = FutureProvider<CurrentUserContext?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userAccountRepositoryProvider).fetchCurrentContext();
});

final managedUsersProvider = FutureProvider<List<ManagedUser>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userAccountRepositoryProvider).fetchManagedUsers();
});
