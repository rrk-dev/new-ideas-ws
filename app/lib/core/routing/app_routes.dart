import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_shell.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/models/presentation/model_import_tile.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

part 'app_routes.g.dart';

@TypedStatefulShellRoute<AppShellRouteData>(
  branches: [
    TypedStatefulShellBranch<RecordBranchData>(
      routes: [TypedGoRoute<RecordRoute>(path: '/record')],
    ),
    TypedStatefulShellBranch<LibraryBranchData>(
      routes: [
        TypedGoRoute<LibraryRoute>(
          path: '/library',
          routes: [
            TypedGoRoute<ProcessingQueueRoute>(path: 'processing'),
            TypedGoRoute<RecordingStatusRoute>(path: 'recordings/:recordingId'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<ProfilesBranchData>(
      routes: [TypedGoRoute<ProfilesRoute>(path: '/profiles')],
    ),
    TypedStatefulShellBranch<SettingsBranchData>(
      routes: [
        TypedGoRoute<SettingsRoute>(
          path: '/settings',
          routes: [
            TypedGoRoute<ModelsSettingsRoute>(path: 'models'),
            TypedGoRoute<VaultFoldersRoute>(path: 'vault-folders'),
            TypedGoRoute<RoutingRulesRoute>(path: 'routing-rules'),
          ],
        ),
      ],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  const AppShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => AppShell(navigationShell: navigationShell);
}

class RecordBranchData extends StatefulShellBranchData {
  const RecordBranchData();
}

class LibraryBranchData extends StatefulShellBranchData {
  const LibraryBranchData();
}

class ProfilesBranchData extends StatefulShellBranchData {
  const ProfilesBranchData();
}

class SettingsBranchData extends StatefulShellBranchData {
  const SettingsBranchData();
}

class RecordRoute extends GoRouteData with $RecordRoute {
  const RecordRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RecordScreen();
}

class LibraryRoute extends GoRouteData with $LibraryRoute {
  const LibraryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LibraryScreen();
}

/// Every job still in the pipeline (target of the global queue indicator).
class ProcessingQueueRoute extends GoRouteData with $ProcessingQueueRoute {
  const ProcessingQueueRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProcessingQueueScreen();
}

/// Processing status of one recording; notification deep-link target.
/// APP-02/APP-05 grow it into the full recording detail.
class RecordingStatusRoute extends GoRouteData with $RecordingStatusRoute {
  const RecordingStatusRoute({required this.recordingId});

  final String recordingId;

  /// Whether [location] is a deep link this app's notifications produce
  /// (`/library/recordings/<id>` or `/library/processing`). Anything else
  /// from a notification payload is ignored.
  static bool isNotificationTarget(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasQuery) {
      return false;
    }
    final s = uri.pathSegments;
    if (s.length == 2) return s[0] == 'library' && s[1] == 'processing';
    return s.length == 3 &&
        s[0] == 'library' &&
        s[1] == 'recordings' &&
        RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(s[2]);
  }

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RecordingStatusScreen(recordingId: recordingId);
}

class ProfilesRoute extends GoRouteData with $ProfilesRoute {
  const ProfilesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfilesScreen();
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

/// Settings → Processing → Models. Until model management (MDL-03)
/// provides the full screen it hosts the offline import entry (MDL-04).
class ModelsSettingsRoute extends GoRouteData with $ModelsSettingsRoute {
  const ModelsSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.settingsModels)),
    body: ListView(children: const [ModelImportTile()]),
  );
}

class VaultFoldersRoute extends GoRouteData with $VaultFoldersRoute {
  const VaultFoldersRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const VaultFoldersScreen();
}

class RoutingRulesRoute extends GoRouteData with $RoutingRulesRoute {
  const RoutingRulesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const RoutingRulesScreen();
}
