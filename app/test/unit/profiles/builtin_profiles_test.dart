import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';

import 'profile_fixtures.dart';

Map<String, String> assetSources() => {
  for (final a in kBuiltinProfileAssets) a: File(a).readAsStringSync(),
};

void main() {
  test('kBuiltinProfileAssets lists exactly assets/profiles/*.yaml', () {
    final onDisk = Directory('assets/profiles')
        .listSync()
        .whereType<File>()
        .map((f) => 'assets/profiles/${f.uri.pathSegments.last}')
        .where((p) => p.endsWith('.yaml'))
        .toSet();
    expect(kBuiltinProfileAssets.toSet(), onDisk);
  });

  test('pubspec declares the profiles asset folder', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('    - assets/profiles/\n'),
    );
  });

  group('built-in profiles', () {
    late BuiltinProfiles builtins;
    setUp(() => builtins = BuiltinProfiles.parse(assetSources()));

    test('meeting, warranty and engineering load, read-only, keyed by '
        '(id, version)', () {
      expect(builtins.all.map((p) => p.id), [
        'meeting',
        'warranty',
        'engineering',
      ]);
      for (final p in builtins.all) {
        expect(p.source, ProfileSource.builtin);
        expect(p.isReadOnly, isTrue);
        expect(builtins.lookup(p.ref), same(p));
      }
      expect(builtins.lookup((id: 'meeting', version: 99)), isNull);
      expect(builtins['nope'], isNull);
      expect(builtins.ids, {'meeting', 'warranty', 'engineering'});
    });

    test('meeting.yaml is the skill reference profile', () {
      final reference = ProfileCodec.decodeYaml(
        File(
          '../.agents/skills/vv-extraction-profiles/references/'
          'meeting-profile.example.yaml',
        ).readAsStringSync(),
      ).$1!;
      expect(
        builtins['meeting']!.toJson(),
        Profile.fromJson(reference).toJson(),
      );
    });

    test('warranty follows the skill field table and spec rules', () {
      final w = builtins['warranty']!;
      expect(w.schema.properties.keys, [
        'product',
        'brand',
        'model',
        'serial_number',
        'purchase_date',
        'retailer',
        'price',
        'warranty_period',
        'support_contacts',
        'notes',
      ]);
      // warranty_expiry is computed in Dart, never asked of the model.
      expect(w.schema.properties.containsKey('warranty_expiry'), isFalse);
      expect(w.stt.diarization, isFalse);
      expect(w.consentConfirmation, ConsentConfirmation.none);
      final period = w.schema.properties['warranty_period']! as ObjectSchema;
      expect(period.properties.keys, ['value', 'unit']);
    });

    test('engineering follows the skill field table', () {
      final e = builtins['engineering']!;
      expect(e.schema.properties.keys, [
        'title',
        'context',
        'concepts',
        'api_designs',
        'tradeoffs',
        'decisions',
        'todos',
        'open_questions',
      ]);
      final tradeoff =
          (e.schema.properties['tradeoffs']! as ArraySchema).items
              as ObjectSchema;
      expect(tradeoff.properties.keys, ['option', 'pros', 'cons']);
      expect(e.stt.diarization, isTrue);
      expect(e.consentConfirmation, ConsentConfirmation.required);
    });

    test('meeting keeps the Free tier; warranty/engineering tiers are a '
        'marked PRODUCT-DECISION', () {
      expect(builtins['meeting']!.tier, ProfileTier.free);
      for (final id in ['warranty', 'engineering']) {
        expect(builtinYaml(id), contains('PRODUCT-DECISION'));
      }
    });
  });

  test('an invalid or duplicate built-in fails loudly', () {
    expect(
      () => BuiltinProfiles.parse({'assets/profiles/bad.yaml': 'id: x'}),
      throwsA(
        isA<BuiltinProfileException>().having(
          (e) => e.toString(),
          'issues',
          contains('assets/profiles/bad.yaml.'),
        ),
      ),
    );
    final meeting = builtinYaml('meeting');
    expect(
      () => BuiltinProfiles.parse({'a.yaml': meeting, 'b.yaml': meeting}),
      throwsA(
        isA<BuiltinProfileException>().having(
          (e) => e.issues.single.toString(),
          'issue',
          'b.yaml: duplicate built-in id "meeting"',
        ),
      ),
    );
  });
}
