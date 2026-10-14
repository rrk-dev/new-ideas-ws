import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';

import '../fakes/fake_capture_backend.dart';
import '../fakes/fake_clock.dart';
import '../fakes/fake_id_generator.dart';
import '../fakes/fake_llm_engine.dart';
import '../fakes/fake_stt_engine.dart';
import '../fakes/fake_vault_writer.dart';

/// Overrides wiring every engine provider to a fake. Pass your own fake for
/// the one under test to script it.
List<Override> fakeEngineOverrides({
  FakeCaptureBackend? capture,
  FakeSttEngine? stt,
  FakeLlmEngine? llm,
  FakeVaultWriter? vault,
  FakeClock? clock,
  SequentialIdGenerator? ids,
}) => [
  captureBackendProvider.overrideWithValue(capture ?? FakeCaptureBackend()),
  sttEngineProvider.overrideWithValue(stt ?? FakeSttEngine()),
  llmEngineProvider.overrideWithValue(llm ?? FakeLlmEngine()),
  vaultWriterProvider.overrideWithValue(vault ?? FakeVaultWriter()),
  clockProvider.overrideWithValue(clock ?? FakeClock()),
  idGeneratorProvider.overrideWithValue(ids ?? SequentialIdGenerator()),
];

/// A [ProviderContainer] disposed automatically at test teardown.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
