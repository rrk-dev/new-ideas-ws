// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$onboardingRoute, $appShellRouteData];

RouteBase get $onboardingRoute => GoRouteData.$route(
  path: '/onboarding',
  hasOverriddenOnExit: false,
  factory: $OnboardingRoute._fromState,
);

mixin $OnboardingRoute on GoRouteData {
  static OnboardingRoute _fromState(GoRouterState state) =>
      const OnboardingRoute();

  @override
  String get location => GoRouteData.$location('/onboarding');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
  factory: $AppShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/record',
          hasOverriddenOnExit: false,
          factory: $RecordRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/library',
          hasOverriddenOnExit: false,
          factory: $LibraryRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'processing',
              hasOverriddenOnExit: false,
              factory: $ProcessingQueueRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'recordings/:recordingId',
              hasOverriddenOnExit: false,
              factory: $RecordingStatusRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'transcript',
                  hasOverriddenOnExit: false,
                  factory: $TranscriptRoute._fromState,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/profiles',
          hasOverriddenOnExit: false,
          factory: $ProfilesRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'new',
              hasOverriddenOnExit: false,
              factory: $ProfileNewRoute._fromState,
            ),
            GoRouteData.$route(
              path: ':profileId',
              hasOverriddenOnExit: false,
              factory: $ProfileEditRoute._fromState,
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/settings',
          hasOverriddenOnExit: false,
          factory: $SettingsRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'models',
              hasOverriddenOnExit: false,
              factory: $ModelsSettingsRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'vault-folders',
              hasOverriddenOnExit: false,
              factory: $VaultFoldersRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: ':targetId',
                  hasOverriddenOnExit: false,
                  factory: $VaultTargetOptionsRoute._fromState,
                ),
              ],
            ),
            GoRouteData.$route(
              path: 'pending-exports',
              hasOverriddenOnExit: false,
              factory: $PendingExportsRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'routing-rules',
              hasOverriddenOnExit: false,
              factory: $RoutingRulesRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: ':ruleId',
                  hasOverriddenOnExit: false,
                  factory: $RoutingRuleEditorRoute._fromState,
                ),
              ],
            ),
            GoRouteData.$route(
              path: 'templates',
              hasOverriddenOnExit: false,
              factory: $TemplatesRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: ':templateId',
                  hasOverriddenOnExit: false,
                  factory: $TemplateEditorRoute._fromState,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) =>
      const AppShellRouteData();
}

mixin $RecordRoute on GoRouteData {
  static RecordRoute _fromState(GoRouterState state) => const RecordRoute();

  @override
  String get location => GoRouteData.$location('/record');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $LibraryRoute on GoRouteData {
  static LibraryRoute _fromState(GoRouterState state) => const LibraryRoute();

  @override
  String get location => GoRouteData.$location('/library');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProcessingQueueRoute on GoRouteData {
  static ProcessingQueueRoute _fromState(GoRouterState state) =>
      const ProcessingQueueRoute();

  @override
  String get location => GoRouteData.$location('/library/processing');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RecordingStatusRoute on GoRouteData {
  static RecordingStatusRoute _fromState(GoRouterState state) =>
      RecordingStatusRoute(recordingId: state.pathParameters['recordingId']!);

  RecordingStatusRoute get _self => this as RecordingStatusRoute;

  @override
  String get location => GoRouteData.$location(
    '/library/recordings/${Uri.encodeComponent(_self.recordingId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TranscriptRoute on GoRouteData {
  static TranscriptRoute _fromState(GoRouterState state) =>
      TranscriptRoute(recordingId: state.pathParameters['recordingId']!);

  TranscriptRoute get _self => this as TranscriptRoute;

  @override
  String get location => GoRouteData.$location(
    '/library/recordings/${Uri.encodeComponent(_self.recordingId)}/transcript',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfilesRoute on GoRouteData {
  static ProfilesRoute _fromState(GoRouterState state) => const ProfilesRoute();

  @override
  String get location => GoRouteData.$location('/profiles');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileNewRoute on GoRouteData {
  static ProfileNewRoute _fromState(GoRouterState state) =>
      const ProfileNewRoute();

  @override
  String get location => GoRouteData.$location('/profiles/new');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileEditRoute on GoRouteData {
  static ProfileEditRoute _fromState(GoRouterState state) =>
      ProfileEditRoute(profileId: state.pathParameters['profileId']!);

  ProfileEditRoute get _self => this as ProfileEditRoute;

  @override
  String get location => GoRouteData.$location(
    '/profiles/${Uri.encodeComponent(_self.profileId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ModelsSettingsRoute on GoRouteData {
  static ModelsSettingsRoute _fromState(GoRouterState state) =>
      const ModelsSettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings/models');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $VaultFoldersRoute on GoRouteData {
  static VaultFoldersRoute _fromState(GoRouterState state) =>
      const VaultFoldersRoute();

  @override
  String get location => GoRouteData.$location('/settings/vault-folders');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $VaultTargetOptionsRoute on GoRouteData {
  static VaultTargetOptionsRoute _fromState(GoRouterState state) =>
      VaultTargetOptionsRoute(targetId: state.pathParameters['targetId']!);

  VaultTargetOptionsRoute get _self => this as VaultTargetOptionsRoute;

  @override
  String get location => GoRouteData.$location(
    '/settings/vault-folders/${Uri.encodeComponent(_self.targetId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PendingExportsRoute on GoRouteData {
  static PendingExportsRoute _fromState(GoRouterState state) =>
      const PendingExportsRoute();

  @override
  String get location => GoRouteData.$location('/settings/pending-exports');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RoutingRulesRoute on GoRouteData {
  static RoutingRulesRoute _fromState(GoRouterState state) =>
      const RoutingRulesRoute();

  @override
  String get location => GoRouteData.$location('/settings/routing-rules');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $RoutingRuleEditorRoute on GoRouteData {
  static RoutingRuleEditorRoute _fromState(GoRouterState state) =>
      RoutingRuleEditorRoute(ruleId: state.pathParameters['ruleId']!);

  RoutingRuleEditorRoute get _self => this as RoutingRuleEditorRoute;

  @override
  String get location => GoRouteData.$location(
    '/settings/routing-rules/${Uri.encodeComponent(_self.ruleId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TemplatesRoute on GoRouteData {
  static TemplatesRoute _fromState(GoRouterState state) =>
      const TemplatesRoute();

  @override
  String get location => GoRouteData.$location('/settings/templates');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $TemplateEditorRoute on GoRouteData {
  static TemplateEditorRoute _fromState(GoRouterState state) =>
      TemplateEditorRoute(templateId: state.pathParameters['templateId']!);

  TemplateEditorRoute get _self => this as TemplateEditorRoute;

  @override
  String get location => GoRouteData.$location(
    '/settings/templates/${Uri.encodeComponent(_self.templateId)}',
  );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
