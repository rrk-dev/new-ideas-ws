/// Download preconditions and retry schedule (MDL-02, `vv-model-delivery`).
library;

/// Extra free space kept on top of the download (`+ 200 MB`).
const int kDownloadSpaceMarginBytes = 200 * 1024 * 1024;

/// Retries after the first attempt before a download gives up (the partial
/// file is kept for a later resume).
const int kMaxDownloadRetries = 8;

/// Retry budget once another URL was refused permanently (e.g. a proxy
/// block page): the remaining URL is most likely blocked too, so give up
/// sooner with an actionable message.
const int kMaxDownloadRetriesWithRejectedUrl = 2;

/// Free space required before downloading [remainingBytes] more bytes:
/// `remaining × 1.1 + 200 MB` (rounded up). For a fresh download
/// `remaining` is the full model size; a resume only needs room for what is
/// still missing.
int requiredFreeBytes(int remainingBytes) {
  if (remainingBytes < 0) {
    throw ArgumentError.value(remainingBytes, 'remainingBytes');
  }
  return remainingBytes +
      (remainingBytes + 9) ~/ 10 +
      kDownloadSpaceMarginBytes;
}

/// Delay before retry number [retry] (1-based): 1 s, 2 s, 4 s … capped at
/// 60 s.
Duration retryDelay(int retry) {
  if (retry < 1) throw ArgumentError.value(retry, 'retry');
  if (retry > 7) return const Duration(seconds: 60);
  final seconds = 1 << (retry - 1);
  return Duration(seconds: seconds > 60 ? 60 : seconds);
}

/// Failure message marking a response that a network proxy/firewall replaced.
const kBlockedByNetwork = 'blocked by network';
