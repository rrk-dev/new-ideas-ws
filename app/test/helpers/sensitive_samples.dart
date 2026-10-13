import 'package:flutter_test/flutter_test.dart';

/// Sample sensitive strings that must never appear in a log at INFO+.
const transcript = 'Anna said the Zephyr merger closes on Friday';
const audioPath =
    '/var/mobile/Containers/Data/Application/1F2E/Documents/vv/audio/'
    'Call with Anna Zephyr.m4a';
const vaultUri =
    'content://com.android.externalstorage.documents/tree/primary%3AZephyrVault';
const llmOutput = '{"action_items":[{"owner":"Anna","task":"Zephyr deck"}]}';
const email = 'anna.zephyr@example.com';
const phone = '+1 (415) 555-0199';
const windowsPath = r'C:\Users\Anna\Zephyr Notes\meeting.md';

const sentinels = [
  'Zephyr',
  'Anna',
  'merger',
  'example.com',
  '555-0199',
  'mobile/Containers',
];

void expectNoSentinel(String text) {
  for (final s in sentinels) {
    expect(text, isNot(contains(s)), reason: 'leaked "$s" in: $text');
  }
}
