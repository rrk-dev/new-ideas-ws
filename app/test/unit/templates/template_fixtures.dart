import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/builtin_profiles.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';
import 'package:vaultvoice/features/templates/domain/note_context.dart';
import 'package:vaultvoice/features/templates/domain/template_engine.dart';
import 'package:vaultvoice/features/templates/domain/template_lambdas.dart';

const engine = MarkdownTemplateEngine();

/// Built-in profiles parsed from `app/assets/profiles/` (cwd = `app/`).
final BuiltinProfiles builtinProfiles = BuiltinProfiles.parse({
  for (final p in kBuiltinProfileAssets) p: File(p).readAsStringSync(),
});

/// Built-in templates parsed from `app/assets/templates/`.
final BuiltinTemplates builtinTemplates = BuiltinTemplates.parse({
  for (final t in kBuiltinTemplates)
    t.assetPath: File(t.assetPath).readAsStringSync(),
});

String templateSource(String id) =>
    File('assets/templates/$id.mustache').readAsStringSync();

Profile profile(String id) => builtinProfiles[id]!;

/// 10 000 characters of mixed adversarial text.
final String tenK = () {
  const chunk = 'Lorem "ipsum" {{x}} --- # [[y]] 🎉 שלום ';
  final b = StringBuffer();
  while (b.length < 10000) {
    b.write(chunk);
  }
  return b.toString().substring(0, 10000);
}();

/// Strings that try to break front-matter, Markdown structure or the
/// template: quotes, `---`, `#`, `{{`, wikilinks, HTML comments, fences,
/// emoji (incl. ZWJ sequences and flags), RTL text and bidi controls.
const List<String> adversarialStrings = [
  'He said "hi" and \'bye\' \\ backslash',
  '---\ninjected: true\n---',
  '# Not a heading',
  '{{data.title}} {{#meta}}x{{/meta}} {{{raw}}}',
  '[[Secret Note]] ![[embed.png]]',
  '<!-- hide everything after -->',
  '```\ncode fence\n```',
  '> quote\n- list\n* star',
  'Emoji 🎉👩\u200D👩\u200D👧\u200D👦🇩🇪 done',
  'مرحبا بالعالم שלום עולם \u202Eevil\u202C',
  'key: value # comment',
  'yes',
  '14:05',
  '| pipe | table |',
  'tab\there\r\nwindows line',
];

/// Meeting data with every optional field non-null.
Map<String, Object?> meetingFull() => {
  'title': 'Q4 Planning Sync',
  'summary':
      'The team agreed on the Q4 roadmap. Sam owns the SDK update and '
      'Priya the migration guide.',
  'attendees': ['Priya', 'Sam', 'Lena'],
  'decisions': ['Ship API v2 in November', 'Freeze v1 on Dec 1'],
  'action_items': [
    {
      'task': 'Update the client SDK',
      'owner': 'Sam',
      'due': 'Friday',
      'due_iso': '2026-10-16',
      't': '00:00:12',
    },
    {
      'task': 'Draft the migration guide',
      'owner': 'Priya',
      'due': 'end of month',
      'due_iso': '2026-10-31',
      't': '00:01:05',
    },
  ],
  'open_questions': ['Who signs off on the deprecation notice?'],
  'topics': ['API versioning', 'Roadmap'],
};

/// Warranty data with every optional field non-null.
Map<String, Object?> warrantyFull() => {
  'product': 'Espresso machine',
  'brand': 'Bialetti',
  'model': 'Brikka 4',
  'serial_number': 'SN12345XYZ',
  'purchase_date': 'last Monday',
  'purchase_date_iso': '2026-10-05',
  'retailer': 'Corner Shop',
  'price': '129 EUR',
  'warranty_period': {'value': 2, 'unit': 'years'},
  'warranty_expiry': '2028-10-05',
  'support_contacts': ['+49 30 1234567', 'support@example.com'],
  'notes': 'Receipt is in the kitchen drawer.',
};

/// Engineering data with every optional field non-null.
Map<String, Object?> engineeringFull() => {
  'title': 'Sync engine design',
  'context': 'Offline edits conflict when two devices change one note.',
  'concepts': ['CRDT', 'Vector clocks'],
  'api_designs': [
    {
      'name': 'SyncService',
      'description': 'Merges local and remote change sets.',
      'endpoints_or_signatures': [
        'Future<void> push(ChangeSet set)',
        'Stream<ChangeSet> pull()',
      ],
    },
  ],
  'tradeoffs': [
    {
      'option': 'CRDT',
      'pros': ['No conflicts', 'Offline first'],
      'cons': ['Metadata overhead'],
    },
    {
      'option': 'Last write wins',
      'pros': ['Simple'],
      'cons': ['Loses edits', 'Clock skew'],
    },
  ],
  'decisions': ['Prototype with a CRDT library'],
  'todos': [
    {'task': 'Benchmark CRDT size', 'owner': 'Lena', 't': '00:03:10'},
  ],
  'open_questions': ['How large do tombstones get?'],
};

