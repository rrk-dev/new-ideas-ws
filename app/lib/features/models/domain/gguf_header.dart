import 'dart:typed_data';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';

/// Bytes [checkGgufHeader] needs: magic, version, tensor and KV counts.
const int kGgufHeaderBytes = 24;

/// GGUF format versions llama.cpp reads (v1 was dropped upstream).
const Set<int> kSupportedGgufVersions = {2, 3};

/// Upper bounds well above real models (Llama 70B ≈ 723 tensors, large MoE
/// GGUFs a few thousand; metadata a few hundred KVs). Anything larger is
/// treated as hostile/corrupt before llama.cpp ever parses it.
const int kMaxGgufTensors = 65536;
const int kMaxGgufMetadataKvs = 65536;

/// Smallest possible on-disk tensor info (name length + empty name, n_dims,
/// type, offset); used to reject counts the file cannot possibly hold.
const int _minTensorInfoBytes = 8 + 4 + 4 + 8;

/// Parsed fixed GGUF header.
class GgufHeader {
  const GgufHeader({
    required this.version,
    required this.tensorCount,
    required this.metadataKvCount,
  });

  final int version;
  final int tensorCount;
  final int metadataKvCount;
}

/// Sanity check for an unsigned "advanced: custom model" GGUF (MDL-04,
/// SEC-08 threat "malicious GGUF"): magic `GGUF`, supported version, bounded
/// counts, counts that fit in [fileSize]. Layout per ggml `docs/gguf.md`
/// (little-endian: u32 magic, u32 version, u64 n_tensors, u64 n_kv).
/// This is a cheap gate, not a full parser; llama.cpp still validates.
Result<GgufHeader> checkGgufHeader(List<int> head, int fileSize) {
  Err<GgufHeader> bad() =>
      Err(ModelImportFailure(ModelImportRejection.invalidGguf));
  if (head.length < kGgufHeaderBytes || fileSize < kGgufHeaderBytes) {
    return bad();
  }
  final data = ByteData.sublistView(Uint8List.fromList(head));
  // "GGUF" as bytes 0x47 0x47 0x55 0x46.
  if (head[0] != 0x47 ||
      head[1] != 0x47 ||
      head[2] != 0x55 ||
      head[3] != 0x46) {
    return bad();
  }
  final version = data.getUint32(4, Endian.little);
  if (!kSupportedGgufVersions.contains(version)) return bad();
  // Read u64 as two u32 halves (no 64-bit overflow surprises on web/VM).
  int u64(int o) {
    final hi = data.getUint32(o + 4, Endian.little);
    if (hi != 0) return -1;
    return data.getUint32(o, Endian.little);
  }

  final tensors = u64(8);
  final kvs = u64(16);
  if (tensors < 0 || tensors > kMaxGgufTensors) return bad();
  if (kvs < 0 || kvs > kMaxGgufMetadataKvs) return bad();
  if (tensors == 0) return bad();
  if (kGgufHeaderBytes + tensors * _minTensorInfoBytes > fileSize) {
    return bad();
  }
  return Ok(
    GgufHeader(version: version, tensorCount: tensors, metadataKvCount: kvs),
  );
}
