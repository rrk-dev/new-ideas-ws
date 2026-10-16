import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/logging/logger.dart';
import 'package:vaultvoice/features/export/data/export_providers.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';
import 'package:vaultvoice/features/settings/presentation/vault_settings_screens.dart';

import '../fakes/fake_permission_hosts.dart';
import '../unit/logging_test.dart' show MemorySink;

/// Runs [pickAndSaveVaultFolder] from a button and records the outcome.
class _Host extends ConsumerWidget {
  const _Host(this.onResult);

  final void Function(VaultFolderPick) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async =>
        onResult(await pickAndSaveVaultFolder(ref, context.l10n)),
    child: const Text('pick'),
  );
}

void main() {
  late MemorySink sink;
  late VaultVoiceDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    sink = MemorySink();
    db = VaultVoiceDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<VaultFolderPick> pick(
    WidgetTester t,
    Result<VaultFolder?> answer,
  ) async {
    VaultFolderPick? result;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          vaultFolderAccessProvider.overrideWithValue(
            FakeVaultFolderAccess(answer),
          ),
          vaultVoiceDatabaseProvider.overrideWithValue(db),
          loggerProvider.overrideWithValue(Logger(sinks: [sink])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _Host((r) => result = r)),
        ),
      ),
    );
    await t.tap(find.text('pick'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    return result!;
  }

  testWidgets('[EXP-04/AC1] a macOS bookmark pick is saved as a bookmark '
      'target', (t) async {
    final result = await pick(
      t,
      const Ok(
        VaultFolder(
          kind: VaultTargetKind.bookmark,
          handle: 'Ym9va21hcms=',
          displayName: 'Notes',
        ),
      ),
    );
    expect(result, isA<VaultFolderPicked>());
    final rows = await t.runAsync(() => db.select(db.vaultTargets).get());
    expect(rows, hasLength(1));
    expect(rows!.single.handle, 'Ym9va21hcms=');
  });

  testWidgets('[EXP-04/AC1] a refused pick is diagnosable without leaking '
      'the folder', (t) async {
    final result = await pick(t, const Err(VaultAccessFailure.revoked()));
    expect(result, isA<VaultFolderPickFailed>());
    final record = sink.records.single;
    expect(record.tag, 'vault');
    expect(record.message, 'vault access: revoked');
    expect(record.fields['failure'], 'VaultAccessFailure');
  });
}
