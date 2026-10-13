import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/saf_vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

/// On-device SAF checks (EXP-03), steps in docs/test-plans/device/EXP-03.md.
///
/// Phase 1 (pick): the system folder picker opens; choose the Obsidian vault
/// folder. A check note is written into it.
///   fvm flutter test integration_test/vault_folder_saf_test.dart \
///     --flavor dev -d DEVICE_ID --dart-define=VV_SAF_PHASE=pick
/// Phase 2 (verify, after force-stop / reboot): no picker; the persisted
/// grant must still allow writing.
///   ... --dart-define=VV_SAF_PHASE=verify
const _phase = String.fromEnvironment('VV_SAF_PHASE', defaultValue: 'pick');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip = defaultTargetPlatform != TargetPlatform.android
      ? 'Android only'
      : null;

  testWidgets(
    '[EXP-03/AC2] picked vault folder receives a note (Obsidian check)',
    skip: _phase != 'pick' || skip != null,
    (tester) async {
      final access = SafFolderAccess();
      final folder = (await access.pick()).valueOrNull;
      expect(folder, isNotNull, reason: 'pick a folder in the system picker');
      expect(await access.checkAccess(folder!), VaultAccess.ok);
      final stamp = DateTime.now().toIso8601String();
      final writer = access.writerFor(folder);
      final r = await writer.write(
        NoteDraft(
          relativePath: 'VaultVoice/EXP-03 check.md',
          markdown:
              '---\nsource: vaultvoice\n---\n\n# EXP-03 check\n\n$stamp\n',
        ),
        overwrite: true,
      );
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
      expect(
        (await writer.exists('VaultVoice/EXP-03 check.md')).valueOrNull,
        isTrue,
      );
    },
  );

  testWidgets(
    '[EXP-03/AC1] persisted grant still writable after restart/reboot',
    skip: _phase != 'verify' || skip != null,
    (tester) async {
      final access = SafFolderAccess();
      final trees = (await access.persistedTrees()).valueOrNull ?? const [];
      expect(trees, isNotEmpty, reason: 'run phase "pick" first');
      final folder = VaultFolder(kind: VaultTargetKind.saf, handle: trees.last);
      expect(await access.checkAccess(folder), VaultAccess.ok);
      final r = await access
          .writerFor(folder)
          .write(
            NoteDraft(
              relativePath: 'VaultVoice/EXP-03 after restart.md',
              markdown: '# EXP-03 after restart\n\n${DateTime.now()}\n',
            ),
            overwrite: true,
          );
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
    },
  );
}
