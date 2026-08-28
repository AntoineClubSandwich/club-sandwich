enum AppEnvironment { production, preprod }

abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Public VAPID key for Web Push subscriptions. Not a secret: it is
  /// embedded in every subscription request and readable from devtools by
  /// design, so it is safe to compile directly into the client rather than
  /// threading it through Netlify env vars like the two keys above.
  static const vapidPublicKey =
      'BA6OtWbONf1dQfbs0IkSNPAng53hTPTD75s2zcm7LxrBhN4CtREflg9shP55gkaQd9ReaXugJ3c_h_ux0KFNMz0';
  static const _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static AppEnvironment get appEnvironment => resolveAppEnvironment(_appEnv);

  static bool get isPreproduction => appEnvironment == AppEnvironment.preprod;

  static AppEnvironment resolveAppEnvironment(String? value) {
    return value == 'preprod'
        ? AppEnvironment.preprod
        : AppEnvironment.production;
  }

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Les variables SUPABASE_URL et SUPABASE_ANON_KEY sont requises. '
        'Utilisez --dart-define pour les fournir.',
      );
    }
  }
}
