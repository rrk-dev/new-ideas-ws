import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';

import 'profile_fixtures.dart';

const validator = ProfileValidator();

void main() {
  late Profile meeting;
  setUp(() => meeting = Profile.fromJson(builtinMap('meeting')));

  List<String> check(String template, [Profile? profile]) => [
    for (final i in validator.validateTemplate(profile ?? meeting, template))
      i.toString(),
  ];

  test('the default meeting template only uses schema + metadata '
      'variables', () {
    expect(check(meetingTemplate()), isEmpty);
  });

  group('[PRF-01/AC2] template variables must match schema fields', () {
    test('unknown variable with position and a suggestion', () {
      final issues = check('# {{data.title}}\n\n{{data.atendees.0}}');
      expect(issues, hasLength(1));
      expect(
        issues.single,
        startsWith('template:3:1: unknown variable "data.atendees.0"'),
      );
      expect(issues.single, contains('did you mean data.attendees?'));
    });

    test('a field removed from the schema breaks the template', () {
      final def = builtinMap('meeting');
      props(def).remove('topics');
      sub(def, 'reduce').remove('topics');
      (sub(def, 'schema')['required']! as List).remove('topics');
      final example = (def['examples']! as List).first as Map;
      (example['output'] as Map).remove('topics');
      final noTopics = Profile.fromJson(def);
      final issues = check(meetingTemplate(), noTopics);
      expect(issues, isNotEmpty);
      expect(
        issues,
        everyElement(
          anyOf(contains('"has_topics"'), contains('"data.topics"')),
        ),
      );
    });

    test('item fields resolve inside their section only', () {
      expect(
        check(
          '{{#data.action_items}}{{task}} {{meta.date}} '
          '{{/data.action_items}}',
        ),
        isEmpty,
      );
      expect(check('{{task}}').single, contains('unknown variable "task"'));
    });

    test('post-processor fields are variables only when the processor is '
        'listed', () {
      const t =
          '{{#data.action_items}}{{#has_due_iso}}{{due_iso}}{{/has_due_iso}}'
          '{{/data.action_items}}';
      expect(check(t), isEmpty);
      final def = builtinMap('meeting');
      (def['post_process']! as List).remove('resolve_relative_dates');
      expect(check(t, Profile.fromJson(def)), hasLength(2));
      final warranty = Profile.fromJson(builtinMap('warranty'));
      expect(
        check(
          '{{#data.has_warranty_expiry}}{{data.warranty_expiry}}'
          '{{/data.has_warranty_expiry}} {{data.purchase_date_iso}}',
          warranty,
        ),
        isEmpty,
      );
    });

    test('a section on a string throws in strict mode: suggest has_', () {
      final issues = check('{{#data.title}}x{{/data.title}}');
      expect(issues.single, contains('"data.title" is a string'));
      expect(issues.single, contains('{{#data.has_title}}'));
      expect(
        check(
          '{{#data.action_items}}{{^owner}}?{{/owner}}'
          '{{/data.action_items}}',
        ).single,
        contains('{{^has_owner}}'),
      );
    });

    test('a list or object printed as a variable is flagged', () {
      expect(check('{{data.attendees}}').single, contains('is a list'));
      expect(check('{{meta.model_ids}}').single, contains('is an object'));
      expect(
        check('{{#data.action_items}}{{.}}{{/data.action_items}}').single,
        contains('"." is an object'),
      );
    });

    test('lambdas: content, text-argument and path-argument forms', () {
      expect(
        check(
          '{{#yaml}}{{data.title}}{{/yaml}} {{#date}}YYYY-MM-DD{{/date}} '
          '{{#yaml_list}}data.attendees{{/yaml_list}} {{transcript_block}}',
        ),
        isEmpty,
      );
      expect(
        check('{{#yaml}}{{data.titel}}{{/yaml}}').single,
        contains('unknown variable "data.titel"'),
      );
      expect(
        check('{{#yaml_list}}data.title{{/yaml_list}}').single,
        contains('must be a list'),
      );
      expect(
        check('{{#yaml_list}}data.nope{{/yaml_list}}').single,
        contains('not a variable path'),
      );
    });

    test('structure errors: unbalanced, unclosed, partials, delimiters', () {
      expect(
        check('{{#data.decisions}}x{{/data.topics}}').first,
        contains('open section is "data.decisions"'),
      );
      expect(check('{{#data.decisions}}x').single, contains('never closed'));
      expect(check('{{/data.decisions}}').single, contains('without an open'));
      expect(check('{{> header}}').single, contains('partials'));
      expect(check('{{=<% %>=}}').single, contains('delimiters'));
      expect(check('{{data.title').single, contains('never closed'));
      expect(check('{{#yaml_list}}data.attendees').single, contains('never'));
      expect(check('{{}}').single, contains('empty tag'));
    });

    test('comments, triple mustache and & are handled', () {
      expect(check('{{! {{nope}} is ignored }}{{{data.title}}}'), isEmpty);
      expect(check('{{& data.summary}}'), isEmpty);
      expect(check('{{{data.nope}}}'), hasLength(1));
    });

    test('root has_ aliases and meta/transcript helpers exist', () {
      expect(
        check(
          '{{#has_attendees}}a{{/has_attendees}}'
          '{{#meta.has_consent_at}}{{meta.consent_at}}{{/meta.has_consent_at}}'
          '{{#transcript.segments}}{{#has_speaker}}{{speaker}}{{/has_speaker}}'
          '{{text}}{{/transcript.segments}}',
        ),
        isEmpty,
      );
    });
  });
}
