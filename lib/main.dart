import 'package:club_sandwich/app.dart';
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

  // Supabase Auth delivers invite/recovery sessions via the URL fragment
  // (`#access_token=...&type=recovery`), but this app also routes with a
  // `#/...` hash strategy. supabase_flutter has already consumed the
  // fragment for session detection by the time initialize() resolves, so
  // strip it now — otherwise GoRouter reads the raw token string as an
  // (invalid) route on its very first build and overwrites the URL,
  // destroying the tokens before anything else can use them.
  final fragment = Uri.base.fragment;
  if (fragment.isNotEmpty && !fragment.startsWith('/')) {
    web.window.history.replaceState(
      null,
      '',
      Uri.base.replace(fragment: '').toString(),
    );
  }

  runApp(const ProviderScope(child: ClubSandwichApp()));
}
