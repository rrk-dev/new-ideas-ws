import 'dart:async';

import 'package:vaultvoice/core/db/enums.dart';
import 'package:vaultvoice/core/db/repositories/models_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/features/extraction/domain/device_tiering.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart'
    show ModelCatalog;
import 'package:vaultvoice/features/pipeline/domain/active_models.dart';

/// Resolves the active STT/LLM models on the UI isolate — where the catalog,
/// device profile and entitlements live — and publishes the result to the
/// pipeline worker through the `settings` table ([kActiveModelsKey]).
///
/// [watch] republishes whenever installed models, the user's preferred
/// models or the entitlement change, and calls `onAvailable` when the set of
/// usable models changed (the pipeline then resumes `waiting(model_missing)`
/// jobs).
final class ActiveModelsPublisher {
  ActiveModelsPublisher({
    required this.settings,
    required this.models,
    required this.access,
    this.accessChanges = const Stream.empty(),
    this.catalog,
    this.device,
    this.sttLanguage,
  });

  final SettingsRepository settings;
  final ModelsRepository models;
  final FeatureAccess Function() access;
  final Stream<Object?> accessChanges;

  /// The verified catalog (bundled or updated), or null when unavailable.
  final Future<ModelCatalog?> Function()? catalog;
  final DeviceProfile? Function()? device;

  /// Transcription language for STT-07's default (null = `en`).
  final String Function()? sttLanguage;

  Future<ActiveModelSelection>? _running;
  bool _again = false;
  String? _fingerprint;

  /// Computes and stores the selection (serialised; a call while one runs
  /// schedules exactly one more run).
  Future<ActiveModelSelection> publish() async {
    if (_running case final running?) {
      _again = true;
      return await running;
    }
    final run = _running = _publish();
    try {
      var result = await run;
      while (_again) {
        _again = false;
        result = await (_running = _publish());
      }
      return result;
    } finally {
      _running = null;
    }
  }

  Future<ActiveModelSelection> _publish() async =>
      (await _publishWithFingerprint()).$1;

  Future<(ActiveModelSelection, String)> _publishWithFingerprint() async {
    final rows = await models.watchAll().first;
    final installed = [
      for (final r in rows)
        if (r.type == ModelType.stt || r.type == ModelType.llm)
          InstalledModelInfo(
            id: r.id,
            kind: r.type == ModelType.stt
                ? EngineModelKind.stt
                : EngineModelKind.llm,
            sizeBytes: r.size,
          ),
    ];
    String? pref(Object? v) => v is String && v.isNotEmpty ? v : null;
    final selection = selectActiveModels(
      installed: installed,
      access: access(),
      catalog: await _catalog(),
      device: _device(),
      preferredStt: pref(
        (await settings.get(kPreferredSttModelKey)).valueOrNull,
      ),
      preferredLlm: pref(
        (await settings.get(kPreferredLlmModelKey)).valueOrNull,
      ),
      sttLanguage: sttLanguage?.call() ?? 'en',
    );
    final stored = (await settings.get(kActiveModelsKey)).valueOrNull;
    if (stored == null || ActiveModelSelection.fromJson(stored) != selection) {
      await settings.set(kActiveModelsKey, selection.toJson());
    }
    final fingerprint = [
      selection,
      for (final r in rows) '${r.id}@${r.installedAt.millisecondsSinceEpoch}',
    ].join('|');
    return (selection, fingerprint);
  }

  Future<ModelCatalog?> _catalog() async {
    try {
      return await catalog?.call();
    } on Object {
      return null;
    }
  }

  DeviceProfile? _device() {
    try {
      return device?.call();
    } on Object {
      return null;
    }
  }

  /// Republishes on every relevant change; [onAvailable] runs after a
  /// publish whose selection or installed set differs from the previous one
  /// (including the first) and that has at least one model.
  StreamSubscription<void> watch({
    required Future<void> Function(ActiveModelSelection selection) onAvailable,
  }) {
    final controller = StreamController<void>();
    final subs = <StreamSubscription<Object?>>[];
    var closed = false;
    var queue = Future<void>.value();

    void trigger(Object? _) {
      if (closed) return;
      queue = queue
          .then((_) async {
            if (closed) return;
            final (selection, fingerprint) = await _publishWithFingerprint();
            if (fingerprint == _fingerprint) return;
            _fingerprint = fingerprint;
            if (selection.stt != null || selection.llm != null) {
              await onAvailable(selection);
            }
          })
          .catchError((Object _) {});
    }

    controller
      ..onListen = () {
        subs
          ..add(models.watchAll().listen(trigger))
          ..add(settings.watch(kPreferredSttModelKey).listen(trigger))
          ..add(settings.watch(kPreferredLlmModelKey).listen(trigger))
          ..add(accessChanges.listen(trigger));
      }
      ..onCancel = () async {
        closed = true;
        for (final s in subs) {
          await s.cancel();
        }
        await queue;
      };
    return controller.stream.listen(null);
  }
}
