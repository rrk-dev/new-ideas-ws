import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Installs global handlers so an uncaught error never takes down the app
/// (and with it an in-progress recording).
///
/// Only the error's runtime type is logged: messages and stack frames can
/// carry user content. FND-07 replaces this with the file logger.
void installErrorBoundary({void Function(String errorType)? onError}) {
  void report(Object error) {
    final type = error.runtimeType.toString();
    developer.log('uncaught error: $type', name: 'vv.error', level: 1000);
    onError?.call(type);
  }

  FlutterError.onError = (details) => report(details.exception);
  PlatformDispatcher.instance.onError = (error, stack) {
    report(error);
    return true; // handled: do not crash
  };
}
