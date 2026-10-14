import 'dart:io';
import 'dart:typed_data';

import 'package:vaultvoice/features/recording/domain/audio_chunk_codec.dart';
import 'package:vaultvoice/features/recording/domain/wav_header.dart';

/// The default chunk codec: plaintext 16 kHz mono PCM16 WAV in app-private
/// storage, protected by OS file encryption (SEC-01 may replace it).
class WavChunkCodec implements AudioChunkCodec {
  const WavChunkCodec();

  @override
  ChunkCodecId get id => ChunkCodecId.wav;

  @override
  Future<AudioChunkWriter> create(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final raf = await file.open(mode: FileMode.write);
    await raf.writeFrom(WavHeader.build(dataBytes: 0));
    await raf.flush();
    return WavChunkWriter._(raf);
  }

  @override
  Future<AudioChunkWriter> reopen(String path) async {
    // FileMode.append = read/write positioned at the end (not O_APPEND), so
    // the header can still be patched in place.
    final raf = await File(path).open(mode: FileMode.append);
    final length = await raf.length();
    final writer = WavChunkWriter._(raf)
      .._dataBytes = WavHeader.recoverableDataBytes(length);
    return writer;
  }

  @override
  Future<int> recover(String path) async {
    final raf = await File(path).open(mode: FileMode.append);
    try {
      final length = await raf.length();
      final data = WavHeader.recoverableDataBytes(length);
      if (length < WavHeader.length) {
        // Killed before the header was complete: rebuild it.
        await raf.truncate(0);
        await raf.setPosition(0);
        await raf.writeFrom(WavHeader.build(dataBytes: 0));
        await raf.flush();
        return 0;
      }
      // A half-written trailing sample is dropped.
      if (length != WavHeader.length + data) {
        await raf.truncate(WavHeader.length + data);
      }
      // Rewrite the whole header (the placeholder may be all there is).
      await raf.setPosition(0);
      await raf.writeFrom(WavHeader.build(dataBytes: data));
      await raf.flush();
      return data;
    } finally {
      await raf.close();
    }
  }
}

/// Writes PCM after a placeholder header; every [flush] patches the RIFF and
/// data sizes and syncs, so the file is a valid WAV of everything flushed —
/// even if the process dies right after (AUD-07).
class WavChunkWriter implements AudioChunkWriter {
  WavChunkWriter._(this._raf);

  final RandomAccessFile _raf;
  int _dataBytes = 0;
  int _patchedBytes = -1;
  bool _closed = false;

  @override
  int get dataBytes => _dataBytes;

  @override
  int get fileBytes => WavHeader.length + _dataBytes;

  @override
  Future<void> append(Uint8List pcm) async {
    _checkOpen();
    if (pcm.isEmpty) return;
    await _raf.setPosition(WavHeader.length + _dataBytes);
    await _raf.writeFrom(pcm);
    _dataBytes += pcm.length;
  }

  @override
  Future<void> flush() async {
    _checkOpen();
    await _patchSizes();
    await _raf.flush();
  }

  @override
  Future<Uint8List> readTail(int fromDataByte) async {
    _checkOpen();
    final from = fromDataByte.clamp(0, _dataBytes);
    await _raf.setPosition(WavHeader.length + from);
    return await _raf.read(_dataBytes - from);
  }

  @override
  Future<void> truncate(int dataBytes) async {
    _checkOpen();
    final keep = dataBytes.clamp(0, _dataBytes);
    if (keep == _dataBytes) return;
    await _raf.truncate(WavHeader.length + keep);
    _dataBytes = keep;
  }

  @override
  Future<int> close() async {
    if (_closed) return WavHeader.length + _dataBytes;
    await _patchSizes();
    await _raf.flush();
    await _raf.close();
    _closed = true;
    return WavHeader.length + _dataBytes;
  }

  Future<void> _patchSizes() async {
    if (_patchedBytes == _dataBytes) return;
    final f = WavHeader.sizeFields(_dataBytes);
    await _raf.setPosition(WavHeader.riffSizeOffset);
    await _raf.writeFrom(f.riffSize);
    await _raf.setPosition(WavHeader.dataSizeOffset);
    await _raf.writeFrom(f.dataSize);
    _patchedBytes = _dataBytes;
  }

  void _checkOpen() {
    if (_closed) throw StateError('chunk writer closed');
  }
}
