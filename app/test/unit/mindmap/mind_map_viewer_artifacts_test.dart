import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _task = '../tasks/14-product-phase2/MAP-02-mind-map-viewer-export.md';
const _device = '../docs/test-plans/device/MAP-02.md';

void main() {
  test('[MAP-02/AC5] the 40-node frame-rate row exists as a pending device '
      'row', () {
    final device = File(_device).readAsStringSync();
    expect(device, contains('[MAP-02/AC5]'));
    expect(device, contains('40 nodes'));
    expect(device, contains('≥ 55 fps'));
    expect(device, contains('⏳'));
  });

  test('[MAP-02/AC6] Mermaid and PNG are recorded as deferred with a '
      'reason', () {
    final task = File(_task).readAsStringSync();
    expect(task, contains('Mermaid: deferred'));
    expect(task, contains('PNG: deferred'));
  });
}
