import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/routing_engine.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';

const _meeting = RoutingInput(
  profileId: 'meeting',
  title: 'Q4 Planning with ACME',
  summary: 'Budget review and hiring.',
  tags: ['#work', 'Planning'],
  speakers: ['Priya', 'Sam'],
);

RoutingRule rule(
  String id,
  int priority,
  String target, {
  RuleMatch match = const RuleMatch(),
  RuleMode mode = RuleMode.stop,
  String subPath = '',
  bool enabled = true,
}) => RoutingRule(
  id: id,
  priority: priority,
  targetId: target,
  match: match,
  mode: mode,
  subPath: subPath,
  enabled: enabled,
);

List<String> targetsOf(List<RouteDecision> d) => [
  for (final x in d) x.targetId,
];

void main() {
  const targets = ['a', 'b', 'c'];

  test('integration W3 (AUD-08 ↔ EXP-05): a destination picked for the '
      'recording wins over the rules; an inactive one falls back', () {
    final rules = [rule('r', 1, 'b')];
    RoutingInput chose(String id) =>
        RoutingInput(profileId: 'meeting', chosenTargetId: id);
    final d = routeNote(
      input: chose('c'),
      rules: rules,
      targetIds: targets,
      policy: RoutingPolicy.unlimited,
    );
    expect(targetsOf(d), ['c']);
    expect(d.single.source, RouteSource.userChoice);
    // 'c' is beyond the Free plan's single active target: normal routing.
    final free = routeNote(
      input: chose('c'),
      rules: rules,
      targetIds: targets,
      policy: RoutingPolicy.free,
    );
    expect(targetsOf(free), ['a']);
    expect(free.single.source, RouteSource.fallback);
  });

  group('[EXP-05/AC1] ordering', () {
    test('[EXP-05/AC1] rules run by ascending priority; first stop match '
        'wins regardless of list order', () {
      final rules = [
        rule('late', 20, 'c', match: const RuleMatch(profileIds: ['meeting'])),
        rule('early', 10, 'b', match: const RuleMatch(tagsAny: ['work'])),
      ];
      final d = routeNote(
        input: _meeting,
        rules: rules,
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(targetsOf(d), ['b']);
      expect(d.single.ruleId, 'early');
      expect(d.single.source, RouteSource.rule);
    });

    test('[EXP-05/AC1] equal priorities are ordered by id (deterministic)', () {
      final d = routeNote(
        input: _meeting,
        rules: [rule('z', 1, 'c'), rule('m', 1, 'b')],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(targetsOf(d), ['b']);
    });

    test('[EXP-05/AC1] a non-matching earlier rule is skipped', () {
      final d = routeNote(
        input: _meeting,
        rules: [
          rule('w', 1, 'b', match: const RuleMatch(profileIds: ['warranty'])),
          rule('m', 2, 'c', match: const RuleMatch(profileIds: ['meeting'])),
        ],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(targetsOf(d), ['c']);
      expect(d.single.ruleId, 'm');
    });
  });

  group('[EXP-05/AC1] multi-match', () {
    test('[EXP-05/AC1] continue rules add targets until a stop rule', () {
      final d = routeNote(
        input: _meeting,
        rules: [
          rule('1', 1, 'a', mode: RuleMode.continueMatching, subPath: 'All'),
          rule(
            '2',
            2,
            'b',
            match: const RuleMatch(keywordsAny: ['acme']),
            mode: RuleMode.continueMatching,
          ),
          rule('3', 3, 'c', match: const RuleMatch(speakersAny: ['priya'])),
          rule('4', 4, 'a'), // never reached: rule 3 stops
        ],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(targetsOf(d), ['a', 'b', 'c']);
      expect(d.first.subPath, 'All');
      expect([for (final x in d) x.ruleId], ['1', '2', '3']);
    });

    test('[EXP-05/AC1] a target is used once (first matching rule wins)', () {
      final d = routeNote(
        input: _meeting,
        rules: [
          rule('1', 1, 'a', mode: RuleMode.continueMatching, subPath: 'One'),
          rule('2', 2, 'a', mode: RuleMode.continueMatching, subPath: 'Two'),
          rule('3', 3, 'b', mode: RuleMode.continueMatching),
        ],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(targetsOf(d), ['a', 'b']);
      expect(d.first.subPath, 'One');
    });
  });

  group('[EXP-05/AC1] fallback target', () {
    test('[EXP-05/AC1] no match → profile default target', () {
      final d = routeNote(
        input: const RoutingInput(
          profileId: 'meeting',
          profileDefaultTargetId: 'c',
        ),
        rules: [
          rule('w', 1, 'b', match: const RuleMatch(profileIds: ['warranty'])),
        ],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(d.single.targetId, 'c');
      expect(d.single.source, RouteSource.profileDefault);
    });

    test('[EXP-05/AC1] no match and no (usable) profile default → first '
        'active target', () {
      for (final def in [null, 'ask', 'deleted-target']) {
        final d = routeNote(
          input: RoutingInput(profileId: 'x', profileDefaultTargetId: def),
          rules: const [],
          targetIds: targets,
          policy: RoutingPolicy.unlimited,
        );
        expect(d.single.targetId, 'a', reason: '$def');
        expect(d.single.source, RouteSource.fallback);
      }
    });

    test('[EXP-05/AC1] no target at all → no destination', () {
      expect(
        routeNote(
          input: _meeting,
          rules: [rule('1', 1, 'a')],
          targetIds: const [],
          policy: RoutingPolicy.unlimited,
        ),
        isEmpty,
      );
    });

    test('[EXP-05/AC1] disabled rules and rules to missing targets are '
        'skipped', () {
      final d = routeNote(
        input: _meeting,
        rules: [rule('off', 1, 'b', enabled: false), rule('gone', 2, 'zz')],
        targetIds: targets,
        policy: RoutingPolicy.unlimited,
      );
      expect(d.single.source, RouteSource.fallback);
      expect(d.single.targetId, 'a');
    });
  });

  group('LIC-01 gating', () {
    test('Free: rules ignored and only the first target is active', () {
      final rules = [
        rule('1', 1, 'b', match: const RuleMatch(profileIds: ['meeting'])),
      ];
      final d = routeNote(
        input: const RoutingInput(
          profileId: 'meeting',
          profileDefaultTargetId: 'c',
        ),
        rules: rules,
        targetIds: targets,
        policy: RoutingPolicy.free,
      );
      expect(d.single.targetId, 'a');
      expect(d.single.source, RouteSource.fallback);
    });

    test('rules may target only active targets', () {
      final d = routeNote(
        input: _meeting,
        rules: [rule('1', 1, 'c'), rule('2', 2, 'b')],
        targetIds: targets,
        policy: const RoutingPolicy(rulesEnabled: true, maxTargets: 2),
      );
      expect(d.single.targetId, 'b');
    });

    test('policy JSON fails closed', () {
      expect(RoutingPolicy.fromJson(null), RoutingPolicy.free);
      expect(RoutingPolicy.fromJson('junk'), RoutingPolicy.free);
      expect(
        RoutingPolicy.fromJson(RoutingPolicy.unlimited.toJson()),
        RoutingPolicy.unlimited,
      );
      expect(
        RoutingPolicy.fromJson(const {'rules': true, 'max_targets': 0}),
        const RoutingPolicy(rulesEnabled: true, maxTargets: 1),
      );
    });
  });

  group('matchers', () {
    bool m(RuleMatch match, [RoutingInput input = _meeting]) =>
        ruleMatches(match, input);

    test('catch-all matches everything', () {
      expect(const RuleMatch().isCatchAll, isTrue);
      expect(m(const RuleMatch()), isTrue);
    });

    test('case-insensitive, # ignored on tags, keywords in title/summary', () {
      expect(m(const RuleMatch(tagsAny: ['WORK'])), isTrue);
      expect(m(const RuleMatch(tagsAny: ['#planning'])), isTrue);
      expect(m(const RuleMatch(tagsAny: ['home'])), isFalse);
      expect(m(const RuleMatch(keywordsAny: ['HIRING'])), isTrue);
      expect(m(const RuleMatch(keywordsAny: ['acme'])), isTrue);
      expect(m(const RuleMatch(keywordsAny: ['invoice', ' '])), isFalse);
      expect(m(const RuleMatch(speakersAny: ['sam'])), isTrue);
      expect(m(const RuleMatch(speakersAny: ['alex'])), isFalse);
      expect(m(const RuleMatch(profileIds: ['Meeting'])), isTrue);
    });

    test('conditions are ANDed', () {
      expect(
        m(const RuleMatch(profileIds: ['meeting'], speakersAny: ['alex'])),
        isFalse,
      );
      expect(
        m(const RuleMatch(profileIds: ['meeting'], speakersAny: ['priya'])),
        isTrue,
      );
    });

    test('classification needs a classification result', () {
      const c = RuleMatch(classificationAny: ['warranty']);
      expect(m(c), isFalse);
      expect(
        m(
          c,
          const RoutingInput(
            profileId: 'meeting',
            classifiedProfileId: 'warranty',
          ),
        ),
        isTrue,
      );
    });

    test('NFC: composed and decomposed umlauts match', () {
      expect(
        m(
          const RuleMatch(speakersAny: ['Jürgen']),
          const RoutingInput(profileId: 'x', speakers: ['Jürgen']),
        ),
        isTrue,
      );
    });
  });

  group('persistence', () {
    test('rule round-trips through the routing_rules columns', () {
      const r = RoutingRule(
        id: 'r1',
        priority: 3,
        targetId: 't',
        match: RuleMatch(
          profileIds: ['meeting'],
          tagsAny: ['a'],
          keywordsAny: ['k'],
          speakersAny: ['s'],
          classificationAny: ['c'],
        ),
        mode: RuleMode.continueMatching,
        subPath: 'X/Y',
        filenamePattern: '{{slug}}.md',
        name: 'Work',
        enabled: false,
      );
      final back = RoutingRule.fromRow(
        id: r.id,
        priority: r.priority,
        targetId: r.targetId,
        match: r.matchJson(),
        subPath: r.subPath,
        filenamePattern: r.filenamePattern,
      );
      expect(back.matchJson(), r.matchJson());
      expect(back.mode, RuleMode.continueMatching);
      expect(back.enabled, isFalse);
      expect(back.name, 'Work');
      expect(
        RoutingRule.fromRow(
          id: 'x',
          priority: 0,
          targetId: 't',
          match: const {
            'mode': 'weird',
            'tags_any': [1, '', ' t '],
          },
          subPath: '',
        ).match.tagsAny,
        ['t'],
      );
    });

    test('target options round-trip; unknown values fall back', () {
      const o = VaultTargetOptions(
        collision: CollisionMode.overwrite,
        filenamePattern: '{{slug}}.md',
        transcriptSidecar: true,
        audioSidecar: true,
      );
      final map = decodeTargetOptions(encodeTargetOptions({'t': o}));
      expect(map['t'], o);
      expect(
        VaultTargetOptions.fromJson(const {'collision': 'nope'}),
        VaultTargetOptions.defaults,
      );
      expect(decodeTargetOptions(42), isEmpty);
    });

    test('sidecar paths derive from the note path', () {
      expect(SidecarPaths.transcript('M/n.md'), 'M/n.transcript.md');
      expect(SidecarPaths.audio('M/n.md', 'm4a'), 'M/attachments/n.m4a');
      expect(SidecarPaths.audio('n.md', 'm4a'), 'attachments/n.m4a');
    });
  });
}
