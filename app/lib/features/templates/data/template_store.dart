import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show immutable;
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/repositories/profiles_repository.dart';
import 'package:vaultvoice/core/db/repositories/settings_repository.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';

/// A user-created Markdown template (EXP-07, Pro).
@immutable
class CustomTemplate {
  const CustomTemplate({
    required this.id,
    required this.body,
    required this.filenamePattern,
    required this.profileId,
    this.baseId,
  });

  /// Also the name shown in the UI (a slug the user chose).
  final String id;
  final String body;
  final String filenamePattern;

  /// The profile whose schema the template is written for (autocomplete,
  /// validation, preview). Built-in profiles are kept out of
  /// `templates.profile_id` (ADR-EXP-01: built-ins are assets, not rows).
  final String profileId;

  /// Built-in template it was duplicated from ("Reset to default").
  final String? baseId;

  CustomTemplate copyWith({String? body, String? filenamePattern}) =>
      CustomTemplate(
        id: id,
        body: body ?? this.body,
        filenamePattern: filenamePattern ?? this.filenamePattern,
        profileId: profileId,
        baseId: baseId,
      );
}

/// Storage of custom templates and of the profile → template binding.
abstract interface class TemplateStore {
  Stream<List<CustomTemplate>> watch();

  Future<Result<void>> save(CustomTemplate template);

  Future<Result<void>> delete(String id);

  /// Profile id → template id the user picked for that profile's notes
  /// (`TemplateNoteRenderer.templateOverrides`).
  Stream<Map<String, String>> watchBindings();

  /// Binds [templateId] to [profileId]; null restores the profile default.
  Future<Result<void>> bind(String profileId, String? templateId);
}

/// [TemplateStore] on the `templates` table + two settings keys:
/// `templates.meta` (`{id: {profile, base}}`) and `templates.bindings`.
class DriftTemplateStore implements TemplateStore {
  DriftTemplateStore({
    required this.templates,
    required this.settings,
    required this.builtinProfileIds,
    this.clock = const SystemClock(),
  });

  final ProfilesRepository templates;
  final SettingsRepository settings;
  final Set<String> builtinProfileIds;
  final Clock clock;

  static Map<String, Object?> _map(Object? v) =>
      v is Map<String, Object?> ? v : const {};

  @override
  Stream<List<CustomTemplate>> watch() async* {
    // Re-emit when either the rows or the meta map change.
    await for (final rows in templates.watchTemplates()) {
      final meta = _map(
        (await settings.get(SettingKeys.templatesMeta)).valueOrNull,
      );
      yield [
        for (final r in rows)
          CustomTemplate(
            id: r.id,
            body: r.body,
            filenamePattern: r.filenamePattern,
            profileId:
                r.profileId ??
                (_map(meta[r.id])['profile'] as String?) ??
                'meeting',
            baseId: _map(meta[r.id])['base'] as String?,
          ),
      ];
    }
  }

  @override
  Future<Result<void>> save(CustomTemplate t) async {
    final meta = {
      ..._map((await settings.get(SettingKeys.templatesMeta)).valueOrNull),
      t.id: {'profile': t.profileId, 'base': ?t.baseId},
    };
    final m = await settings.set(SettingKeys.templatesMeta, meta);
    if (m case Err()) return m;
    return await templates.upsertTemplate(
      TemplatesCompanion.insert(
        id: t.id,
        // Never reference a built-in profile (no row; FK would fail).
        profileId: Value(
          builtinProfileIds.contains(t.profileId) ? null : t.profileId,
        ),
        body: t.body,
        filenamePattern: t.filenamePattern,
        updatedAt: clock.now(),
      ),
    );
  }

  @override
  Future<Result<void>> delete(String id) async {
    final bindings = await _bindings();
    final kept = {
      for (final e in bindings.entries)
        if (e.value != id) e.key: e.value,
    };
    if (kept.length != bindings.length) {
      await settings.set(SettingKeys.templatesBindings, kept);
    }
    return await templates.deleteTemplate(id);
  }

  Future<Map<String, String>> _bindings() async => {
    for (final e in _map(
      (await settings.get(SettingKeys.templatesBindings)).valueOrNull,
    ).entries)
      if (e.value is String) e.key: e.value! as String,
  };

  @override
  Stream<Map<String, String>> watchBindings() => settings
      .watch(SettingKeys.templatesBindings)
      .map(
        (v) => {
          for (final e in _map(v).entries)
            if (e.value is String) e.key: e.value! as String,
        },
      );

  @override
  Future<Result<void>> bind(String profileId, String? templateId) async {
    final next = {...await _bindings()};
    if (templateId == null) {
      next.remove(profileId);
    } else {
      next[profileId] = templateId;
    }
    return await settings.set(SettingKeys.templatesBindings, next);
  }
}

/// A free template id from a user-typed [name] (lowercase slug, unique
/// against [taken]): `My Meeting` → `my-meeting`, then `my-meeting-2`.
String templateIdFrom(String name, Set<String> taken) {
  var base = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) base = 'template';
  if (base.length > 48) base = base.substring(0, 48);
  if (!taken.contains(base)) return base;
  for (var n = 2; ; n++) {
    final id = '$base-$n';
    if (!taken.contains(id)) return id;
  }
}
