import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/features/profiles/domain/profile_draft.dart';
import 'package:vaultvoice/features/profiles/domain/profile_validator.dart';
import 'package:vaultvoice/features/templates/domain/template_generator.dart';

import 'profile_fixtures.dart';

const _fields = [
  FieldSpec(name: 'goal', kind: FieldKind.text),
  FieldSpec(name: 'notes', kind: FieldKind.longText),
  FieldSpec(name: 'risks', kind: FieldKind.textList),
  FieldSpec(name: 'when', kind: FieldKind.date),
  FieldSpec(name: 'budget', kind: FieldKind.number),
  FieldSpec(name: 'approved', kind: FieldKind.boolean),
  FieldSpec(name: 'tasks', kind: FieldKind.checkboxList),
  FieldSpec(
    name: 'stories',
    kind: FieldKind.table,
    columns: [
      ColumnSpec(name: 'story'),
      ColumnSpec(name: 'points', kind: ColumnKind.number),
      ColumnSpec(name: 'due', kind: ColumnKind.date),
      ColumnSpec(name: 'done', kind: ColumnKind.boolean),
    ],
  ),
];

void main() {
  test('[PRF-07/AC1] reopening and re-saving does not stack the fixed '
      'instruction lines', () {
    var draft = const ProfileDraft(
      id: 'idem',
      name: 'Idem',
      instructions: '- Be brief.',
      fields: _fields,
    );
    final first = validateDraft(draft).profile!;
    for (var i = 0; i < 3; i++) {
      draft = ProfileDraft.fromProfile(validateDraft(draft).profile!)
          .copyWith(id: 'idem');
    }
    final again = validateDraft(draft).profile!;
    expect(again.instructions, first.instructions);
    expect(draft.instructions, '- Be brief.');
  });

  test('[PRF-07/AC1] every field kind generates a valid, bounded schema and '
      'a template that passes the strict variable check', () {
    const draft = ProfileDraft(
      id: 'all-kinds',
      name: 'All kinds',
      fields: _fields,
    );
    expect(draft.check(), isEmpty);
    final v = validateDraft(draft);
    expect(v.issues.map((i) => '$i'), isEmpty);
    final profile = v.profile!;
    expect(profile.consentConfirmation.name, 'required');
    expect(
      const ProfileValidator().validateTemplate(
        profile,
        generateTemplate(profile),
      ),
      isEmpty,
    );
    // Round trip: the editor reads its own schema back field by field.
    final again = ProfileDraft.fromProfile(profile);
    expect(
      [for (final f in again.fields) (f.name, f.kind)],
      [for (final f in _fields) (f.name, f.kind)],
    );
    expect(
      again.fields.last.columns.map((c) => c.kind),
      _fields.last.columns.map((c) => c.kind),
    );
  });

  test('inline issues: name, fields, names, duplicates, columns', () {
    final d = ProfileDraft.empty().copyWith(
      fields: const [
        FieldSpec(name: '1bad', kind: FieldKind.text),
        FieldSpec(name: 'has_x', kind: FieldKind.text),
        FieldSpec(name: 'ok', kind: FieldKind.text),
        FieldSpec(name: 'ok', kind: FieldKind.text),
        FieldSpec(name: 'tbl', kind: FieldKind.table),
      ],
    );
    expect(
      [for (final i in d.check()) (i.kind, i.field)],
      [
        (DraftIssueKind.nameMissing, null),
        (DraftIssueKind.fieldName, 0),
        (DraftIssueKind.fieldName, 1),
        (DraftIssueKind.duplicateField, 3),
        (DraftIssueKind.columns, 4),
      ],
    );
    expect(ProfileDraft.empty().check().map((i) => i.kind), [
      DraftIssueKind.nameMissing,
      DraftIssueKind.noFields,
    ]);
  });

  test('examples typed as plain text become schema-valid outputs', () {
    const ex = ExampleDraft(
      transcript: '[00:00:01] Ana: Goal is launch.',
      values: {
        'goal': 'Launch',
        'risks': 'Late keys\n\nBudget',
        'budget': '1200',
        'approved': 'yes',
        'tasks': '[x] Book room\nWrite notes',
        'stories': 'Sync | 8 | next week | no',
      },
    );
    final out = ex.toOutput(_fields);
    expect(out['goal'], 'Launch');
    expect(out['notes'], isNull);
    expect(out['risks'], ['Late keys', 'Budget']);
    expect(out['budget'], 1200);
    expect(out['approved'], true);
    expect(out['tasks'], [
      {'task': 'Book room', 'done': true},
      {'task': 'Write notes', 'done': false},
    ]);
    expect(out['stories'], [
      {'story': 'Sync', 'points': 8, 'due': 'next week', 'done': false},
    ]);
    final draft = const ProfileDraft(
      id: 'with-example',
      name: 'With example',
      fields: _fields,
    ).copyWith(examples: const [ex]);
    final v = validateDraft(draft);
    expect(v.issues.map((i) => '$i'), isEmpty);
    final back = ExampleDraft.fromExample(v.profile!.examples.single, _fields);
    expect(back.values['tasks'], '[x] Book room\n[ ] Write notes');
    expect(back.values['stories'], 'Sync | 8 | next week | false');
  });

  test('ids and field names are derived safely', () {
    expect(fieldNameFrom('Due date!'), 'due_date');
    expect(fieldNameFrom('42 things'), 'field_42_things');
    expect(fieldNameFrom('has owner'), 'f_has_owner');
    expect(
      profileIdFrom('Sprint Planning', {'sprint-planning'}),
      'sprint-planning-2',
    );
    expect(profileIdFrom('!', {}), 'profile');
  });

  test(
    'duplicating a built-in keeps unsupported shapes as advanced fields',
    () {
      final draft = ProfileDraft.fromProfile(builtinProfile('meeting'));
      final kinds = {for (final f in draft.fields) f.name: f.kind};
      expect(kinds['title'], FieldKind.text);
      expect(kinds['summary'], FieldKind.longText);
      expect(kinds['attendees'], FieldKind.textList);
      expect(kinds['action_items'], FieldKind.table);
      final copy = draft.copyWith(id: 'meeting-copy-1', name: 'Copy');
      expect(validateDraft(copy).issues.map((i) => '$i'), isEmpty);
    },
  );
}
