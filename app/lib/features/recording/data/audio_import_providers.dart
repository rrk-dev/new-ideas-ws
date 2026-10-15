import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/core/db/db_providers.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/platform/id_generator.dart';
import 'package:vaultvoice/core/platform/providers.dart';
import 'package:vaultvoice/features/pipeline/data/pipeline_providers.dart';
import 'package:vaultvoice/features/recording/data/audio_import_service.dart';
import 'package:vaultvoice/features/recording/data/pigeon_audio_decoder.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/audio_import.dart';

part 'audio_import_providers.g.dart';

/// Lets the user pick one audio file (system picker; the plugin hands back
/// an app-private copy on both platforms).
abstract interface class AudioFilePicker {
  /// Path of the picked copy, or null when cancelled.
  Future<String?> pick();
}

/// `file_selector` 1.1.0: Android `ACTION_OPEN_DOCUMENT` (`audio/*`), iOS
/// `UIDocumentPickerViewController` (`public.audio`, import mode = copy).
class FileSelectorAudioPicker implements AudioFilePicker {
  const FileSelectorAudioPicker();

  @override
  Future<String?> pick() async {
    final f = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'audio',
          mimeTypes: ['audio/*', 'application/ogg'],
          uniformTypeIdentifiers: ['public.audio'],
        ),
      ],
    );
    return f?.path;
  }
}

@Riverpod(keepAlive: true)
AudioFilePicker audioFilePicker(Ref ref) => const FileSelectorAudioPicker();

/// Native decoders (AUD-06); tests override with a fake.
@Riverpod(keepAlive: true)
AudioDecoder audioDecoder(Ref ref) => PigeonAudioDecoder();

/// Files shared into the app, waiting for the attestation; tests override.
@Riverpod(keepAlive: true)
SharedAudioInbox sharedAudioInbox(Ref ref) {
  final inbox = PigeonSharedAudioInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
}

/// The platform whose decoder table applies.
@Riverpod(keepAlive: true)
ImportPlatform importPlatform(Ref ref) => Platform.isIOS || Platform.isMacOS
    ? ImportPlatform.ios
    : ImportPlatform.android;

@Riverpod(keepAlive: true)
Future<AudioImportService> audioImportService(Ref ref) async {
  final paths = await ref.watch(storagePathsProvider.future);
  return AudioImportService(
    decoder: ref.watch(audioDecoderProvider),
    recordings: ref.watch(recordingsRepositoryProvider),
    paths: paths,
    codec: ref.watch(audioChunkCodecProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    platform: ref.watch(importPlatformProvider),
    disk: ref.watch(diskSpaceProbeProvider),
    logger: ref.watch(loggerProvider),
    // Same pipeline as a microphone recording (FND-05), in queue order.
    enqueue: (id) async {
      final client = await ref.read(pipelineClientProvider.future);
      await client.enqueue(id);
    },
  );
}
