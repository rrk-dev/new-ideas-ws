import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Log messages must be constant event names; data goes into `fields`
/// (sanitized by the logger). This guard rejects calls whose message is
/// interpolated or not a string literal — the one leak the runtime redactor
/// cannot catch (free prose such as transcript text).
final _call = RegExp(
  r'''\.\.?(?:debug|info|warning|error)\(\s*'[a-z0-9_.]+'\s*,\s*'''
  r'''(?:'[^'\n]*\$|"[^"\n]*\$|[^'"\s])''',
);

List<String> violations(String source) =>
    _call.allMatches(source).map((m) => m[0]!).toList();

void main() {
  test('[FND-07/AC1] guard flags interpolated or non-literal messages', () {
    expect(
      violations(r"logger.info('stt', 'text $transcript');"),
      hasLength(1),
    );
    expect(
      violations("logger\n  ..error(\n  'llm',\n  output,\n);"),
      hasLength(1),
    );
    expect(
      violations("logger.info('stt', 'job finished', fields: {});"),
      isEmpty,
    );
  });

  test('[FND-07/AC1] no log call in lib/ interpolates content into the '
      'message', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final v in violations(f.readAsStringSync())) {
        hits.add('${f.path}: $v');
      }
    }
    expect(hits, isEmpty);
  });
}
