import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Session? get session => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    required String redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Establishes a session directly from the 6-digit code an invite or
  /// recovery e-mail carries alongside its link — the fallback for when
  /// the link itself never reaches the person (a corporate mail gateway
  /// that prefetches links can silently burn a one-time token before they
  /// ever click it themselves; a typed code has nothing for it to consume).
  /// We don't ask which kind of code it is: try it as an invite code, and
  /// only fall back to recovery if that's rejected.
  Future<void> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.invite,
      );
    } on AuthException {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
    }
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }
}
