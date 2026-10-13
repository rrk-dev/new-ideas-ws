import 'package:crypto/crypto.dart' as crypto;
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Streams a model file and checks it against its catalog entry: exact byte
/// count first (stops early on oversize), then SHA-256.
///
/// MDL-02 runs this in a background isolate (or natively) before the atomic
/// rename into `models/<id>/`; a mismatch means delete + re-download.
Future<Result<void>> verifyModelBytes(
  Stream<List<int>> bytes,
  CatalogModel model,
) async {
  final digest = _DigestSink();
  final input = crypto.sha256.startChunkedConversion(digest);
  var count = 0;
  await for (final chunk in bytes) {
    count += chunk.length;
    if (count > model.size) {
      return Err(ModelIntegrityFailure(model.id, sizeMismatch: true));
    }
    input.add(chunk);
  }
  input.close();
  if (count != model.size) {
    return Err(ModelIntegrityFailure(model.id, sizeMismatch: true));
  }
  if (digest.value.toString() != model.sha256) {
    return Err(ModelIntegrityFailure(model.id, sizeMismatch: false));
  }
  return const Ok(null);
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
