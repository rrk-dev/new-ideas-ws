import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/field_helper.dart';
import 'package:vaultvoice/features/library/domain/extraction_summary.dart';
import 'package:vaultvoice/features/profiles/domain/profile_schema.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';

/// Name of the LLM-05 evidence field holding the `hh:mm:ss` source position.
const kEvidenceField = 't';

/// Empty value for a new item of [node] (form "Add" button).
Object? emptyValueFor(SchemaNode node) => switch (node) {
  ObjectSchema(:final properties) => <String, Object?>{
    for (final e in properties.entries) e.key: emptyValueFor(e.value),
  },
  ArraySchema() => <Object?>[],
  StringSchema(:final nullable, :final enumValues) =>
    nullable ? null : (enumValues?.first ?? ''),
  NumberSchema(:final nullable) => nullable ? null : 0,
  BooleanSchema(:final nullable) => nullable ? null : false,
};

/// Returns a copy of [root] with [value] at [path] (map keys / list
/// indices).
Object? setIn(Object? root, List<Object> path, Object? value) {
  if (path.isEmpty) return value;
  final head = path.first;
  final rest = path.sublist(1);
  if (head is int) {
    final list = [...(root as List<Object?>? ?? const [])];
    list[head] = setIn(list[head], rest, value);
    return list;
  }
  final map = {...(root as Map<String, Object?>? ?? const {})};
  map[head as String] = setIn(map[head], rest, value);
  return map;
}

/// Edit form generated from a profile output schema (APP-05): text fields
/// for strings (dropdowns for enums), number fields, switches, repeatable
/// groups for arrays (add/remove), cards for objects. Evidence timestamps
/// (`t`) get a "play from here" link via [onSourceTap].
class SchemaForm extends StatefulWidget {
  const SchemaForm({
    required this.schema,
    required this.value,
    required this.onChanged,
    this.onSourceTap,
    this.onInputValidityChanged,
    super.key,
  });

  final ObjectSchema schema;
  final Map<String, Object?> value;
  final ValueChanged<Map<String, Object?>> onChanged;

  /// Called with the recording position (ms) of an evidence timestamp.
  final ValueChanged<int>? onSourceTap;

  /// Reports whether every number field currently holds a valid number;
  /// invalid text is kept in the field and never written to the value.
  final ValueChanged<bool>? onInputValidityChanged;

  @override
  State<SchemaForm> createState() => _SchemaFormState();
}

class _SchemaFormState extends State<SchemaForm> {
  /// Bumped on every add/remove so fields re-read their initial values
  /// (list indices shift).
  int _generation = 0;

  /// Paths of number fields whose text is not a valid number.
  final _invalidNumbers = <String>{};

  void _set(List<Object> path, Object? value, {bool structural = false}) {
    if (structural) setState(() => _generation++);
    widget.onChanged(setIn(widget.value, path, value)! as Map<String, Object?>);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in widget.schema.properties.entries)
        _node(context, e.key, e.value, widget.value[e.key], [e.key]),
    ],
  );

  Widget _node(
    BuildContext context,
    String name,
    SchemaNode node,
    Object? value,
    List<Object> path,
  ) {
    final label = humanizeFieldName(name);
    final key = ValueKey('field-$_generation-${path.join('.')}');
    return switch (node) {
      ObjectSchema(:final properties) => Card(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in properties.entries)
                _node(
                  context,
                  p.key,
                  p.value,
                  (value as Map<String, Object?>?)?[p.key],
                  [...path, p.key],
                ),
            ],
          ),
        ),
      ),
      ArraySchema() => _array(context, label, node, value, path, key),
      StringSchema(:final enumValues?) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: DropdownButtonFormField<String?>(
          key: key,
          initialValue: value is String && enumValues.contains(value)
              ? value
              : null,
          decoration: InputDecoration(labelText: label),
          items: [
            if (node.nullable)
              DropdownMenuItem(child: Text(context.l10n.reviewFieldNone)),
            for (final v in enumValues)
              DropdownMenuItem(value: v, child: Text(v)),
          ],
          onChanged: (v) => _set(path, v),
        ),
      ),
      StringSchema(:final maxLength) => _text(
        context,
        key: key,
        label: name == kEvidenceField ? context.l10n.reviewFieldSource : label,
        helper: node.description,
        value: value is String ? value : '',
        maxLength: maxLength,
        multiline: (maxLength ?? 0) > 120,
        onChanged: (v) => _set(path, v.isEmpty && node.nullable ? null : v),
        source: name == kEvidenceField ? timestampToMs(value) : null,
      ),
      NumberSchema(:final integer) => _text(
        context,
        key: key,
        label: label,
        helper: node.description,
        value: value is num ? '$value' : '',
        number: true,
        errorText: _invalidNumbers.contains(path.join('.'))
            ? context.l10n.reviewNumberInvalid
            : null,
        onChanged: (v) {
          final id = path.join('.');
          final blankOk = v.isEmpty && node.nullable;
          final n = blankOk
              ? null
              : (integer ? int.tryParse(v) : num.tryParse(v));
          final wasValid = _invalidNumbers.isEmpty;
          final valid = blankOk || n != null;
          setState(() {
            if (valid) {
              _invalidNumbers.remove(id);
            } else {
              _invalidNumbers.add(id);
            }
          });
          if (wasValid != _invalidNumbers.isEmpty) {
            widget.onInputValidityChanged?.call(_invalidNumbers.isEmpty);
          }
          if (valid) _set(path, n);
        },
      ),
      BooleanSchema() => SwitchListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value == true,
        onChanged: (v) => _set(path, v),
      ),
    };
  }

  Widget _text(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? helper,
    String? errorText,
    int? maxLength,
    bool multiline = false,
    bool number = false,
    int? source,
  }) {
    final tap = widget.onSourceTap;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: TextFormField(
        key: key,
        initialValue: value,
        maxLength: maxLength,
        minLines: 1,
        maxLines: multiline ? 6 : 1,
        keyboardType: number ? TextInputType.number : null,
        inputFormatters: number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          helper: helper == null ? null : FieldHelper(helper),
          errorText: errorText,
          counterText: '',
          suffixIcon: source == null || tap == null
              ? null
              : IconButton(
                  key: ValueKey('source-link-$value'),
                  tooltip: context.l10n.reviewPlayFrom(value),
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () => tap(source),
                ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _array(
    BuildContext context,
    String label,
    ArraySchema node,
    Object? value,
    List<Object> path,
    Key key,
  ) {
    final items = value is List<Object?> ? value : const <Object?>[];
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final (i, item) in items.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _node(context, label, node.items, item, [...path, i]),
                ),
                IconButton(
                  tooltip: context.l10n.reviewRemoveItem(label),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () =>
                      _set(path, [...items]..removeAt(i), structural: true),
                ),
              ],
            ),
          if (items.length < node.maxItems)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('add-${path.join('.')}'),
                onPressed: () => _set(path, [
                  ...items,
                  emptyValueFor(node.items),
                ], structural: true),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.reviewAddItem(label)),
              ),
            ),
        ],
      ),
    );
  }
}
