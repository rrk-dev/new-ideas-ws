import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/routing/app_shell.dart';
import 'package:vaultvoice/features/library/presentation/action_items_screen.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/library/presentation/recording_detail_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/models/presentation/models_screen.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

part 'app_routes.g.dart';

/// First-launch flow (APP-01), outside the tab shell. The router redirects
/// here until onboarding is completed.
@TypedGoRoute<OnboardingRoute>(path: '/onboarding')
class OnboardingRoute extends GoRouteData with $OnboardingRoute {
  const OnboardingRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const OnboardingScreen();
}

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
            TypedGoRoute<ActionItemsRoute>(path: 'action-items'),
            TypedGoRoute<RecordingStatusRoute>(
              path: 'recordings/:recordingId',
              routes: [TypedGoRoute<RecordingLinesRoute>(path: 'text')],
            ),
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

/// One recording (APP-02 detail: status, transcript, extraction, exports,
/// actions); notification deep-link target.
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
      RecordingDetailScreen(recordingId: recordingId);
}

/// Read-only transcript of a recording, optionally opened at position [t]
/// (ms) — APP-02 "show transcript", APP-05 source links.
class RecordingLinesRoute extends GoRouteData with $RecordingLinesRoute {
  const RecordingLinesRoute({required this.recordingId, this.t});

  final String recordingId;
  final int? t;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TranscriptLinesScreen(recordingId: recordingId, atMs: t);
}

/// Open action items across recordings (APP-02).
class ActionItemsRoute extends GoRouteData with $ActionItemsRoute {
  const ActionItemsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ActionItemsScreen();
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

/// Settings → Processing → Models: model management (MDL-03), including
/// the offline import entry (MDL-04).
class ModelsSettingsRoute extends GoRouteData with $ModelsSettingsRoute {
  const ModelsSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ModelsScreen();
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
