import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/db/database.dart';
import 'package:vaultvoice/core/db/storage_paths.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/platform/cancel_token.dart';
import 'package:vaultvoice/core/platform/diarization_engine.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_engines.dart';
import 'package:vaultvoice/features/pipeline/data/steps/diarize_step.dart';
import 'package:vaultvoice/features/pipeline/data/steps/render_write_steps.dart';
import 'package:vaultvoice/features/pipeline/domain/job_state.dart';
import 'package:vaultvoice/features/pipeline/domain/pipeline_step.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/settings/domain/setting_keys.dart';
import 'package:vaultvoice/features/templates/data/template_note_renderer.dart';
import 'package:vaultvoice/features/transcription/domain/speaker_alignment.dart';

import '../../db/db_test_utils.dart';
import '../../fakes/fake_diarization_engine.dart';
import '../pipeline/pipeline_test_utils.dart';
import '../profiles/profile_fixtures.dart';
import '../templates/template_fixtures.dart' as tf;

class _Ctx implements StepContext {
  _Ctx(this.job);

  @override
  final JobSnapshot job;
  @override
  final CancelToken cancel = CancelToken();

  @override
  void reportProgress(double fraction) {}

  @override
  Future<void> saveCheckpoint(
    Map<String, Object?> checkpoint, {
    double? progress,
    Future<void> Function()? writes,
  }) async {
    await writes?.call();
  }
}

JobSnapshot _job() => JobSnapshot(
  id: 'j1',
  recordingId: 'r1',
  state: JobState.transcribing,
  step: PipelineStepId.diarize,
  createdAt: t0,
  updatedAt: t0,
);

String _tokens(List<(String, int, int)> t) => jsonEncode([
  for (final (text, a, b) in t)
    {'text': text, 't0_ms': a, 't1_ms': b, 'p': 0.9},
]);

Profile _profile({bool? diarization, Object? numSpeakers}) {
  final def = builtinMap('meeting');
  final stt = <String, Object?>{'vocabulary': <String>[]};
  if (diarization != null) stt['diarization'] = diarization;
  if (numSpeakers != null) stt['num_speakers'] = numSpeakers;
  def['stt'] = stt;
  return Profile.fromJson(def);
}

