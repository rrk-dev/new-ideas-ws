import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/routing/app_shell.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';

part 'app_routes.g.dart';

@TypedStatefulShellRoute<AppShellRouteData>(
  branches: [
    TypedStatefulShellBranch<RecordBranchData>(
      routes: [TypedGoRoute<RecordRoute>(path: '/record')],
    ),
    TypedStatefulShellBranch<LibraryBranchData>(
      routes: [TypedGoRoute<LibraryRoute>(path: '/library')],
    ),
    TypedStatefulShellBranch<ProfilesBranchData>(
      routes: [TypedGoRoute<ProfilesRoute>(path: '/profiles')],
    ),
    TypedStatefulShellBranch<SettingsBranchData>(
      routes: [TypedGoRoute<SettingsRoute>(path: '/settings')],
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
