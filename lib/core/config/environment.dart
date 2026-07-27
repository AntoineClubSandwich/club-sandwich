enum AppEnvironment { production, preprod }

abstract final class Environment {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
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