/// Lecture data with every optional field non-null.
Map<String, Object?> lectureFull() => {
  'title': 'Introduction to Graph Algorithms',
  'summary':
      'The lecture introduced breadth-first search and Dijkstra shortest '
      'paths, and set the first problem set.',
  'key_concepts': [
    {
      'term': 'Breadth-first search',
      'explanation': 'Visits vertices in order of distance from the source.',
    },
    {
      'term': 'Relaxation',
      'explanation': 'Updating a distance when a shorter path is found.',
    },
  ],
  'outline': [
    {
      'heading': 'Graph basics',
      'points': ['Vertices and edges', 'Adjacency lists'],
    },
    {
      'heading': 'Shortest paths',
      'points': ['BFS for unweighted graphs', 'Dijkstra for weights'],
    },
  ],
  'assignments': [
    {
      'task': 'Finish problem set 1',
      'due': 'next Friday',
      'due_iso': '2026-10-23',
      't': '00:41:10',
    },
    {'task': 'Read chapter 22', 'due': null, 'due_iso': null, 't': '00:42:30'},
  ],
  'questions': ['Why does Dijkstra fail with negative edges?'],
  'references': ['Introduction to Algorithms, chapter 22'],
};

/// Sales conversation data with every optional field non-null.
Map<String, Object?> salesCallFull() => {
  'title': 'Northwind pilot discussion',
  'summary':
      'Ana from Contoso Cloud met Ben from Northwind to discuss a pilot of '
      'the reporting product. Ben raised price and migration effort.',
  'participants': ['Ana', 'Ben'],
  'needs': ['Weekly reports without manual exports', 'Single sign-on'],
  'objections': [
    {
      'objection': 'The price is above the current budget',
      'response': 'Ana offered a smaller pilot tier',
    },
    {'objection': 'Migration may take too long', 'response': null},
  ],
  'commitments': [
    {'who': 'Ana', 'what': 'Share a migration plan', 't': '00:21:40'},
    {'who': 'Ben', 'what': 'Ask finance about the budget', 't': '00:22:05'},
  ],
  'next_steps': [
    {
      'task': 'Send the pilot proposal',
      'owner': 'Ana',
      'due': 'Friday',
      'due_iso': '2026-10-16',
      't': '00:23:10',
    },
    {
      'task': 'Book a follow-up meeting with finance',
      'owner': null,
      'due': null,
      'due_iso': null,
      't': '00:24:00',
    },
  ],
  'competitors_mentioned': ['Fabrikam Reports'],
  'open_questions': ['Which team will own the rollout?'],
};

/// Fills every string of the value (recursively) with adversarial text.
Object? adversarial(Object? value, [int seed = 0]) {
  var i = seed;
  Object? walk(Object? v) {
    if (v is String) {
      i++;
      if (i % 7 == 0) return tenK;
      return adversarialStrings[i % adversarialStrings.length];
    }
    if (v is Map<String, Object?>) {
      return {for (final e in v.entries) e.key: walk(e.value)};
    }
    if (v is List<Object?>) return [for (final e in v) walk(e)];
    return v;
  }

  return walk(value);
}

/// Metadata with every optional field set.
Map<String, Object?> metaFull({String profileId = 'meeting'}) => buildNoteMeta(
  recordingId: '0f8d2c1e-7a5b-4c3d-9e1f-2a3b4c5d6e7f',
  title: 'Recording title',
  createdAt: DateTime(2026, 10, 13, 14, 5),
  durationMs: 3723000,
  profileId: profileId,
  profileName: profile(profileId).name,
  appVersion: '1.0.0',
  speakers: const [(label: 'S1', name: 'Priya'), (label: 'S2', name: 'Sam')],
  tags: const ['work', '#planning'],
  markers: const [(atMs: 12000, label: 'Important', kind: 'user')],
  sttModel: 'ggml-base',
  llmModel: 'qwen2.5-3b-q4',
  device: 'Pixel 8',
  consentAt: DateTime.utc(2026, 10, 13, 12, 4, 30),
);

/// Metadata with every optional field null / empty.
Map<String, Object?> metaEmpty({String profileId = 'meeting'}) => buildNoteMeta(
  recordingId: 'rec-empty',
  createdAt: DateTime(2026, 1, 2, 3, 4),
  durationMs: 45000,
  profileId: profileId,
  profileName: profile(profileId).name,
  appVersion: '1.0.0',
);

Map<String, Object?> transcriptFull() => buildNoteTranscript(const [
  (startMs: 5000, speaker: 'Priya', text: "Let's lock the API version."),
  (startMs: 12000, speaker: 'Sam', text: "I'll update the SDK by Friday."),
  (startMs: 65000, speaker: null, text: 'Background noise.'),
]);

Map<String, Object?> contextFor(
  String profileId,
  Map<String, Object?> data, {
  Map<String, Object?>? meta,
  Map<String, Object?>? transcript,
}) => buildRenderContext(
  profile: profile(profileId),
  data: data,
  meta: meta ?? metaFull(profileId: profileId),
  transcript: transcript ?? transcriptFull(),
);

