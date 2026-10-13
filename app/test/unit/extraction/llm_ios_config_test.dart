import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LLM-02: the iOS app requests the increased-memory-limit entitlement in
/// every Runner build configuration (jetsam headroom for 3B models).
void main() {
  test('LLM-02 Runner.entitlements enables increased-memory-limit', () {
    final ent = File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(
      RegExp(
        r'<key>com\.apple\.developer\.kernel\.increased-memory-limit</key>\s*<true/>',
      ).hasMatch(ent),
      isTrue,
    );
  });

  test('LLM-02 all six Runner configurations sign with the entitlements', () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final n = RegExp(r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;')
        .allMatches(pbx)
        .length;
    // Debug/Release/Profile x dev/prod flavors.
    expect(n, 6);
    expect(
      RegExp('INFOPLIST_FILE = Runner/Info.plist;').allMatches(pbx).length,
      n,
    );
  });
}
