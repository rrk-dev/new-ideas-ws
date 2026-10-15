import 'package:flutter_test/flutter_test.dart';

import '../../helpers/store_demo_data.dart';

void main() {
  test('[REL-05/AC1] store demo data is synthetic (no real people)', () {
    expect(kStoreDemoTitle, 'Sample weekly planning');
    expect(storeDemoLines.map((l) => l.speaker), [
      kStoreDemoSpeakerA,
      kStoreDemoSpeakerB,
      kStoreDemoSpeakerA,
    ]);
    for (final line in storeDemoLines) {
      expect(line.speaker, isNot(anyOf('Priya', 'Sam')));
      expect(line.text.toLowerCase(), isNot(contains('priya')));
    }
    expect(storeDemoExtraction.data['attendees'], [
      kStoreDemoSpeakerA,
      kStoreDemoSpeakerB,
    ]);
    expect(kStoreScreenshotShots.map((s) => s.$1).toList(), [
      '01_onboarding',
      '02_record',
      '03_library',
      '04_transcript',
      '05_settings',
    ]);
  });
}
