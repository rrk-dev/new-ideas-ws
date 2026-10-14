import 'package:flutter/foundation.dart';

/// Licences of code and models that pub's `LicenseRegistry` does not know
/// about: the native libraries built from `native/` (pins in
/// `native/VERSIONS.md`) and the model weights offered by the catalog
/// (`docs/privacy-audit.md` → Models). Shown by "Open-source & model
/// licenses" in Settings → About next to every pub package. SEC-05 owns the
/// full inventory (`docs/licenses.md`) and extends this list.
const List<BundledLicense> kBundledLicenses = [
  BundledLicense(
    packages: ['whisper.cpp', 'ggml'],
    text: _mit,
    copyright: 'Copyright (c) 2023-2026 The ggml authors',
  ),
  BundledLicense(
    packages: ['llama.cpp'],
    text: _mit,
    copyright: 'Copyright (c) 2023-2026 The ggml authors',
  ),
  BundledLicense(
    packages: ['Whisper model weights (OpenAI)'],
    text: _mit,
    copyright: 'Copyright (c) 2022 OpenAI',
  ),
  BundledLicense(
    packages: ['Qwen2.5-0.5B-Instruct (model)'],
    copyright: 'Copyright 2024 Alibaba Cloud',
    text:
        'Licensed under the Apache License, Version 2.0 (the "License"); you '
        'may not use this file except in compliance with the License. You may '
        'obtain a copy of the License at '
        'http://www.apache.org/licenses/LICENSE-2.0\n\n'
        'Unless required by applicable law or agreed to in writing, software '
        'distributed under the License is distributed on an "AS IS" BASIS, '
        'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or '
        'implied. See the License for the specific language governing '
        'permissions and limitations under the License.',
  ),
];

class BundledLicense {
  const BundledLicense({
    required this.packages,
    required this.copyright,
    required this.text,
  });

  final List<String> packages;
  final String copyright;
  final String text;

  LicenseEntry toEntry() =>
      LicenseEntryWithLineBreaks(packages, '$copyright\n\n$text');
}

bool _registered = false;

/// Adds [kBundledLicenses] to Flutter's [LicenseRegistry] (idempotent).
void registerBundledLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(
    () => Stream.fromIterable([for (final l in kBundledLicenses) l.toEntry()]),
  );
}

const _mit =
    'Permission is hereby granted, free of charge, to any person obtaining a '
    'copy of this software and associated documentation files (the '
    '"Software"), to deal in the Software without restriction, including '
    'without limitation the rights to use, copy, modify, merge, publish, '
    'distribute, sublicense, and/or sell copies of the Software, and to '
    'permit persons to whom the Software is furnished to do so, subject to '
    'the following conditions:\n\n'
    'The above copyright notice and this permission notice shall be included '
    'in all copies or substantial portions of the Software.\n\n'
    'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS '
    'OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
    'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. '
    'IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY '
    'CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, '
    'TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE '
    'SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.';
