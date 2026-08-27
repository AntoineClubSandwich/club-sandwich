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

  // A URL carrying fresh auth tokens (`#access_token=...`) means someone
  // just clicked an invite/recovery link for a *specific* account. On
  // initialize(), supabase_flutter first restores whatever session this
  // browser already has persisted, then processes the link on top of it —
  // if that second step fails for any reason (network hiccup, a link that
  // was already exchanged once), the stale restored session silently
  // stays active instead. On a shared browser used to test several
  // accounts, that means clicking one person's link can land you in
  // whoever was last signed in here. Drop the stale session first, so
  // this load can only ever end up with the session the link itself
  // produces (or none at all).
  if (Uri.base.fragment.contains('access_token=')) {
    try {
      final host = Uri.parse(Environment.supabaseUrl).host.split('.').first;
      web.window.localStorage.removeItem('sb-$host-auth-token');
    } catch (_) {
      // Best-effort: storage can be unavailable (e.g. private browsing
      // with storage blocked). Falling through just means the pre-existing
      // race remains possible, not that startup fails.
    }
  }

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
