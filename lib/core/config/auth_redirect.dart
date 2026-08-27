/// Returns the stable browser callback used by Supabase Auth.
///
/// Club Sandwich uses hash-based Flutter Web routes. Supabase also uses the
/// URL fragment while establishing an Auth session, so application routes such
/// as `#/activate` must not be used as Auth callbacks. Once the session exists,
/// GoRouter sends invited accounts to `/activate` and password-recovery
/// sessions to `/reset-password`.
String authRedirectUrl([Uri? browserUri]) {
  final uri = browserUri ?? Uri.base;
  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: '/',
  ).toString();
}

/// Set once at startup (see `main.dart`) from any `?error=...` query
/// parameters Supabase Auth appends to [authRedirectUrl] when an
/// invite/recovery link couldn't be exchanged for a session (most often
/// because it expired). `LoginScreen` reads and clears this on its first
/// build so the message doesn't linger past that one display.
String? initialAuthErrorMessage;

/// Translates Supabase Auth's `error_code` query parameter into a message
/// a volunteer can act on. Returns null when [uri] carries no auth error.
String? describeAuthErrorFromUri(Uri uri) {
  final errorCode = uri.queryParameters['error_code'];
  if (errorCode == null) return null;
  return switch (errorCode) {
    'otp_expired' =>
      'Ce lien a expiré. Demandez-en un nouveau depuis « Mot de passe oublié ? ».',
    _ => 'Ce lien n’est plus valide. Demandez-en un nouveau.',
  };
}
