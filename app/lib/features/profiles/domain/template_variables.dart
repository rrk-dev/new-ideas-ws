import 'package:vaultvoice/features/profiles/domain/profile_issue.dart';
import 'package:vaultvoice/features/profiles/domain/render_context.dart';

/// Lambdas whose section content is rendered as a template (tags inside are
/// checked like any other). The set is the `vv-markdown-vault-export`
/// lambda list; the implementations live in
/// `features/templates/domain/template_lambdas.dart` (EXP-01, documented in
/// `docs/templates.md`) — keep both in sync.
const Set<String> kContentLambdas = {
  'yaml',
  'wikilink',
  'slug',
  'upper',
  'lower',
  'trim',
  'checkbox',
  'code_block',
};

/// Lambdas whose section text is a literal argument (a date/duration
/// format), not a template. The optional form `path|FORMAT` names the
/// scalar to format (`{{#date}}data.due_iso|DD.MM.YYYY{{/date}}`); the path
/// is checked.
const Set<String> kTextArgLambdas = {'date', 'duration'};

/// Lambdas whose section text is a variable path that must name a list
/// (`{{#yaml_list}}data.attendees{{/yaml_list}}`), optionally followed by
/// `|arguments` (`{{#md_table}}data.tradeoffs|option,pros{{/md_table}}`).
const Set<String> kPathArgLambdas = {
  'yaml_list',
  'bullets',
  'md_table',
  'code_lines',
};

/// Lambdas used as plain variables (`{{transcript_block}}`).
const Set<String> kVariableLambdas = {'transcript_block', 'audio_link'};

/// Every lambda name.
final Set<String> kTemplateLambdas = {
  ...kContentLambdas,
  ...kTextArgLambdas,
  ...kPathArgLambdas,
  ...kVariableLambdas,
};

/// Checks every Mustache tag in [source] against [root] (the render-context
/// shape) with the rules of `mustache_template` in `lenient: false` mode:
/// unknown variables, sections/inverted sections on strings or numbers,
/// variables on lists/maps, unbalanced sections, partials and delimiter
/// changes (unsupported) are all reported with `line:column`.
///
/// Name resolution follows the Mustache spec: the first segment of a dotted
/// name is looked up from the innermost section scope outwards, the rest
/// strictly from there; lambdas are found last (they live at the root).
List<ProfileIssue> checkTemplateVariables(
  String source,
  MapShape root, {
  String name = 'template',
}) => _TemplateChecker(source, root, name).run();

class _Tag {
  _Tag(this.kind, this.name, this.start, this.end);

  /// One of `name`, `#`, `^`, `/`, `!`, `>`, `=`.
  final String kind;
  final String name;
  final int start;
  final int end;
}

class _Open {
  _Open(this.name, this.tag, {required this.pushed});

  final String name;
  final _Tag tag;
  final bool pushed;
}

class _TemplateChecker {
  _TemplateChecker(this.source, this.root, this.name);

  final String source;
  final MapShape root;
  final String name;
  final IssueSink sink = IssueSink();

  /// Section scopes, innermost last; null = a scope without fields (bool).
  final List<ContextShape?> scopes = [];

