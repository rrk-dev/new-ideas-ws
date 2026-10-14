import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_codec.dart';
import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

import 'profile_fixtures.dart';

const validator = ProfileValidator();

/// Validates [def] and returns the issues as `path: message` strings.
List<String> issuesOf(
  Map<String, Object?> def, {
  Set<String> takenIds = const {},
}) {
  final result = validator.validate(def, takenIds: takenIds);
  expect(
    result.profile == null,
    result.issues.isNotEmpty,
    reason: 'a profile is returned exactly when there are no issues',
  );
  return [for (final i in result.issues) i.toString()];
}

/// Asserts validation fails with an issue at [path] whose message contains
/// every fragment in [contains].
void expectIssue(
  Map<String, Object?> def,
  String path,
  List<String> contains, {
  Set<String> takenIds = const {},
}) {
  final issues = issuesOf(def, takenIds: takenIds);
  final match = issues.where(
    (i) => i.startsWith('$path: ') && contains.every(i.contains),
  );
  expect(
    match,
    isNotEmpty,
    reason:
        'expected "$path: …${contains.join('…')}…" in\n'
        '${issues.join('\n')}',
  );
}

void main() {
  late Map<String, Object?> def;
  setUp(() => def = builtinMap('meeting'));

  test('the meeting reference profile is valid', () {
    expect(issuesOf(def), isEmpty);
    final p = validator.validate(def).profile!;
    expect(p.id, 'meeting');
    expect(p.consentConfirmation, ConsentConfirmation.required);
    expect(p.examples, hasLength(1));
  });

  group('[PRF-01/AC2] validator rejects malformed profiles with actionable '
      'errors', () {
    test('missing maxLength names the field path and the fix', () {
      final item = sub(sub(props(def), 'action_items'), 'items');
      sub(sub(item, 'properties'), 'owner').remove('maxLength');
      final issues = issuesOf(def);
      expect(
        issues,
        contains(
          'schema.action_items[].owner: missing maxLength — every string '
          'needs one (e.g. maxLength: 200) so the grammar cannot loop',
        ),
      );
    });

    test('missing maxItems on an array', () {
      sub(props(def), 'attendees').remove('maxItems');
      expectIssue(def, 'schema.attendees', ['missing maxItems', 'maxItems:']);
    });

    test('maxItems out of range', () {
      sub(props(def), 'topics')['maxItems'] = 0;
      expectIssue(def, 'schema.topics', ['between 1 and 200']);
    });

    test('unsupported keyword (outside the JSON-Schema subset)', () {
      sub(props(def), 'title')['pattern'] = '^[A-Z]';
      expectIssue(def, 'schema.title', ['unsupported keyword "pattern"']);
      def = builtinMap('meeting');
      sub(def, 'schema')[r'$ref'] = '#/defs/x';
      expectIssue(def, 'schema', [r'unsupported keyword "$ref"']);
    });

    test('type unions and unknown types', () {
      sub(props(def), 'title')['type'] = ['string', 'integer'];
      expectIssue(def, 'schema.title', ['exactly one non-null type']);
      def = builtinMap('meeting');
      sub(props(def), 'title')['type'] = 'text';
      expectIssue(def, 'schema.title', ['unknown type "text"']);
      def = builtinMap('meeting');
      sub(props(def), 'title').remove('type');
      expectIssue(def, 'schema.title', ['missing "type"']);
    });

    test('keyword on the wrong type', () {
      sub(props(def), 'title')['maxItems'] = 3;
      expectIssue(def, 'schema.title', ['"maxItems" applies to arrays']);
    });

    test('nullable arrays are refused', () {
      sub(props(def), 'topics')['type'] = ['array', 'null'];
      expectIssue(def, 'schema.topics', ['arrays cannot be nullable']);
    });

    test('root schema must be a non-nullable object', () {
      def['schema'] = {'type': 'string', 'maxLength': 3};
      expectIssue(def, 'schema', ['root must be "type: object"']);
      def.remove('schema');
      expectIssue(def, 'schema', ['is required']);
    });

    test('required lists unknown fields', () {
      (sub(def, 'schema')['required']! as List).add('agenda');
      expectIssue(def, 'schema', ['"required" lists "agenda"']);
    });

    test('invalid and reserved field names', () {
      props(def)['Bad-Name'] = {'type': 'string', 'maxLength': 5};
      expectIssue(def, 'schema.Bad-Name', ['lower_snake_case']);
      def = builtinMap('meeting');
      props(def)['has_notes'] = {'type': 'boolean'};
      expectIssue(def, 'schema.has_notes', ['must not start with "has_"']);
    });

    test('string enum must be non-empty unique text; enum bounds length', () {
      props(def)['mood'] = {
        'type': 'string',
        'enum': ['calm', 'calm'],
      };
      expectIssue(def, 'schema.mood', ['duplicate']);
      props(def)['mood'] = {
        'type': 'string',
        'enum': ['calm', 'tense'],
      };
      expect(issuesOf(def), isEmpty, reason: 'enum strings need no maxLength');
    });

    test('nesting deeper than the limit is refused', () {
      Map<String, Object?> nest(int n) => n == 0
          ? {'type': 'string', 'maxLength': 5}
          : {'type': 'array', 'maxItems': 2, 'items': nest(n - 1)};
      props(def)['deep'] = nest(7);
      expectIssue(def, 'schema.deep[][][][][][]', ['nested deeper than 6']);
    });

    test('id rules: pattern and uniqueness', () {
      def['id'] = 'Meeting Notes';
      expectIssue(def, 'id', ['must match']);
      def['id'] = 'm';
      expectIssue(def, 'id', ['must match']);
      def['id'] = 'a' * 41;
      expectIssue(def, 'id', ['must match']);
      def['id'] = 'meeting';
      expectIssue(def, 'id', ['already used'], takenIds: {'meeting'});
      def['id'] = 'team-sync_2';
      expect(issuesOf(def, takenIds: {'meeting'}), isEmpty);
    });

    test('instructions are limited to 2000 chars', () {
      def['instructions'] = 'x' * 2000;
      expect(issuesOf(def), isEmpty);
      def['instructions'] = 'x' * 2001;
      expectIssue(def, 'instructions', ['2001 chars, max 2000']);
      def['instructions'] = '  ';
      expectIssue(def, 'instructions', ['non-empty']);
    });

    test('examples must validate against the schema', () {
      final example = (def['examples']! as List).first as Map<String, Object?>;
      final output = sub(example, 'output');
      ((output['action_items']! as List).first as Map)['owner'] = 42;
      output.remove('topics');
      output['agenda'] = <Object?>[];
      final issues = issuesOf(def);
      const ownerIssue =
          'examples[0].output.action_items[0].owner: '
          'expected a string, got a number';
      expect(
        issues,
        containsAll([
          ownerIssue,
          'examples[0].output.topics: required field is missing',
          'examples[0].output.agenda: is not defined in the schema',
        ]),
      );
    });

    test('example values over the limits and wrong enum values', () {
      final example = (def['examples']! as List).first as Map<String, Object?>;
      sub(example, 'output')['title'] = 'x' * 81;
      expectIssue(def, 'examples[0].output.title', ['81 chars, maxLength']);
      def = builtinMap('warranty');
      final w = (def['examples']! as List).first as Map<String, Object?>;
      sub(sub(w, 'output'), 'warranty_period')['unit'] = 'decades';
      expectIssue(def, 'examples[0].output.warranty_period.unit', [
        'is not one of days, weeks, months, years',
      ]);
    });

    test('at most two examples, each with transcript and output', () {
      final examples = def['examples']! as List;
      examples
        ..add(examples.first)
        ..add({'transcript': '', 'output': <String, Object?>{}, 'note': 1});
      expectIssue(def, 'examples', ['has 3 examples, max 2']);
      expectIssue(def, 'examples[2].transcript', ['non-empty']);
      expectIssue(def, 'examples[2].note', ['unknown key']);
    });

    test('consent_confirmation is a required enum', () {
      def['consent_confirmation'] = 'yes';
      expectIssue(def, 'consent_confirmation', [
        'must be one of required | optional | none',
      ]);
      def.remove('consent_confirmation');
      expectIssue(def, 'consent_confirmation', ['is required']);
    });

    test('multi-speaker profiles cannot skip consent (SEC-07)', () {
      def['consent_confirmation'] = 'none';
      expectIssue(def, 'consent_confirmation', ['stt.diarization: true']);
      def['consent_confirmation'] = 'optional';
      expect(issuesOf(def), isEmpty);
    });

    test('unknown post-processor names are errors', () {
      (def['post_process']! as List).add('translate_to_french');
      expectIssue(def, 'post_process[4]', [
        'unknown post-processor "translate_to_french"',
        'resolve_relative_dates',
      ]);
    });

    test('post-processors whose fields are missing are errors', () {
      def['post_process'] = ['compute_warranty_expiry', 'normalize_serial'];
      expectIssue(def, 'post_process[0]', ['purchase_date', 'warranty_period']);
      expectIssue(def, 'post_process[1]', ['serial_number']);
      def['post_process'] = ['sort_by_timestamp', 'sort_by_timestamp'];
      expectIssue(def, 'post_process[1]', ['listed twice']);
    });

    test('a schema field colliding with a post-processor field', () {
      final item = sub(sub(props(def), 'action_items'), 'items');
      sub(item, 'properties')['due_iso'] = {
        'type': ['string', 'null'],
        'maxLength': 10,
      };
      expectIssue(def, 'schema.action_items[].due_iso', ['collides']);
    });

    test('reduce strategies must exist and fit the field type', () {
      sub(def, 'reduce')['topics'] = 'llm_summarize';
      expectIssue(def, 'reduce.topics', ['does not fit a array field']);
      sub(def, 'reduce')['topics'] = 'average';
      expectIssue(def, 'reduce.topics', ['unknown strategy']);
      sub(def, 'reduce')
        ..['topics'] = 'union_dedupe'
        ..['agenda'] = 'first_non_null';
      expectIssue(def, 'reduce.agenda', ['not a top-level schema field']);
    });

    test('required top-level keys and enums', () {
      for (final key in ['id', 'name', 'description', 'template_id']) {
        final d = builtinMap('meeting')..remove(key);
        expectIssue(d, key, ['is required']);
      }
      def['tier'] = 'gold';
      expectIssue(def, 'tier', ['free | pro | enterprise']);
      def['version'] = 0;
      expectIssue(def, 'version', ['>= 1']);
      def['format'] = 2;
      expectIssue(def, 'format', ['format 1']);
    });

    test('unknown keys and app-owned keys are rejected', () {
      def['sourse'] = 'user';
      expectIssue(def, 'sourse', ['unknown key']);
      def['source'] = 'builtin';
      expectIssue(def, 'source', ['set by the app']);
      sub(def, 'stt')['language'] = 'en';
      expectIssue(def, 'stt.language', ['unknown key']);
    });

    test('description is one short line; name is short', () {
      def['description'] = 'line one\nline two';
      expectIssue(def, 'description', ['one line']);
      def['name'] = 'n' * 61;
      expectIssue(def, 'name', ['max 60']);
    });

    test('stt hints are bounded', () {
      sub(def, 'stt')
        ..['vocabulary'] = List.filled(30, 'Kubernetes')
        ..['num_speakers'] = 99;
      expectIssue(def, 'stt.vocabulary', ['max 200']);
      expectIssue(def, 'stt.num_speakers', ['"auto" or an integer 1-10']);
    });

    test('filename pattern tokens are checked', () {
      def['filename_pattern'] = '{{date:YYYY-MM-DD}}-{{speaker}}.txt';
      expectIssue(def, 'filename_pattern', ['unknown token "{{speaker}}"']);
      expectIssue(def, 'filename_pattern', ['end with ".md"']);
      def['filename_pattern'] = '../{{date:YYYY/MM}}.md';
      expectIssue(def, 'filename_pattern', ['".." segments']);
      expectIssue(def, 'filename_pattern', ['date token']);
    });

    test('every problem is reported at once', () {
      def
        ..['id'] = 'X'
        ..['instructions'] = 'x' * 3000
        ..['consent_confirmation'] = 'maybe';
      sub(props(def), 'title').remove('maxLength');
      final issues = issuesOf(def);
      expect(issues.length, greaterThanOrEqualTo(4));
    });

    test(
      'Profile.fromJson throws a ProfileFormatException with the issues',
      () {
        def['tier'] = 'gold';
        expect(
          () => Profile.fromJson(def),
          throwsA(
            isA<ProfileFormatException>().having(
              (e) => e.toString(),
              'message',
              contains('tier: must be one of'),
            ),
          ),
        );
      },
    );

    test('YAML syntax errors carry line and column', () {
      final (map, issues) = ProfileCodec.decodeYaml('id: [meeting\nname: x');
      expect(map, isNull);
      expect(
        issues.single.toString(),
        startsWith('yaml: invalid YAML at line'),
      );
      expect(ProfileCodec.decodeJson('{').$2.single.path, 'json');
      expect(
        ProfileCodec.decodeJson('[1]').$2.single.message,
        contains('JSON'),
      );
    });

    test('issue messages never echo field values', () {
      final example = (def['examples']! as List).first as Map<String, Object?>;
      sub(example, 'output')['title'] = 'SECRET-PROJECT-NAME ' * 10;
      final issues = issuesOf(def).join('\n');
      expect(issues, contains('examples[0].output.title'));
      expect(issues, isNot(contains('SECRET')));
    });
  });

  test('model round-trips through canonical JSON', () {
    final p = validator.validate(def).profile!;
    final again = validator.validate(p.toJson()).profile!;
    expect(again.toJson(), p.toJson());
    expect(p.toJson().containsKey('source'), isFalse);
    expect(p.toJson(includeSource: true)['source'], 'user');
    final builtin = validator.validate(def, source: ProfileSource.builtin);
    expect(builtin.profile!.isReadOnly, isTrue);
    expect(p.isReadOnly, isFalse);
    expect(p.ref, (id: 'meeting', version: 1));
  });

  test('reduce defaults follow the spec', () {
    final p = Profile.fromJson(def..remove('reduce'));
    expect(p.reduceStrategyFor('attendees'), ReduceStrategy.unionDedupe);
    expect(p.reduceStrategyFor('summary'), ReduceStrategy.llmSummarize);
    expect(p.reduceStrategyFor('title'), ReduceStrategy.llmSummarize);
    final w = Profile.fromJson(builtinMap('warranty'));
    expect(w.reduceStrategyFor('serial_number'), ReduceStrategy.firstNonNull);
    expect(w.reduceStrategyFor('notes'), ReduceStrategy.llmSummarize);
  });

  test('extraction fingerprint changes only with extraction content', () {
    final p = Profile.fromJson(def);
    final renamed = Profile.fromJson({...def, 'name': 'Team sync'});
    expect(renamed.extractionFingerprint, p.extractionFingerprint);
    final edited = Profile.fromJson({...def, 'instructions': 'Be brief.'});
    expect(edited.extractionFingerprint, isNot(p.extractionFingerprint));
  });
}
