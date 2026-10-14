import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_id_generator.dart';
import '../fakes/fake_llm_engine.dart';
import '../fakes/fake_stt_engine.dart';
import '../fakes/fake_vault_writer.dart';
import 'deterministic.dart';
import 'test_container.dart';

/// Everything a pipeline test needs: every engine faked, a deterministic clock
/// and IDs, a temp working directory that survives [restart], and a
/// [ProviderContainer] that can be torn down and rebuilt mid-job to simulate
/// the app being killed (vv-testing → "Fakes contract").
///
/// Pass `overrides` for providers that should point into [workDir], e.g. the
/// database file (`harness.file('vv.db')`) once FND-04/05 land; the builder
/// receives the harness so it can resolve paths via [file].
class PipelineHarness {
  PipelineHarness({
    FakeSttEngine? stt,
    FakeLlmEngine? llm,
    FakeVaultWriter? vault,
    FakeCaptureBackend? capture,
    FakeClock? clock,
    SequentialIdGenerator? ids,
    this.overrides,
  }) : stt = stt ?? FakeSttEngine(),
       llm = llm ?? FakeLlmEngine(),
       vault = vault ?? FakeVaultWriter(),
       capture = capture ?? FakeCaptureBackend(),
       clock = clock ?? testClock(),
       ids = ids ?? testIds(),
       workDir = Directory.systemTemp.createTempSync('vv_pipeline_') {
    addTearDown(() {
      _container?.dispose();
      if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    });
  }

  final FakeSttEngine stt;
  final FakeLlmEngine llm;
  final FakeVaultWriter vault;
  final FakeCaptureBackend capture;
  final FakeClock clock;
  final SequentialIdGenerator ids;
  final Directory workDir;

  /// Extra overrides, rebuilt on every [restart].
  final List<Override> Function(PipelineHarness h)? overrides;

  ProviderContainer? _container;

  /// How many times the container was rebuilt by [restart].
  int restarts = 0;

  /// The live container (built on first access).
  ProviderContainer get container => _container ??= _build();

  /// Disposes the container ("app killed") and builds a fresh one against the
  /// same [workDir] and fakes ("app relaunched").
  ProviderContainer restart() {
    _container?.dispose();
    restarts++;
    return _container = _build();
  }

  /// A file inside [workDir] (not created).
  File file(String name) => File('${workDir.path}/$name');

  ProviderContainer _build() => ProviderContainer(
    overrides: [
      ...fakeEngineOverrides(
        capture: capture,
        stt: stt,
        llm: llm,
        vault: vault,
        clock: clock,
        ids: ids,
      ),
      ...?overrides?.call(this),
    ],
  );
}

/// Splits scripted LLM output into tokens of [size] characters for
/// `FakeLlmEngine(tokens: …)`, so streaming/progress paths are exercised.
List<String> tokensOf(String text, {int size = 8}) => [
  for (var i = 0; i < text.length; i += size)
    text.substring(i, i + size > text.length ? text.length : i + size),
];