  List<ProfileIssue> run() {
    scopes
      ..clear()
      ..add(root);
    final open = <_Open>[];
    var pos = 0;
    while (true) {
      final tag = _nextTag(pos);
      if (tag == null) break;
      pos = tag.end;
      switch (tag.kind) {
        case '!':
          continue;
        case '>':
          _error(tag, 'partials ({{> ...}}) are not supported');
        case '=':
          _error(tag, 'changing delimiters ({{= =}}) is not supported');
          return sink.issues; // the rest cannot be tokenized reliably
        case '#' || '^':
          final lambda = _isLambda(tag.name);
          if (lambda && tag.kind == '#') {
            if (kTextArgLambdas.contains(tag.name) ||
                kPathArgLambdas.contains(tag.name)) {
              final close = _findClose(tag);
              if (close == null) {
                _error(tag, 'section "${tag.name}" is never closed');
                return sink.issues;
              }
              final arg = source.substring(tag.end, close.start);
              if (kPathArgLambdas.contains(tag.name)) {
                _checkPathArg(tag, arg);
              } else if (arg.contains('|')) {
                _checkScalarArg(tag, arg.substring(0, arg.indexOf('|')));
              }
              pos = close.end;
              continue;
            }
            open.add(_Open(tag.name, tag, pushed: false));
            continue;
          }
          open.add(_Open(tag.name, tag, pushed: _openSection(tag)));
        case '/':
          if (open.isEmpty) {
            _error(tag, 'closing "${tag.name}" without an open section');
            continue;
          }
          final top = open.removeLast();
          if (top.name != tag.name) {
            _error(
              tag,
              'closing "${tag.name}" but the open section is "${top.name}" '
              '(opened at ${_where(top.tag.start)})',
            );
          }
          if (top.pushed) scopes.removeLast();
        default:
          _checkVariable(tag);
      }
    }
    for (final o in open.reversed) {
      _error(o.tag, 'section "${o.name}" is never closed');
    }
    return sink.issues;
  }

  _Tag? _nextTag(int from) {
    final start = source.indexOf('{{', from);
    if (start < 0) return null;
    if (source.startsWith('{{{', start)) {
      final end = source.indexOf('}}}', start + 3);
      if (end < 0) return _unterminated(start);
      return _Tag(
        'name',
        source.substring(start + 3, end).trim(),
        start,
        end + 3,
      );
    }
    final end = source.indexOf('}}', start + 2);
    if (end < 0) return _unterminated(start);
    final body = source.substring(start + 2, end).trim();
    final first = body.isEmpty ? '' : body[0];
    const sigils = {'#', '^', '/', '!', '>', '=', '&'};
    if (sigils.contains(first)) {
      final kind = first == '&' ? 'name' : first;
      return _Tag(kind, body.substring(1).trim(), start, end + 2);
    }
    return _Tag('name', body, start, end + 2);
  }

  _Tag? _unterminated(int start) {
    sink.add('$name:${_where(start)}', 'tag "{{" is never closed with "}}"');
    return null;
  }

  _Tag? _findClose(_Tag open) {
    var pos = open.end;
    var depth = 0;
    while (true) {
      final tag = _nextTag(pos);
      if (tag == null) return null;
      pos = tag.end;
      if ((tag.kind == '#' || tag.kind == '^') && tag.name == open.name) {
        depth++;
      } else if (tag.kind == '/' && tag.name == open.name) {
        if (depth == 0) return tag;
        depth--;
      }
    }
  }

  bool _isLambda(String n) =>
      kTemplateLambdas.contains(n) && _resolve(n) == null;

  /// Opens a section; returns whether a scope was pushed.
  bool _openSection(_Tag tag) {
    final shape = _resolveOrReport(tag);
    if (shape == null) {
      // Already reported; an opaque scope keeps `{{.}}` inside from
      // cascading into a second error while outer names still resolve.
      scopes.add(const ScalarShape(ScalarKind.string, nullable: true));
      return true;
    }
    switch (shape) {
      case ScalarShape(:final kind) when kind != ScalarKind.boolean:
        final helper = _helperHint(tag.name);
        final inverted = tag.kind == '#' ? '' : 'inverted ';
        _error(
          tag,
          '"${tag.name}" is a ${kind.name}; a ${inverted}section on a '
          '${kind.name} throws in strict mode — use '
          '{{${tag.kind}$helper}}…{{/$helper}} instead',
        );
        return false;
      case ScalarShape():
        scopes.add(null);
      case ListShape(:final item):
        scopes.add(tag.kind == '#' ? item : null);
      case MapShape():
        scopes.add(tag.kind == '#' ? shape : null);
    }
    return true;
  }

