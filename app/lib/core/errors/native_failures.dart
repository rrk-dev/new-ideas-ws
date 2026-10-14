import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vv_native/vv_native.dart';

/// The one place that maps `VV_E_*` codes (`native/bridge/vv_error.h`) to
/// [Failure]s (vv-ffi-bridge). Messages stay content-free.
Failure failureFromVvCode(int code, {required String operation}) =>
    switch (code) {
      VV_E_CANCELLED => const CancelledFailure(),
      VV_E_OOM => const OutOfMemoryFailure(),
      VV_E_IO => StorageFailure('$operation: file not readable'),
      VV_E_MODEL_LOAD => NativeFailure(code, '$operation: model load failed'),
      VV_E_INVALID_ARG => NativeFailure(code, '$operation: invalid input'),
      VV_E_BACKEND => NativeFailure(code, '$operation: no compute backend'),
      VV_E_BUSY => NativeFailure(code, '$operation: engine busy'),
      _ => NativeFailure(code, '$operation: native error $code'),
    };
