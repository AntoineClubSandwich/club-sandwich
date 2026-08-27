import 'package:club_sandwich/app.dart';
import 'package:club_sandwich/core/config/auth_redirect.dart';
import 'package:club_sandwich/core/config/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Environment.validate();

  await Supabase.initialize(
    url: Environment.supabaseUrl,
    publishableKey: Environment.supabaseAnonKey,
  );

  // When an invite/recovery link can't be exchanged for a session (most
  // often because it expired), Supabase Auth redirects back to
  // authRedirectUrl() with `?error=...&error_code=...` instead of a usable
  // fragment. Capture that now, before it's lost, so LoginScreen can show
  // the volunteer something actionable instead of a silent, unexplained
  // login form.
  initialAuthErrorMessage = describeAuthErrorFromUri(Uri.base);

  // Supabase Auth delivers invite/recovery sessions via the URL fragment
  // (`#access_token=...&type=recovery`), but this app also routes with a
  // `#/...` hash strategy. supabase_flutter has already consumed the
  // fragment for session detection by the time initialize() resolves, so
  // strip it now — otherwise GoRouter reads the raw token string as an
  // (invalid) route on its very first build and overwrites the URL,
  // destroying the tokens before anything else can use them.
  final fragment = Uri.base.fragment;
  final hasErrorQuery = Uri.base.queryParameters.containsKey('error');
  if ((fragment.isNotEmpty && !fragment.startsWith('/')) || hasErrorQuery) {
    web.window.history.replaceState(
      null,
      '',
      Uri.base.replace(fragment: '', query: '').toString(),
    );
  }

  runApp(const ProviderScope(child: ClubSandwichApp()));
}
