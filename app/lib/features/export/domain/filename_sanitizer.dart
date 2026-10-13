import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Maximum UTF-8 bytes of one path segment (APFS, ext4, NTFS, FAT/exFAT
/// long names and SAF providers all allow at least 255).
const int kMaxSegmentBytes = 255;

/// Name used when a segment sanitizes to nothing.
const String kUntitled = 'untitled';

/// The note file extension.
const String kNoteExtension = '.md';

/// Characters never allowed in a file or folder name: Windows-reserved
/// `\ / : * ? " < > |` (vaults are often synced to Windows) plus the
/// Obsidian link-breaking `# ^ [ ]` (a note named `a#b` cannot be
/// wikilinked).
final RegExp _reserved = RegExp(r'[\\/:*?"<>|#^\[\]]');

/// C0/C1 controls, DEL, line/paragraph separators, BOM and every bidi
/// control (U+200E/F, U+202A–E, U+2066–9: they can disguise an extension,
/// e.g. `note\u202Edm.exe`).
final RegExp _invisible = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u2028\u2029\uFEFF'
  r'\u200E\u200F\u202A-\u202E\u2066-\u2069]',
);

/// Whitespace controls and line breaks become spaces (then collapse).
final RegExp _lineSpace = RegExp(r'[\t\n\v\f\r\u0085\u2028\u2029]');

final RegExp _spaces = RegExp(r'\s+');

/// Windows device names (with or without an extension), case-insensitive.
final RegExp _windowsReserved = RegExp(
  r'^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])$',
  caseSensitive: false,
);

/// A sanitized file name split into stem and extension, so a collision
/// suffix can be added without breaking the byte limit.
class VaultFileName {
  const VaultFileName._(this.stem, this.extension);

  /// Sanitizes [raw] (see [sanitizeSegment]) and splits off [extension]
  /// (default `.md`; added when [raw] does not end with it).
  factory VaultFileName.parse(
    String raw, {
    String extension = kNoteExtension,
    int maxBytes = kMaxSegmentBytes,
  }) {
    var base = raw;
    if (base.toLowerCase().endsWith(extension)) {
      base = base.substring(0, base.length - extension.length);
    }
    final stem = _sanitizeStem(base, maxBytes - utf8Length(extension));
    return VaultFileName._(stem, extension);
  }

  final String stem;
  final String extension;

  String get name => '$stem$extension';

  /// `<stem>-<n><ext>`, truncating the stem (never mid-grapheme) so the
  /// result still fits [maxBytes].
  String withSuffix(int n, {int maxBytes = kMaxSegmentBytes}) {
    final suffix = '-$n';
    final room = maxBytes - utf8Length(extension) - utf8Length(suffix);
    final cut = _trimEnd(truncateUtf8(stem, room));
    return '${cut.isEmpty ? kUntitled : cut}$suffix$extension';
  }

  @override
  String toString() => 'VaultFileName(${utf8Length(name)} bytes)';
}

/// UTF-8 byte length of [s].
int utf8Length(String s) => utf8.encode(s).length;

/// The longest prefix of [s] whose UTF-8 encoding fits [maxBytes], cut on
/// a grapheme-cluster boundary (an emoji with ZWJ/skin tone/flag is kept
/// whole or dropped whole).
String truncateUtf8(String s, int maxBytes) {
  if (utf8Length(s) <= maxBytes) return s;
  final out = StringBuffer();
  var used = 0;
  for (final g in s.characters) {
    final n = utf8Length(g);
    if (used + n > maxBytes) break;
    out.write(g);
    used += n;
  }
  return out.toString();
}

/// Trailing dots and spaces are stripped by Windows / some SAF providers.
String _trimEnd(String s) => s.replaceFirst(RegExp(r'[. ]+$'), '');

/// Sanitizes one folder or file-name segment for iOS, Android (SAF) and
/// Windows-synced vaults:
/// NFC-normalized; reserved characters, controls and bidi marks removed;
/// whitespace collapsed; leading dots/spaces (hidden files, `.`/`..`) and
/// trailing dots/spaces removed; Windows device names (`CON`, `NUL`,
/// `COM1`…) get a `_`; at most [maxBytes] UTF-8 bytes without splitting a
/// grapheme; empty → `untitled`. Emoji are allowed.
String sanitizeSegment(String raw, {int maxBytes = kMaxSegmentBytes}) =>
    _sanitizeStem(raw, maxBytes);

String _sanitizeStem(String raw, int maxBytes) {
  var s = unorm.nfc(_fixSurrogates(raw));
  s = s.replaceAll(_lineSpace, ' ');
  s = s.replaceAll(_invisible, '').replaceAll(_reserved, '');
  s = s.replaceAll(_spaces, ' ');
  s = s.replaceFirst(RegExp('^[. ]+'), '');
  s = _trimEnd(s);
  final dot = s.indexOf('.');
  final device = dot < 0 ? s : s.substring(0, dot);
  if (_windowsReserved.hasMatch(device)) {
    s = '${device}_${dot < 0 ? '' : s.substring(dot)}';
  }
  s = _trimEnd(truncateUtf8(s, maxBytes));
  return s.isEmpty ? kUntitled : s;
}

String _fixSurrogates(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 < s.length) {
        final d = s.codeUnitAt(i + 1);
        if (d >= 0xDC00 && d <= 0xDFFF) {
          out
            ..writeCharCode(c)
            ..writeCharCode(d);
          i++;
          continue;
        }
      }
      continue; // unpaired: drop
    }
    if (c >= 0xDC00 && c <= 0xDFFF) continue;
    out.writeCharCode(c);
  }
  return out.toString();
}

/// Canonical form for comparing two vault paths: NFC + case-folded (iOS,
/// Windows and most Android storage are case-insensitive).
String pathKey(String relPath) => unorm.nfc(relPath).toLowerCase();
