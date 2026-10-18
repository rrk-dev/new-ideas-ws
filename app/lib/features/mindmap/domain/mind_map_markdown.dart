import 'package:vaultvoice/features/mindmap/domain/mind_map.dart';
import 'package:vaultvoice/features/templates/domain/markdown_sanitizer.dart';

/// Heading of the mind-map section in a note (English only).
const String kMindMapHeading = 'Mind map';

/// A node label made inert for Markdown (MAP-02): [sanitizeInline] (no block
/// markers, `[[`/`]]`, `{{`, `<` or backticks) plus brackets and bare-link
/// forms, so a model-written label can neither open a link nor autolink.
String mindMapLabel(String raw) {
  final inline = sanitizeInline(raw)
      .replaceAll(RegExp(r'(?<!\\)\['), r'\[')
      .replaceAll(RegExp(r'(?<!\\)\]'), r'\]')
      .replaceAll('://', r':\/\/')
      .replaceAll(RegExp(r'www\.', caseSensitive: false), r'www\.');
  return inline.isEmpty ? '…' : inline;
}

String _line(MindMapNode n) =>
    n.t == null ? mindMapLabel(n.label) : '${mindMapLabel(n.label)} (${n.t})';

/// The tree as a nested Markdown list (`-` markers, two-space indent): the
/// guaranteed export format. The root is the first item.
String mindMapMarkdownList(MindMapNode root) {
  final out = StringBuffer();
  void visit(MindMapNode n, int depth) {
    out.writeln('${'  ' * depth}- ${_line(n)}');
    for (final c in n.children) {
      visit(c, depth + 1);
    }
  }

  visit(root, 0);
  return out.toString();
}

/// The section appended to a note: `## Mind map`, a blank line and the list.
String mindMapNoteSection(MindMapNode root) =>
    '## $kMindMapHeading\n\n${mindMapMarkdownList(root)}';

/// The standalone file written next to the note (`<note>.mindmap.md`): a
/// title and the list; no front-matter, so nothing from the model can reach
/// one.
String mindMapStandaloneMarkdown(MindMapNode root) =>
    '# ${mindMapLabel(root.label)}\n\n'
    '## $kMindMapHeading\n\n'
    '${mindMapMarkdownList(root)}';

/// Appends [mindMapNoteSection] to a rendered [note]; a null [map] returns
/// the note unchanged.
String appendMindMapSection(String note, MindMapNode? map) {
  if (map == null) return note;
  final body = note.endsWith('\n') ? note : '$note\n';
  return '$body\n${mindMapNoteSection(map)}';
}

/// Parses a stored map (`mind_maps.json`) or null when it is not a valid
/// tree.
MindMapNode? mindMapFromJson(Object? json) {
  if (validateMindMap(json).isNotEmpty) return null;
  MindMapNode node(Map<Object?, Object?> m) => MindMapNode(
    id: m['id']! as String,
    label: m['label']! as String,
    t: m['t'] as String?,
    children: [
      for (final c in (m['children'] as List? ?? const []))
        node(c as Map<Object?, Object?>),
    ],
  );
  return node(json! as Map<Object?, Object?>);
}