/// Renders built-in template [id]; fails the test on warnings.
String renderBuiltin(
  String id,
  Map<String, Object?> context, {
  LambdaOptions options = const LambdaOptions(),
}) {
  final note = engine.render(builtinTemplates[id]!, context, options: options);
  expect(note.warnings, isEmpty, reason: 'template $id rendered with warnings');
  return note.markdown;
}

/// Shape a built-in template is written for.
MapShape shapeForTemplate(BuiltinTemplateInfo info) => info.profileId == null
    ? kSummaryOnlyRootShape
    : rootShapeFor(profile(info.profileId!));

/// A custom profile using every field kind the PRF-07 editor can produce.
Profile customProfile() => Profile.fromJson({
  'format': 1,
  'id': 'site-visit',
  'version': 1,
  'name': 'Site visit',
  'description': 'Notes from a construction site visit.',
  'tier': 'pro',
  'instructions': '- Extract only what is said.',
  'template_id': 'site-visit-template',
  'consent_confirmation': 'optional',
  'post_process': ['resolve_relative_dates'],
  'schema': {
    'type': 'object',
    'required': <String>[],
    'properties': {
      'site': {'type': 'string', 'maxLength': 80},
      'report': {
        'type': ['string', 'null'],
        'maxLength': 2000,
      },
      'visit_date': {
        'type': ['string', 'null'],
        'maxLength': 40,
      },
      'workers': {
        'type': ['integer', 'null'],
      },
      'safe': {'type': 'boolean'},
      'passed': {
        'type': ['boolean', 'null'],
      },
      'status': {
        'type': 'string',
        'enum': ['open', 'closed'],
      },
      'issues': {
        'type': 'array',
        'maxItems': 10,
        'items': {'type': 'string', 'maxLength': 200},
      },
      'checks': {
        'type': 'array',
        'maxItems': 10,
        'items': {
          'type': 'object',
          'required': ['text', 'done'],
          'properties': {
            'text': {'type': 'string', 'maxLength': 100},
            'done': {'type': 'boolean'},
            'owner': {
              'type': ['string', 'null'],
              'maxLength': 40,
            },
            'due': {
              'type': ['string', 'null'],
              'maxLength': 40,
            },
          },
        },
      },
      'measurements': {
        'type': 'array',
        'maxItems': 10,
        'items': {
          'type': 'object',
          'required': ['name', 'value'],
          'properties': {
            'name': {'type': 'string', 'maxLength': 40},
            'value': {'type': 'number'},
          },
        },
      },
      'contact': {
        'type': ['object', 'null'],
        'required': ['name'],
        'properties': {
          'name': {'type': 'string', 'maxLength': 60},
          'phone': {
            'type': ['string', 'null'],
            'maxLength': 30,
          },
          'emails': {
            'type': 'array',
            'maxItems': 3,
            'items': {'type': 'string', 'maxLength': 80},
          },
        },
      },
    },
  },
});

Map<String, Object?> customFull() => {
  'site': 'North tower | level 3',
  'report': 'Concrete poured.\n\n# not a heading',
  'visit_date': 'today',
  'visit_date_iso': '2026-10-13',
  'workers': 12,
  'safe': true,
  'passed': false,
  'status': 'open',
  'issues': ['Loose rail', '{{x}}'],
  'checks': [
    {'text': 'Helmets', 'done': true, 'owner': 'Lena', 'due': null},
    {
      'text': 'Scaffold tags',
      'done': false,
      'owner': null,
      'due': 'Friday',
      'due_iso': '2026-10-16',
    },
  ],
  'measurements': [
    {'name': 'Slab', 'value': 21.5},
  ],
  'contact': {
    'name': 'Ana',
    'phone': '+1 555',
    'emails': ['ana@example.com'],
  },
};

/// Interview data with every optional field non-null.
Map<String, Object?> interviewFull() => {
  'title': 'Sensor drift research interview',
  'summary':
      'Dana interviewed Ravi about a research project on seasonal sensor '
      'drift and what the team learned about calibration.',
  'participants': [
    {'name': 'Dana', 'role': 'interviewer'},
    {'name': 'Ravi', 'role': 'interviewee'},
  ],
  'topics': ['Sensor drift', 'Calibration', 'Field deployment'],
  'qa_highlights': [
    {
      'question': 'How did the research project start?',
      'answer': 'The team noticed the sensors drifted every winter.',
      't': '00:00:12',
    },
    {
      'question': 'What did you learn?',
      'answer': 'Calibration matters more than hardware.',
      't': '00:00:48',
    },
  ],
  'quotes': [
    {
      'speaker': 'Ravi',
      'text': 'Calibration matters more than hardware.',
      't': '00:00:48',
    },
  ],
  'follow_ups': [
    {
      'task': 'Email the written questions',
      'owner': 'Dana',
      'due': 'Friday',
      'due_iso': '2026-10-16',
      't': '00:01:10',
    },
    {
      'task': 'Share the calibration notes',
      'owner': null,
      'due': null,
      'due_iso': null,
      't': '00:01:20',
    },
  ],
  'open_questions': ['How often should sensors be recalibrated?'],
};
