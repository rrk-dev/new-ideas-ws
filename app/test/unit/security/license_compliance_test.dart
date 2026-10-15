import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/licenses/bundled_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '[SEC-05/AC1] resolved runtime and build packages have full notices',
    () {
      final inventory = jsonDecode(
        File('assets/licenses/pub_inventory.json').readAsStringSync(),
      ) as List<Object?>;
      final rows = inventory.cast<Map<String, Object?>>();
      final config = jsonDecode(
        File('.dart_tool/package_config.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final packages = (config['packages']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((p) => p['name'])
          .where((name) => name != 'vaultvoice');
      expect(rows.map((p) => p['name']).toSet(), containsAll(packages));
      for (final row in rows) {
        expect((row['license_text']! as String).length, greaterThan(40));
        expect(row['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
      }
    },
  );

  test(
    '[SEC-05/AC1] every catalog model has license id, URL and inventory',
    () {
      final catalog = jsonDecode(
        File('assets/catalog/catalog.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final doc = File('../docs/licenses.md').readAsStringSync();
      for (final model
          in (catalog['models']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        expect(model['license'], isNotEmpty);
        final url = Uri.parse(model['license_url']! as String);
        expect(url.scheme, 'https');
        expect(url.host, isNotEmpty);
        expect(doc, contains('`${model['id']}`'));
      }
    },
  );

  test(
    '[SEC-05/AC1] LicenseRegistry includes native and model full notices',
    () async {
      registerBundledLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final packages = entries.expand((e) => e.packages).toSet();
      expect(
        packages,
        containsAll([
          'whisper.cpp',
          'llama.cpp',
          'ggml',
          'SQLite3 Multiple Ciphers',
          'SQLite',
          'Silero VAD v6.2.0',
          'Whisper model weights (OpenAI)',
          'Qwen2.5-0.5B-Instruct (model)',
          'drift',
          'record',
        ]),
      );
      for (final entry in entries.where(
        (e) => e.packages.contains('Qwen2.5-0.5B-Instruct (model)'),
      )) {
        expect(
          entry.paragraphs.map((p) => p.text).join('\n'),
          contains('TERMS AND CONDITIONS'),
        );
      }
    },
  );
}
