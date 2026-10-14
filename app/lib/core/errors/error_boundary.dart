import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Where an uncaught error was caught.
enum ErrorSource {
  /// `FlutterError.onError` (framework: build, layout, gestures …).
  flutter,

  /// `PlatformDispatcher.onError` (uncaught async errors).
  platform,
}

/// Receives the error object and its stack for local crash capture
/// (REL-02). Implementations must never persist or log the error message —
/// it can contain user content.
typedef CrashSink = void Function(
  Object error,
  StackTrace? stack,
  ErrorSource source,
);

/// Installs global handlers so an uncaught error never takes down the app
/// (and with it an in-progress recording).
///
/// Only the error's runtime type is logged: messages and stack frames can
/// carry user content. [onCrash] (REL-02) gets the stack for the local crash
/// report; it must stay content-free too.
void installErrorBoundary({
  void Function(String errorType)? onError,
  CrashSink? onCrash,
}) {
  void report(Object error, StackTrace? stack, ErrorSource source) {
    final type = error.runtimeType.toString();
    developer.log('uncaught error: $type', name: 'vv.error', level: 1000);
    onError?.call(type);
    try {
      onCrash?.call(error, stack, source);
    } on Object {
      // Crash capture must never turn a handled error into a crash.
    }
  }

  FlutterError.onError = (details) =>
      report(details.exception, details.stack, ErrorSource.flutter);
  PlatformDispatcher.instance.onError = (error, stack) {
    report(error, stack, ErrorSource.platform);
    return true; // handled: do not crash
  };
}
