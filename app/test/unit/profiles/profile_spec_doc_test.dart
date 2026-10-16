import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/post_processors.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

import 'profile_fixtures.dart';

void main() {
  // Lazy: read inside the tests, so tag-filtered runs without docs/ (the
  // Linux golden container) can still load this file.
  late final doc = File('../docs/profile-spec.md').readAsStringSync();

  group('[PRF-01/AC1] docs/profile-spec.md documents the spec with a full '
      'example', () {
    test('the full example is a valid profile identical to the shipped '
        'meeting built-in', () {
      final blocks = RegExp(
        r'```yaml\n(.*?)```',
        dotAll: true,
      ).allMatches(doc).map((m) => m.group(1)!).toList();
      expect(blocks, hasLength(1), reason: 'one full example block');
      final result = ProfileCodec.parseYaml(blocks.single);
      expect(result.issues.map((i) => '$i'), isEmpty);
      final example = result.profile!;
      // Uses every major section of the spec.
      expect(example.postProcess, isNotEmpty);
      expect(example.reduce, isNotEmpty);
      expect(example.classifyKeywords, isNotEmpty);
      expect(example.filenamePattern, isNotNull);
      expect(
        example.toJson(),
        Profile.fromJson(builtinMap('meeting')).toJson(),
      );
      expect(
        const ProfileValidator().validateTemplate(example, meetingTemplate()),
        isEmpty,
      );
    });

    test('every definition key, schema keyword and post-processor is '
        'documented', () {
      for (final key in kProfileKeys) {
        expect(doc, contains('`$key'), reason: 'key $key');
      }
      for (final keyword in kSupportedSchemaKeywords) {
        expect(doc, contains('`$keyword`'), reason: 'keyword $keyword');
      }
      for (final p in PostProcessor.values) {
        expect(doc, contains('`${p.wireName}`'), reason: p.wireName);
      }
      for (final s in ReduceStrategy.values) {
        expect(doc, contains('`${s.wireName}`'), reason: s.wireName);
      }
      for (final c in ConsentConfirmation.values) {
        expect(doc, contains('`${c.name}`'), reason: c.name);
      }
    });
  });
}
