import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/app_info.dart';
import 'package:vaultvoice/core/flavor_provider.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_router.dart';
import 'package:vaultvoice/core/theme/app_theme.dart';
import 'package:vaultvoice/features/app_lock/presentation/app_lock_gate.dart';
import 'package:vaultvoice/features/device_support/data/device_support_providers.dart';
import 'package:vaultvoice/features/device_support/presentation/unsupported_device_screen.dart';
import 'package:vaultvoice/features/models/data/download_providers.dart';
import 'package:vaultvoice/features/settings/presentation/crash_reports.dart';

/// Root widget: theme + router. Providers come from the enclosing scope.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Minimum CPU (ARMv8.2-A + dotprod, 2026-10-14): below it nothing else
    // is built — no router, no downloads, no recording.
    if (!ref.watch(deviceSupportedProvider)) {
      return MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const UnsupportedDeviceScreen(),
      );
    }
    // MDL-02: resume model downloads interrupted by an app kill.
    ref.listen(resumeModelDownloadsProvider, (_, _) {});
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: ref.watch(flavorProvider).isDev,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // REL-02: offer last run's crash report once, after the first frame.
      // SEC-03: the app lock covers everything (dialogs included).
      builder: (context, child) => AppLockGate(
        child: CrashReportGate(
          navigatorKey: router.routerDelegate.navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
