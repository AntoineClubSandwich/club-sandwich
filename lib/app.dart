import 'package:club_sandwich/core/config/environment.dart';
import 'package:club_sandwich/core/router/app_router.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/shared/widgets/environment_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClubSandwichApp extends ConsumerWidget {
  const ClubSandwichApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Club Sandwich',
      debugShowCheckedModeBanner: false,
      theme: DsTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => AppEnvironmentBanner(
        environment: Environment.appEnvironment,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
