import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/db/repositories/vault_repository.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/export/data/export_outbox.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/data/vault_writer_resolver.dart';
import 'package:vaultvoice/features/export/domain/pending_export.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

part 'routing_providers.g.dart';

/// Persistence of routing rules (`routing_rules`, FND-04 schema v1).
abstract interface class RoutingRulesStore {
  /// Rules in evaluation order.
  Stream<List<RoutingRule>> watch();

  Future<Result<void>> save(RoutingRule rule);

  Future<Result<void>> delete(String id);

  /// Rewrites priorities to match [ordered] (10, 20, 30, …).
  Future<Result<void>> reorder(List<RoutingRule> ordered);
}

class DriftRoutingRulesStore implements RoutingRulesStore {
  const DriftRoutingRulesStore(this._repo);

  final VaultRepository _repo;

  @override
  Stream<List<RoutingRule>> watch() =>
      _repo.watchRules().map((rows) => [for (final r in rows) ruleFromRow(r)]);

  @override
  Future<Result<void>> save(RoutingRule rule) => _repo.upsertRule(
    RoutingRulesCompanion.insert(
      id: rule.id,
      priority: rule.priority,
      match: rule.matchJson(),
      targetId: rule.targetId,
      subPath: Value(rule.subPath),
      filenamePattern: Value(rule.filenamePattern),
    ),
  );

  @override
  Future<Result<void>> delete(String id) => _repo.deleteRule(id);

  @override
  Future<Result<void>> reorder(List<RoutingRule> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      final saved = await save(ordered[i].copyWith(priority: (i + 1) * 10));
      if (saved case Err()) return saved;
    }
    return const Ok(null);
  }
}

/// `routing_rules` row → [RoutingRule].
RoutingRule ruleFromRow(RoutingRuleRow r) => RoutingRule.fromRow(
  id: r.id,
  priority: r.priority,
  targetId: r.targetId,
  match: r.match,
  subPath: r.subPath,
  filenamePattern: r.filenamePattern,
);

@Riverpod(keepAlive: true)
RoutingRulesStore routingRulesStore(Ref ref) =>
    DriftRoutingRulesStore(ref.watch(vaultRepositoryProvider));

/// Routing rules in evaluation order (rule editor, EXP-05).
@riverpod
Stream<List<RoutingRule>> routingRuleList(Ref ref) =>
    ref.watch(routingRulesStoreProvider).watch();

/// Per-target export options (`export.target_options`).
@riverpod
Stream<Map<String, VaultTargetOptions>> vaultTargetOptions(Ref ref) => ref
    .watch(settingsStoreProvider)
    .watch(SettingKeys.exportTargetOptions)
    .map(decodeTargetOptions);

/// Saves the options of one target, keeping the others in [current].
Future<Result<void>> saveTargetOptions(
  SettingsStore store,
  Map<String, VaultTargetOptions> current,
  String targetId,
  VaultTargetOptions options,
) => store.set(
  SettingKeys.exportTargetOptions,
  encodeTargetOptions({...current, targetId: options}),
);

/// [RoutingPolicy] of a [FeatureAccess] (LIC-01 `routingRules`,
/// `multiTarget`).
RoutingPolicy routingPolicyOf(FeatureAccess access) => RoutingPolicy(
  rulesEnabled: access.routingRules == AccessLevel.full,
  maxTargets: access.maxActiveVaultTargets,
);

/// The routing entitlement for the UI.
@riverpod
RoutingPolicy routingPolicy(Ref ref) =>
    routingPolicyOf(ref.watch(featureAccessStateProvider));

/// Mirrors [routingPolicy] into `export.routing_policy` for the pipeline
/// worker isolate (it has no `EntitlementService`). Read once at startup
/// (`ProcessingServicesHost`); stays subscribed for the app's lifetime.
@Riverpod(keepAlive: true)
void routingPolicyMirror(Ref ref) {
  ref.listen(featureAccessStateProvider, (_, access) {
    ref
        .read(settingsStoreProvider)
        .set(SettingKeys.exportRoutingPolicy, routingPolicyOf(access).toJson())
        .ignore();
  }, fireImmediately: true);
}

/// The export outbox (EXP-06).
@Riverpod(keepAlive: true)
ExportOutbox exportOutbox(Ref ref) {
  // Host / desktop builds have no platform folder access (tests override).
  final mobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final folders = mobile ? ref.watch(vaultFolderAccessProvider) : null;
  final resolver = mobile
      ? platformVaultWriterResolver(
          appLocal: ref.watch(appLocalVaultWriterProvider),
          repo: ref.watch(vaultRepositoryProvider),
        )
      : null;
  return ExportOutbox(
    db: ref.watch(vaultVoiceDatabaseProvider),
    client: () => ref.read(pipelineClientProvider.future),
    folders: folders,
    writerFor: resolver,
    clock: ref.watch(clockProvider),
  );
}

/// Notes that have not reached their vault folder yet (EXP-06).
@riverpod
Stream<List<PendingExport>> pendingExports(Ref ref) =>
    ref.watch(exportOutboxProvider).watch();
