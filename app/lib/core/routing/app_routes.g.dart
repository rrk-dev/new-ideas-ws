// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRouteData];

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
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/settings',
          hasOverriddenOnExit: false,
          factory: $SettingsRoute._fromState,
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