void main() {
  group('[STT-05/AC1] aligning speaker turns to segments', () {
    const seg = AlignSegment(id: 1, startMs: 0, endMs: 4000, body: 'Hello all');

    test('[STT-05/AC1] the speaker with the most overlap wins', () {
      final out = alignSpeakers(
        [seg],
        const [SpeakerTurn(0, 1000, 2), SpeakerTurn(1000, 4200, 5)],
      );
      expect(out.single.speaker, 5);
      expect(out.single.isSplit, isFalse);
    });

    test('[STT-05/AC1] a long speaker change splits at a token boundary', () {
      final out = alignSpeakers(
        [
          AlignSegment(
            id: 2,
            startMs: 5000,
            endMs: 11000,
            body: ' one two three four',
            tokensJson: _tokens([
              (' one', 5000, 6500),
              (' two', 6500, 8000),
              (' three', 8000, 9500),
              (' four', 9500, 11000),
            ]),
          ),
        ],
        const [SpeakerTurn(5000, 8000, 3), SpeakerTurn(8000, 11000, 7)],
      );
      expect(out.map((o) => o.speaker), [3, 7]);
      expect(out.first.body.trim(), 'one two');
      expect(out.last.body.trim(), 'three four');
      expect(out.every((o) => o.isSplit), isTrue);
      expect(out.first.endMs, lessThanOrEqualTo(out.last.startMs));
    });

    test('[STT-05/AC1] a change shorter than the minimum does not split', () {
      final out = alignSpeakers(
        [
          AlignSegment(
            id: 3,
            startMs: 0,
            endMs: 4000,
            body: ' a b c',
            tokensJson: _tokens([
              (' a', 0, 1500),
              (' b', 1500, 2500),
              (' c', 2500, 4000),
            ]),
          ),
        ],
        const [
          SpeakerTurn(0, 1500, 1),
          SpeakerTurn(1500, 2200, 2),
          SpeakerTurn(2200, 4000, 1),
        ],
      );
      expect(out, hasLength(1));
      expect(out.single.speaker, 1);
    });

    test('[STT-05/AC1] silence between turns takes the nearest speaker', () {
      final out = alignSpeakers(
        [const AlignSegment(id: 4, startMs: 10000, endMs: 12000, body: 'x')],
        const [SpeakerTurn(0, 4000, 1), SpeakerTurn(13000, 15000, 2)],
      );
      expect(out.single.speaker, 2);
    });
  });

  group('[STT-05/AC1] DiarizeStep', () {
    late Directory dir;
    late StoragePaths paths;
    late VaultVoiceDatabase db;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('vv_diar_step_');
      paths = StoragePaths(dir.path);
      db = memoryDb();
      await seedRecordingWithChunks(db, 'r1', chunks: 2);
      expectOk(
        await db.transcriptsRepository.create(
          TranscriptsCompanion.insert(
            id: 't1',
            recordingId: 'r1',
            modelId: 'm',
            language: 'en',
            createdAt: t0,
          ),
        ),
      );
      TranscriptSegmentsCompanion seg(
        int seq,
        int a,
        int b,
        String body, {
        String? tokens,
        String? original,
      }) => TranscriptSegmentsCompanion.insert(
        transcriptId: 't1',
        seq: seq,
        startMs: a,
        endMs: b,
        body: body,
        tokensJson: tokens == null ? const Value.absent() : Value(tokens),
        originalText: original == null ? const Value.absent() : Value(original),
      );
      expectOk(
        await db.transcriptsRepository.upsertSegments([
          seg(0, 0, 4000, 'Hello everyone'),
          seg(
            1,
            5000,
            11000,
            ' one two three four',
            tokens: _tokens([
              (' one', 5000, 6500),
              (' two', 6500, 8000),
              (' three', 8000, 9500),
              (' four', 9500, 11000),
            ]),
          ),
          seg(100000, 31000, 34000, 'Right'),
          seg(
            100001,
            35000,
            41000,
            ' fixed by hand',
            original: ' fixed bi hand',
            tokens: _tokens([
              (' fixed', 35000, 37000),
              (' bi', 37000, 39000),
              (' hand', 39000, 41000),
            ]),
          ),
        ]),
      );
    });
    tearDown(() => dir.deleteSync(recursive: true));

    final turns = [
      const SpeakerTurn(0, 4500, 7),
      const SpeakerTurn(5000, 8000, 3),
      const SpeakerTurn(8000, 11000, 7),
      const SpeakerTurn(30000, 34500, 3),
      const SpeakerTurn(35000, 39500, 3),
      const SpeakerTurn(39500, 41000, 7),
    ];

    DiarizeStep step(DiarizationEngine e, {Profile? profile}) => DiarizeStep(
      db: db,
      paths: paths,
      engine: e,
      config: const PipelineConfig(),
      profiles: (_) async => profile,
    );

    Future<StepResult> runAndCommit(DiarizeStep s) async {
      final r = await s.run(_Ctx(_job()));
      if (r is StepSucceeded) {
        await db.transaction(() async => await r.commit?.call());
      }
      return r;
    }

    Future<List<TranscriptSegmentRow>> rows() async {
      final r = await db.transcriptsRepository.segments('t1');
      final list = expectOk(r);
      return list;
    }

    test('[STT-05/AC1] labels segments "Speaker N" by first appearance, '
        'splits a long change and never splits an edited segment', () async {
      final engine = FakeDiarizationEngine(turns);
      final r = await runAndCommit(
        step(engine, profile: _profile(diarization: true, numSpeakers: 3)),
      );
      expect(r, isA<StepSucceeded>());
      expect(engine.lastNumSpeakers, 3);
      final out = await rows();
      expect(
        [for (final s in out) (s.body.trim(), s.speaker)],
        [
          ('Hello everyone', 'Speaker 1'),
          ('one two', 'Speaker 2'),
          ('three four', 'Speaker 1'),
          ('Right', 'Speaker 2'),
          ('fixed by hand', 'Speaker 2'),
        ],
      );
      final seqs = [for (final s in out) s.seq];
      expect([...seqs]..sort(), seqs, reason: 'seq order = time order');
      expect(seqs.where((s) => s < 100000), hasLength(3));
      final names = await db.recordingsRepository.watchSpeakers('r1').first;
      expect([for (final s in names) s.label], ['Speaker 1', 'Speaker 2']);

      // Re-running is idempotent (same segments, same labels).
      await runAndCommit(step(engine, profile: _profile(diarization: true)));
      expect(
        [for (final s in await rows()) (s.body.trim(), s.speaker)],
        [for (final s in out) (s.body.trim(), s.speaker)],
      );
    });

    test('[STT-05/AC1] off by default; profile and setting decide', () async {
      final engine = FakeDiarizationEngine(turns);
      await runAndCommit(step(engine));
      expect(engine.calls, 0);
      expect((await rows()).every((s) => s.speaker == null), isTrue);

      await runAndCommit(step(engine, profile: _profile(diarization: false)));
      expect(engine.calls, 0);

      expectOk(
        await db.settingsRepository.set(
          SettingKeys.processingDiarization,
          true,
        ),
      );
      await runAndCommit(step(engine, profile: _profile()));
      expect(engine.calls, 1);

      // An explicit profile "off" beats the app default.
      await runAndCommit(step(engine, profile: _profile(diarization: false)));
      expect(engine.calls, 1);
    });

    test('[STT-05/AC1] an engine failure leaves the transcript untouched '
        'and is reported', () async {
      final engine = FakeDiarizationEngine(
        turns,
        failure: const UnexpectedFailure('boom'),
      );
      final r = await runAndCommit(
        step(engine, profile: _profile(diarization: true)),
      );
      expect(r, isA<StepFailed>());
      expect(await rows(), hasLength(4));
      expect((await rows()).every((s) => s.speaker == null), isTrue);
    });

    test('[STT-05/AC4] no embeddings or voiceprints persist: scratch is '
        'deleted on success, failure and crash; nothing stored contains '
        'them', () async {
      Future<void> noSentinel() async {
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          expect(
            f.readAsStringSync().contains(
              FakeDiarizationEngine.embeddingSentinel,
            ),
            isFalse,
            reason: f.path,
          );
        }
        for (final s in await rows()) {
          expect(
            '${s.body}${s.speaker}${s.tokensJson}'.contains(
              FakeDiarizationEngine.embeddingSentinel,
            ),
            isFalse,
          );
        }
      }

      final ok = FakeDiarizationEngine(turns);
      await runAndCommit(step(ok, profile: _profile(diarization: true)));
      expect(ok.lastScratchDir, isNotNull);
      expect(Directory(ok.lastScratchDir!).existsSync(), isFalse);
      await noSentinel();

      final bad = FakeDiarizationEngine(
        turns,
        failure: const UnexpectedFailure('x'),
      );
      await runAndCommit(step(bad, profile: _profile(diarization: true)));
      expect(Directory(bad.lastScratchDir!).existsSync(), isFalse);

      final crash = FakeDiarizationEngine(
        turns,
        throwAfterScratch: Exception('crash'),
      );
      await expectLater(
        step(crash, profile: _profile(diarization: true)).run(_Ctx(_job())),
        throwsA(isA<Exception>()),
      );
      expect(Directory(crash.lastScratchDir!).existsSync(), isFalse);
      await noSentinel();
    });

    test('[STT-05/AC4] the schema has no embedding or voiceprint column', () {
      for (final t in db.allTables) {
        for (final c in t.$columns) {
          expect(
            RegExp(
              'embed|voiceprint|speaker_vec',
              caseSensitive: false,
            ).hasMatch(c.name),
            isFalse,
            reason: '${t.actualTableName}.${c.name}',
          );
        }
      }
    });

    test('[STT-05/AC3] a renamed speaker appears by name in the Markdown '
        'transcript and the rename survives per recording only', () async {
      await runAndCommit(
        step(
          FakeDiarizationEngine(turns),
          profile: _profile(diarization: true),
        ),
      );
      expectOk(
        await db.recordingsRepository.renameSpeaker(
          'r1',
          'Speaker 1',
          '  Priya ',
        ),
      );
      final names = expectOk(await db.recordingsRepository.speakerNames('r1'));
      expect(names, {'Speaker 1': 'Priya'});

      final renderer = TemplateNoteRenderer(
        profiles: tf.builtinProfiles,
        templates: tf.builtinTemplates,
        appVersion: '1.0.0',
      );
      final recording = expectOk(await db.recordingsRepository.get('r1'));
      final md = renderer(
        NoteInput(
          recording: recording,
          extraction: ExtractionRow(
            id: 'x1',
            recordingId: 'r1',
            profileId: 'meeting',
            profileVersion: 1,
            modelId: 'm',
            json: const {'summary': 'S'},
            valid: false,
            createdAt: t0,
          ),
          segments: await rows(),
          speakerNames: names,
        ),
      );
      expect(md, contains('Priya: Hello everyone'));
      expect(md, contains('Speaker 2: one two'));
      expect(md, isNot(contains('Speaker 1:')));

      // Clearing the name restores the anonymous label.
      expectOk(
        await db.recordingsRepository.renameSpeaker('r1', 'Speaker 1', ' '),
      );
      expect(
        expectOk(await db.recordingsRepository.speakerNames('r1')),
        isEmpty,
      );
    });
  });
}