  void _checkVariable(_Tag tag) {
    if (tag.name.isEmpty) {
      _error(tag, 'empty tag');
      return;
    }
    if (tag.name == '.') {
      final top = scopes.last;
      if (top is MapShape || top is ListShape) {
        _error(
          tag,
          '"." is an object here; name a field (e.g. {{task}}) instead',
        );
      }
      return;
    }
    if (kVariableLambdas.contains(tag.name) && _resolve(tag.name) == null) {
      return;
    }
    final shape = _resolveOrReport(tag);
    switch (shape) {
      case ListShape():
        _error(
          tag,
          '"${tag.name}" is a list; iterate it with '
          '{{#${tag.name}}}…{{/${tag.name}}} or a lambda such as yaml_list',
        );
      case MapShape():
        _error(tag, '"${tag.name}" is an object; name one of its fields');
      case ScalarShape() || null:
        break;
    }
  }

  void _checkScalarArg(_Tag tag, String rawPath) {
    final path = rawPath.trim();
    final shape = _resolve(path);
    if (shape == null) {
      _error(
        tag,
        '${tag.name} argument "$path" is not a variable path'
        '${_suggestion(path)}',
      );
    } else if (shape is! ScalarShape) {
      _error(tag, '${tag.name} argument "$path" must be a scalar');
    }
  }

  void _checkPathArg(_Tag tag, String rawArg) {
    final bar = rawArg.indexOf('|');
    final path = (bar < 0 ? rawArg : rawArg.substring(0, bar)).trim();
    final shape = _resolve(path);
    if (shape == null) {
      _error(
        tag,
        '${tag.name} argument "$path" is not a variable path'
        '${_suggestion(path)}',
      );
    } else if (shape is! ListShape) {
      _error(tag, '${tag.name} argument "$path" must be a list');
    } else if (tag.name == 'md_table' && bar >= 0) {
      final item = shape.item;
      for (final column in rawArg.substring(bar + 1).split(',')) {
        final c = column.trim();
        if (c.isEmpty) continue;
        if (item is! MapShape || item.lookup(c) == null) {
          _error(tag, 'md_table column "$c" is not a field of "$path"');
        }
      }
    }
  }

  ContextShape? _resolveOrReport(_Tag tag) {
    final shape = _resolve(tag.name);
    if (shape == null) {
      _error(
        tag,
        'unknown variable "${tag.name}" — not a profile schema field, '
        'post-processor field or render metadata${_suggestion(tag.name)}',
      );
    }
    return shape;
  }

  ContextShape? _resolve(String dotted) {
    final parts = dotted.split('.');
    if (parts.any((p) => p.isEmpty)) return null;
    for (final scope in scopes.reversed) {
      if (scope is! MapShape) continue;
      var current = scope.lookup(parts.first);
      if (current == null) continue;
      for (final part in parts.skip(1)) {
        current = current is MapShape ? current.lookup(part) : null;
        if (current == null) return null;
      }
      return current;
    }
    return null;
  }

  String _helperHint(String dotted) {
    final i = dotted.lastIndexOf('.');
    return i < 0
        ? 'has_$dotted'
        : '${dotted.substring(0, i)}.has_${dotted.substring(i + 1)}';
  }

  /// " (did you mean x?)" for a near miss among the names visible at the
  /// failing segment.
  String _suggestion(String dotted) {
    final parts = dotted.split('.');
    final candidates = <String>{};
    for (final scope in scopes.reversed) {
      if (scope is! MapShape) continue;
      var current = scope as ContextShape?;
      final prefix = <String>[];
      for (final part in parts) {
        if (current is! MapShape) break;
        final next = current.lookup(part);
        if (next == null) {
          for (final key in [
            ...current.fields.keys,
            for (final h in current.helpersFor) 'has_$h',
          ]) {
            if (_distance(key, part) <= 2) {
              candidates.add([...prefix, key].join('.'));
            }
          }
          break;
        }
        prefix.add(part);
        current = next;
      }
    }
    return candidates.isEmpty ? '' : ' (did you mean ${candidates.first}?)';
  }

  void _error(_Tag tag, String message) =>
      sink.add('$name:${_where(tag.start)}', message);

  String _where(int offset) {
    var line = 1;
    var col = 1;
    for (var i = 0; i < offset; i++) {
      if (source.codeUnitAt(i) == 0x0A) {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return '$line:$col';
  }
}

int _distance(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 3;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}
