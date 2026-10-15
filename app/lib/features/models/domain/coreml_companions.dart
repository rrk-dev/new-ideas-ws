import 'package:vaultvoice/features/models/domain/model_catalog.dart';

/// Directory whisper.cpp looks for next to [modelFile] when built with Core
/// ML (`VV_WHISPER_COREML=ON`, iOS — ADR-STT-01, Accepted 2026-10-14): the
/// file name minus its extension and a `-qX_Y` quantization suffix, plus
/// `-encoder.mlmodelc`. Mirrors `whisper_get_coreml_path_encoder` in
/// whisper.cpp v1.9.5 (`src/whisper.cpp:3395`): `ggml-base.en-q5_1.bin` →
/// `ggml-base.en-encoder.mlmodelc`.
String coreMlEncoderDirName(String modelFile) {
  var base = modelFile;
  final dot = base.lastIndexOf('.');
  if (dot >= 0) base = base.substring(0, dot);
  final dash = base.lastIndexOf('-');
  if (dash >= 0) {
    final sub = base.substring(dash);
    if (sub.length == 5 && sub[1] == 'q' && sub[3] == '_') {
      base = base.substring(0, dash);
    }
  }
  return '$base-encoder.mlmodelc';
}

/// The Core ML encoder companions of [model] that [lookup] can resolve
/// (catalog `companions` of type `coreml-encoder`). Only an STT model has
/// them; an unknown id is skipped (the catalog validator already rejects
/// dangling ids).
List<CatalogModel> coreMlCompanionsOf(
  CatalogModel model,
  CatalogModel? Function(String id) lookup,
) => [
  if (model.type == ModelType.stt)
    for (final id in model.companions)
      if (lookup(id) case final c? when c.type == ModelType.coremlEncoder) c,
];
