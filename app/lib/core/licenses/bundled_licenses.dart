import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Full upstream notices, including native dependencies absent from pub's
/// registry. Generated pub inventory also covers runtime transitive packages.
void registerBundledLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final asset in ['pub_inventory', 'native_models']) {
      final rows = jsonDecode(
        await rootBundle.loadString('assets/licenses/$asset.json'),
      ) as List<Object?>;
      for (final value in rows) {
        final row = value! as Map<String, Object?>;
        final packages = row['packages'] as List<Object?>?;
        yield LicenseEntryWithLineBreaks(
          packages?.cast<String>() ?? [row['name']! as String],
          row['license_text']! as String,
        );
      }
    }
  });
}
