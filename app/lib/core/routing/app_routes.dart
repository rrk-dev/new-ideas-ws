import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultvoice/core/routing/app_shell.dart';
import 'package:vaultvoice/features/export/presentation/pending_exports_screen.dart';
import 'package:vaultvoice/features/export/presentation/routing_rule_editor_screen.dart';
import 'package:vaultvoice/features/export/presentation/vault_target_options_screen.dart';
import 'package:vaultvoice/features/library/presentation/action_items_screen.dart';
import 'package:vaultvoice/features/library/presentation/library_screen.dart';
import 'package:vaultvoice/features/library/presentation/recording_detail_screen.dart';
import 'package:vaultvoice/features/library/presentation/transcript_lines_screen.dart';
import 'package:vaultvoice/features/models/presentation/models_screen.dart';
import 'package:vaultvoice/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_queue_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profile_editor_screen.dart';
import 'package:vaultvoice/features/profiles/presentation/profiles_screen.dart';
import 'package:vaultvoice/features/recording/presentation/recording_screen.dart';
import 'package:vaultvoice/features/review/presentation/review_screen.dart';
import 'package:vaultvoice/features/review/presentation/review_settings_screen.dart';
import 'package:vaultvoice/features/settings/presentation/settings_screen.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';
import 'package:vaultvoice/features/templates/presentation/template_editor_screen.dart';
import 'package:vaultvoice/features/templates/presentation/templates_screen.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_screen.dart';

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
              routes: [
                // STT-06 viewer/editor and APP-02's read-only lines view.
                TypedGoRoute<TranscriptRoute>(path: 'transcript'),
                TypedGoRoute<RecordingLinesRoute>(path: 'text'),
                // APP-05 review before export.
                TypedGoRoute<RecordingReviewRoute>(path: 'review'),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<ProfilesBranchData>(
      routes: [
        TypedGoRoute<ProfilesRoute>(
          path: '/profiles',
          routes: [
            TypedGoRoute<ProfileNewRoute>(path: 'new'),
            TypedGoRoute<ProfileEditRoute>(path: ':profileId'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<SettingsBranchData>(
      routes: [
        TypedGoRoute<SettingsRoute>(
          path: '/settings',
          routes: [
            TypedGoRoute<ModelsSettingsRoute>(path: 'models'),
            TypedGoRoute<VaultFoldersRoute>(
              path: 'vault-folders',
              routes: [
                TypedGoRoute<VaultTargetOptionsRoute>(path: ':targetId'),
              ],
            ),
            TypedGoRoute<PendingExportsRoute>(path: 'pending-exports'),
            TypedGoRoute<RoutingRulesRoute>(
              path: 'routing-rules',
              routes: [TypedGoRoute<RoutingRuleEditorRoute>(path: ':ruleId')],
            ),
            TypedGoRoute<TemplatesRoute>(
              path: 'templates',
              routes: [TypedGoRoute<TemplateEditorRoute>(path: ':templateId')],
            ),
            TypedGoRoute<ReviewSettingsRoute>(path: 'review'),
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

/// Review & edit a recording's extracted result before export (APP-05).
class RecordingReviewRoute extends GoRouteData with $RecordingReviewRoute {
  const RecordingReviewRoute({required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ReviewScreen(recordingId: recordingId);
}

/// Settings › Export › Review before export, per profile (APP-05).
class ReviewSettingsRoute extends GoRouteData with $ReviewSettingsRoute {
  const ReviewSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ReviewSettingsScreen();
}

/// Open action items across recordings (APP-02).
class ActionItemsRoute extends GoRouteData with $ActionItemsRoute {
  const ActionItemsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ActionItemsScreen();
}

/// Transcript viewer & editor of one recording (STT-06), optionally opened
/// at position [t] (ms): scrolled there and playing from it (APP-02 "show in
/// transcript", APP-05 source links — integration wave 3).
class TranscriptRoute extends GoRouteData with $TranscriptRoute {
  const TranscriptRoute({required this.recordingId, this.t});

  final String recordingId;
  final int? t;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TranscriptScreen(recordingId: recordingId, atMs: t);
}

class ProfilesRoute extends GoRouteData with $ProfilesRoute {
  const ProfilesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfilesScreen();
}

/// Custom profile editor, new profile (PRF-07).
class ProfileNewRoute extends GoRouteData with $ProfileNewRoute {
  const ProfileNewRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileEditorScreen();
}

/// A profile in the editor (read-only for built-in / managed ones).
class ProfileEditRoute extends GoRouteData with $ProfileEditRoute {
  const ProfileEditRoute({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ProfileEditorScreen(profileId: profileId);
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

/// Settings → Vault folders → one folder's export options (EXP-05).
class VaultTargetOptionsRoute extends GoRouteData
    with $VaultTargetOptionsRoute {
  const VaultTargetOptionsRoute({required this.targetId});

  final String targetId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      VaultTargetOptionsScreen(targetId: targetId);
}

/// Settings → Routing rules → edit one rule; `ruleId` [kNewRuleId] adds
/// a rule (EXP-05).
class RoutingRuleEditorRoute extends GoRouteData with $RoutingRuleEditorRoute {
  const RoutingRuleEditorRoute({required this.ruleId});

  final String ruleId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      RoutingRuleEditorScreen(ruleId: ruleId);
}

/// Settings → Pending exports: the export outbox (EXP-06).
class PendingExportsRoute extends GoRouteData with $PendingExportsRoute {
  const PendingExportsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PendingExportsScreen();
}

/// Settings → Templates (EXP-07).
class TemplatesRoute extends GoRouteData with $TemplatesRoute {
  const TemplatesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const TemplatesScreen();
}

/// Settings → Templates → one template (built-in read-only or custom).
class TemplateEditorRoute extends GoRouteData with $TemplateEditorRoute {
  const TemplateEditorRoute({required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TemplateEditorScreen(templateId: templateId);
}
