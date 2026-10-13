import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vaultvoice/core/platform/vault_writer.dart';
import 'package:vaultvoice/features/export/data/bookmark_vault_writer.dart';
import 'package:vaultvoice/features/export/domain/vault_folder.dart';

/// On-device bookmark checks (EXP-04), steps in
/// docs/test-plans/device/EXP-04.md.
///
/// Phase 1 (pick): the Files folder picker opens; choose the Obsidian vault.
/// A check note is written and the bookmark is printed as
/// `VV_BOOKMARK=<base64>` (test-only output; it identifies a folder, not
/// content).
///   fvm flutter test integration_test/vault_folder_bookmark_test.dart \
///     --flavor dev -d DEVICE_ID --dart-define=VV_BOOKMARK_PHASE=pick
/// Phase 2 (verify, after force-quit / reboot / app update): no picker.
///   ... --dart-define=VV_BOOKMARK_PHASE=verify --dart-define=VV_BOOKMARK=...
const _phase = String.fromEnvironment(
  'VV_BOOKMARK_PHASE',
  defaultValue: 'pick',
);
const _bookmark = String.fromEnvironment('VV_BOOKMARK');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final notIos = defaultTargetPlatform != TargetPlatform.iOS;

  testWidgets(
    '[EXP-04/AC2] picked vault folder receives a note (Obsidian check)',
    skip: _phase != 'pick' || notIos,
    (tester) async {
      final access = BookmarkFolderAccess();
      final folder = (await access.pick()).valueOrNull;
      expect(folder, isNotNull, reason: 'pick a folder in the Files picker');
      expect(await access.checkAccess(folder!), VaultAccess.ok);
      final r = await access
          .writerFor(folder)
          .write(
            NoteDraft(
              relativePath: 'VaultVoice/EXP-04 check.md',
              markdown:
                  '---\nsource: vaultvoice\n---\n\n# EXP-04 check\n\n'
                  '${DateTime.now().toIso8601String()}\n',
            ),
            overwrite: true,
          );
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
      debugPrint('VV_BOOKMARK=${folder.handle}');
    },
  );

  testWidgets(
    '[EXP-04/AC1] stored bookmark still writable after restart/update',
    skip: _phase != 'verify' || notIos,
    (tester) async {
      expect(_bookmark, isNotEmpty, reason: 'pass --dart-define=VV_BOOKMARK');
      final refreshed = <String>[];
      final access = BookmarkFolderAccess(
        onRefreshed: (_, updated) => refreshed.add(updated.handle),
      );
      const folder = VaultFolder(
        kind: VaultTargetKind.bookmark,
        handle: _bookmark,
      );
      expect(await access.checkAccess(folder), VaultAccess.ok);
      if (refreshed.isNotEmpty) {
        debugPrint('VV_BOOKMARK (refreshed)=${refreshed.last}');
      }
      final r = await access
          .writerFor(folder)
          .write(
            NoteDraft(
              relativePath: 'VaultVoice/EXP-04 after restart.md',
              markdown: '# EXP-04 after restart\n\n${DateTime.now()}\n',
            ),
            overwrite: true,
          );
      expect(r.isOk, isTrue, reason: '${r.failureOrNull}');
    },
  );
}
