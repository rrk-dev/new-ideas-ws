import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';

/// Root widget: theme + router. Providers come from the enclosing scope.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: ref.watch(flavorProvider).isDev,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
