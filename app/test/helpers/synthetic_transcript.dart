import 'package:vaultvoice/features/extraction/domain/long_transcript/transcript_chunker.dart';

/// Synthetic meeting transcript (no real people): one segment every
/// [stepSeconds] for [minutes], four speakers taking turns of 1–3 segments,
/// and a planted action item (`ACTION <task>.`) every [actionEveryMinutes]
/// with a unique task text. Sized by token count, not wall time: 2 h at a
/// 4 s cadence ≈ 1800 segments ≈ 30k tokens (> 7× a 4k context).
({
  List<TranscriptLine> lines,
  List<({String task, String owner, String t})> actions,
})
syntheticMeeting({
  int minutes = 120,
  int stepSeconds = 4,
  int actionEveryMinutes = 5,
  bool speakers = true,
}) {
  const people = ['Ana', 'Ben', 'Chen', 'Dara'];
  const filler = [
    'I think we should look at the numbers from last week before deciding',
    'the device lab results look stable but the battery drain is still high',
    'can we move the review to Thursday so the design team can join us',
    'the release checklist has three open items and two of them are blocked',
    'let us keep the scope small and ship the first version on time',
    'we heard from the vendor and the contract draft needs another pass',
  ];
  const objects = [
    'the battery report',
    'the store screenshots',
    'the vendor contract',
    'the onboarding copy',
    'the crash triage notes',
    'the pricing table',
    'the accessibility audit',
    'the release notes',
  ];
  final lines = <TranscriptLine>[];
  final actions = <({String task, String owner, String t})>[];
  var turn = 0;
  var turnLeft = 1;
  var nextAction = actionEveryMinutes * 60;
  var k = 0;
  for (var s = 0; s < minutes * 60; s += stepSeconds) {
    if (--turnLeft < 0) {
      turn = (turn + 1) % people.length;
      turnLeft = 1 + (s ~/ stepSeconds) % 3;
    }
    final who = people[turn];
    String text;
    if (s >= nextAction) {
      nextAction += actionEveryMinutes * 60;
      final task = 'prepare ${objects[k % objects.length]} for milestone $k';
      k++;
      text = 'Okay, ACTION $task. I will send it around.';
      actions.add((task: task, owner: who, t: formatTimestamp(s * 1000)));
    } else {
      text = '${filler[(s ~/ stepSeconds) % filler.length]}.';
    }
    lines.add(
      TranscriptLine(
        startMs: s * 1000,
        speaker: speakers ? who : null,
        text: text,
      ),
    );
  }
  return (lines: lines, actions: actions);
}

/// Built-in-Meeting-shaped output schema (subset used by the tests).
const Map<String, Object?> meetingTestSchema = {
  'type': 'object',
  'required': [
    'title',
    'summary',
    'attendees',
    'decisions',
    'action_items',
    'open_questions',
    'topics',
  ],
  'properties': {
    'title': {'type': 'string', 'maxLength': 80, 'description': 'Short title'},
    'summary': {
      'type': 'string',
      'maxLength': 600,
      'description': '2-4 sentence summary',
    },
    'attendees': {
      'type': 'array',
      'maxItems': 20,
      'items': {'type': 'string', 'maxLength': 60},
    },
    'decisions': {
      'type': 'array',
      'maxItems': 30,
      'items': {'type': 'string', 'maxLength': 200},
    },
    'action_items': {
      'type': 'array',
      'maxItems': 50,
      'items': {
        'type': 'object',
        'required': ['task', 'owner', 'due', 't'],
        'properties': {
          'task': {'type': 'string', 'maxLength': 200},
          'owner': {
            'type': ['string', 'null'],
            'maxLength': 60,
          },
          'due': {
            'type': ['string', 'null'],
            'maxLength': 40,
          },
          't': {
            'type': ['string', 'null'],
            'maxLength': 8,
          },
        },
      },
    },
    'open_questions': {
      'type': 'array',
      'maxItems': 20,
      'items': {'type': 'string', 'maxLength': 200},
    },
    'topics': {
      'type': 'array',
      'maxItems': 10,
      'items': {'type': 'string', 'maxLength': 40},
    },
  },
};

/// Action-item recall of [extracted] against [expected] (fuzzy task match,
/// one-to-one, token Jaccard ≥ 0.6 — the PRF-09 list-field rule).
double actionItemRecall(
  List<Object?> extracted,
  List<({String task, String owner, String t})> expected,
  double Function(String, String) similarity,
) {
  if (expected.isEmpty) return 1;
  final pool = [
    for (final e in extracted)
      if (e is Map) (e['task'] as String?) ?? '',
  ];
  var hit = 0;
  for (final x in expected) {
    var best = -1;
    var bestScore = 0.0;
    for (var i = 0; i < pool.length; i++) {
      final s = similarity(x.task, pool[i]);
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    if (best >= 0 && bestScore >= 0.6) {
      hit++;
      pool.removeAt(best);
    }
  }
  return hit / expected.length;
}
