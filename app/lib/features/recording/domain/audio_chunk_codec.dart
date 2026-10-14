import 'dart:typed_data';

/// On-disk encoding of a chunk file, chosen by the SEC-01 ADR
/// (`vv-audio-capture` → Chunk writer & optional encryption).
enum ChunkCodecId {
  /// Plain 16 kHz mono PCM16 WAV protected by OS file encryption (default,
  /// Phase 1).
  wav('wav'),

  /// App-level AES-256-GCM framed format (only if SEC-01 chooses it).
  vvenc('vvenc');

  ChunkCodecId(this.extension);

  /// File extension of chunks written with this codec.
  final String extension;
}

/// Creates chunk writers. All recording chunk IO goes through this seam so
/// AUD-01 never hard-codes the file format; SEC-01 swaps the codec.
abstract interface class AudioChunkCodec {
  ChunkCodecId get id;

  /// Creates [path] (replacing any file there) and returns its writer.
  Future<AudioChunkWriter> create(String path);

  /// Reopens a finalized chunk written by this codec to change its tail
  /// (a call-interruption discard reaching back past a chunk rollover).
  Future<AudioChunkWriter> reopen(String path);

  /// Crash recovery (AUD-07): makes a chunk left behind by a killed process
  /// readable — WAV: rewrite the header sizes from the file length (rounded
  /// down to whole samples); `vvenc`: drop the incomplete last frame.
  /// Returns the recovered PCM byte count (0 = nothing usable).
  Future<int> recover(String path);
}

/// Appends mono 16 kHz PCM16 to one chunk file.
///
/// Contract (crash safety, AUD-07): after [flush] completes, everything
/// appended so far is durable and the file is readable/recoverable as-is.
abstract interface class AudioChunkWriter {
  /// PCM bytes in the chunk so far (excluding container overhead).
  int get dataBytes;

  /// Size of the chunk file once flushed (container overhead included).
  int get fileBytes;

  /// Appends PCM bytes (whole samples).
  Future<void> append(Uint8List pcm);

  /// Makes everything appended durable (header/size fields updated, OS
  /// buffers synced).
  Future<void> flush();

  /// Returns the PCM bytes from [fromDataByte] to the end (to re-shape the
  /// tail, e.g. a fade-out at a pause).
  Future<Uint8List> readTail(int fromDataByte);

  /// Discards all PCM after [dataBytes] (call-interruption discard, tail
  /// rewrite).
  Future<void> truncate(int dataBytes);

  /// Finalizes the file; the writer is unusable afterwards. Returns the
  /// final file length in bytes.
  Future<int> close();
}
