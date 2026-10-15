#!/usr/bin/env python3
"""Regenerate app/assets/licenses/native_models.json (SEC-05).

Native libraries and model weights are unknown to Flutter's LicenseRegistry,
so their full notices ship in this asset (read by bundled_licenses.dart).
Texts live in tools/licenses/texts/ (copied from the pinned upstream sources
listed in native/VERSIONS.md and docs/licenses.md).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXTS = ROOT / 'tools/licenses/texts'

MIT = (
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
    'SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'
)


def mit(copyright_line):
    return f'MIT License\n\n{copyright_line}\n\n{MIT}'


ggml = (TEXTS / 'ggml-mit.txt').read_text()
apache = (TEXTS / 'apache-2.0.txt').read_text()

rows = [
    {'packages': ['whisper.cpp', 'ggml'], 'license_text': ggml},
    {'packages': ['llama.cpp'], 'license_text': ggml},
    {
        'packages': ['SQLite3 Multiple Ciphers'],
        'license_text': mit('Copyright (c) 2019-2025 Ulrich Telle'),
    },
    {
        'packages': ['SQLite'],
        'license_text': (
            'The author disclaims copyright to this source code. In place of '
            'a legal notice, here is a blessing:\n\n'
            '  * May you do good and not evil.\n'
            '  * May you find forgiveness for yourself and forgive others.\n'
            '  * May you share freely, never taking more than you give.'
        ),
    },
    {
        'packages': ['Silero VAD v6.2.0'],
        'license_text': mit('Copyright (c) 2020-present Silero Team'),
    },
    {
        'packages': ['Whisper model weights (OpenAI)'],
        'license_text': mit('Copyright (c) 2022 OpenAI'),
    },
    {
        'packages': ['Qwen2.5-0.5B-Instruct (model)'],
        'license_text': 'Copyright 2024 Alibaba Cloud\n\n' + apache,
    },
]
out = ROOT / 'app/assets/licenses/native_models.json'
out.write_text(json.dumps(rows, indent=2) + '\n')
print(f'{len(rows)} native/model notices generated')
