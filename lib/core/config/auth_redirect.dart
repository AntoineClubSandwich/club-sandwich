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
