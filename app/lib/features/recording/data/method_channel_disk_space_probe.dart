import 'package:flutter/services.dart';
import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/recording/domain/storage_policy.dart';

/// [DiskSpaceProbe] backed by `StorageInfoPlugin` (Android `StatFs`
/// `availableBytes`; iOS `volumeAvailableCapacityForImportantUsage`).
class MethodChannelDiskSpaceProbe implements DiskSpaceProbe {
  const MethodChannelDiskSpaceProbe([
    this._channel = const MethodChannel(channelName),
  ]);

  static const channelName = 'vaultvoice/storage_info';

  final MethodChannel _channel;

  @override
  Future<Result<int>> freeBytes(String path) async {
    try {
      final free = await _channel.invokeMethod<int>('freeBytes', {
        'path': path,
      });
      if (free == null || free < 0) {
        return const Err(StorageFailure('free space unknown'));
      }
      return Ok(free);
    } on Object catch (e) {
      return Err(UnexpectedFailure(e.runtimeType.toString()));
    }
  }
}
