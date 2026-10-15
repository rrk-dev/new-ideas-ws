import 'package:flutter_riverpod/misc.dart';
import 'package:vaultvoice/features/library/domain/library_models.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';

import 'library_fixtures.dart';

/// Synthetic store-screenshot seed (REL-05). No real people, no photos.
const String kStoreDemoRecordingId = 'store-demo';
const String kStoreDemoTitle = 'Sample weekly planning';
const String kStoreDemoSpeakerA = 'Speaker A';
const String kStoreDemoSpeakerB = 'Speaker B';

final DateTime kStoreDemoAt = DateTime.utc(2026, 10, 14, 9, 30);

List<LibraryItem> storeDemoLibrary() => [
  LibraryItem(
    id: kStoreDemoRecordingId,
    title: kStoreDemoTitle,
    createdAt: kStoreDemoAt,
    duration: const Duration(minutes: 12, seconds: 4),
    status: LibraryStatus.exported,
    profileId: 'meeting',
    tags: const ['demo'],
    exports: [
      ExportInfo(
        targetId: 'v1',
        targetName: 'Notes',
        relPath: 'Meetings/2026-10-14-sample-planning.md',
        written: true,
        failed: false,
        updatedAt: kStoreDemoAt,
      ),
    ],
  ),
];

const List<TranscriptLine> storeDemoLines = [
  TranscriptLine(
    startMs: 1000,
    endMs: 4000,
    text: 'Let us confirm the agenda for the week.',
    speaker: kStoreDemoSpeakerA,
  ),
  TranscriptLine(
    startMs: 4500,
    endMs: 8000,
    text: 'I will send the summary after we finish.',
    speaker: kStoreDemoSpeakerB,
  ),
  TranscriptLine(
    startMs: 8500,
    endMs: 12000,
    text: 'The sample note stays on this device.',
    speaker: kStoreDemoSpeakerA,
  ),
];

final ExtractionView storeDemoExtraction = ExtractionView(
  id: 'store-ex',
  profileId: 'meeting',
  profileVersion: 1,
  modelId: 'demo',
  valid: true,
  createdAt: kStoreDemoAt,
  data: const {
    'title': kStoreDemoTitle,
    'summary': 'A synthetic weekly planning note for store screenshots.',
    'attendees': [kStoreDemoSpeakerA, kStoreDemoSpeakerB],
    'action_items': [
      {
        'task': 'Send the sample summary',
        'owner': kStoreDemoSpeakerB,
        'due': 'Friday',
      },
    ],
  },
);

/// Routes captured by `integration_test/store_screenshots_test.dart`.
/// Keep in sync with `tools/release/store_screenshot_sizes.json` → shots.
const List<(String, String)> kStoreScreenshotShots = [
  ('01_onboarding', '/onboarding'),
  ('02_record', '/record'),
  ('03_library', '/library'),
  ('04_transcript', '/library/recordings/store-demo/text'),
  ('05_settings', '/settings'),
];

List<Override> storeDemoOverrides() => libraryOverrides(
  items: storeDemoLibrary(),
  detailId: kStoreDemoRecordingId,
  lines: storeDemoLines,
  extraction: storeDemoExtraction,
);
