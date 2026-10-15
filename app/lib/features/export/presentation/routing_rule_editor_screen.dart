import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/utils/ids.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/filename_pattern.dart';
import 'package:vaultvoice/features/export/domain/routing_rule.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Route parameter that opens the editor for a new rule.
const String kNewRuleId = 'new';

/// Splits a comma-separated field into trimmed, non-empty values.
List<String> splitValues(String raw) => [
  for (final v in raw.split(','))
    if (v.trim().isNotEmpty) v.trim(),
];

/// Error code of a filename pattern field ('' allowed = inherit), or null.
String? filenamePatternError(String raw) {
  if (raw.trim().isEmpty) return null;
  final basic = validateFilenamePattern(raw);
  if (basic != null) return basic;
  return FilenamePattern.parse(raw.trim()).isOk ? null : 'invalid';
}

/// Edits one routing rule (Settings → Routing rules → rule). Pro: callers
/// only open it when `Feature.routingRules` is available. Field values are
/// user content: shown, never logged.
class RoutingRuleEditorScreen extends ConsumerWidget {
  const RoutingRuleEditorScreen({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (ruleId == kNewRuleId) {
      return _RuleForm(
        key: const ValueKey('rule-form-new'),
        initial: null,
        nextPriority: _nextPriority(ref.watch(routingRuleListProvider).value),
      );
    }
    final rules = ref.watch(routingRuleListProvider);
    return rules.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l.routingRuleEditTitle)),
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(l.routingRuleEditTitle)),
        body: StatusMessage(
          icon: Icons.error_outline,
          message: l.routingRulesLoadFailed,
        ),
      ),
      data: (list) {
        final rule = list.where((r) => r.id == ruleId).firstOrNull;
        if (rule == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.routingRuleEditTitle)),
            body: StatusMessage(
              icon: Icons.search_off,
              message: l.routingRuleNotFound,
            ),
          );
        }
        return _RuleForm(
          key: ValueKey('rule-form-${rule.id}'),
          initial: rule,
          nextPriority: rule.priority,
        );
      },
    );
  }

  static int _nextPriority(List<RoutingRule>? rules) {
    if (rules == null || rules.isEmpty) return 10;
    return rules.map((r) => r.priority).reduce((a, b) => a > b ? a : b) + 10;
  }
}

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({
    required this.initial,
    required this.nextPriority,
    super.key,
  });

  final RoutingRule? initial;
  final int nextPriority;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _subPath;
  late final TextEditingController _pattern;
  late final TextEditingController _profiles;
  late final TextEditingController _tags;
  late final TextEditingController _keywords;
  late final TextEditingController _speakers;
  String? _targetId;
  late bool _continue;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    String join(List<String>? v) => (v ?? const []).join(', ');
    _name = TextEditingController(text: r?.name ?? '');
    _subPath = TextEditingController(text: r?.subPath ?? '');
    _pattern = TextEditingController(text: r?.filenamePattern ?? '');
    _profiles = TextEditingController(text: join(r?.match.profileIds));
    _tags = TextEditingController(text: join(r?.match.tagsAny));
    _keywords = TextEditingController(text: join(r?.match.keywordsAny));
    _speakers = TextEditingController(text: join(r?.match.speakersAny));
    _targetId = r?.targetId;
    _continue = r?.mode == RuleMode.continueMatching;
    _enabled = r?.enabled ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _subPath,
      _pattern,
      _profiles,
      _tags,
      _keywords,
      _speakers,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final failed = context.l10n.routingRuleSaveFailed;
    setState(() => _saving = true);
    final pattern = _pattern.text.trim();
    final rule = RoutingRule(
      id: widget.initial?.id ?? newUuidV4(),
      priority: widget.nextPriority,
      targetId: _targetId!,
      match: RuleMatch(
        profileIds: splitValues(_profiles.text),
        tagsAny: splitValues(_tags.text),
        keywordsAny: splitValues(_keywords.text),
        speakersAny: splitValues(_speakers.text),
        // Kept as-is: not editable until PRF-06 persists classifications.
        classificationAny: widget.initial?.match.classificationAny ?? const [],
      ),
      mode: _continue ? RuleMode.continueMatching : RuleMode.stop,
      subPath: _subPath.text.trim(),
      filenamePattern: pattern.isEmpty ? null : pattern,
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      enabled: _enabled,
    );
    final saved = await ref.read(routingRulesStoreProvider).save(rule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved case Err()) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.routingRuleDeleteTitle),
        content: Text(l.routingRuleDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.routingRuleDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(routingRulesStoreProvider).delete(widget.initial!.id);
    if (mounted && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final targets = ref.watch(vaultTargetsProvider).value ?? const [];
    final known = {for (final t in targets) t.id};
    final target = known.contains(_targetId) ? _targetId : null;
    InputDecoration deco(String label, {String? hint, String? helper}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
        );
    const gap = SizedBox(height: AppSpacing.md);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? l.routingRuleNewTitle
              : l.routingRuleEditTitle,
        ),
        actions: [
          if (widget.initial != null)
            IconButton(
              key: const ValueKey('rule-delete'),
              tooltip: l.routingRuleDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              key: const ValueKey('rule-name'),
              controller: _name,
              decoration: deco(l.routingRuleName),
            ),
            gap,
            if (targets.isEmpty)
              Text(l.routingRuleNoTargets)
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('rule-target'),
                initialValue: target,
                isExpanded: true,
                decoration: deco(l.routingRuleTarget),
                items: [
                  for (final t in targets)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (v) =>
                    v == null ? l.routingRuleTargetRequired : null,
                onChanged: (v) => setState(() => _targetId = v),
              ),
            gap,
            TextFormField(
              key: const ValueKey('rule-subpath'),
              controller: _subPath,
              decoration: deco(
                l.routingRuleSubPath,
                hint: l.routingRuleSubPathHint,
              ),
            ),
            gap,
            TextFormField(
              key: const ValueKey('rule-pattern'),
              controller: _pattern,
              decoration: deco(
                l.routingRuleFilename,
                helper: l.routingRuleFilenameHint,
              ),
              validator: (v) {
                final code = filenamePatternError(v ?? '');
                return code == null ? null : SettingTexts.patternError(l, code);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.routingRuleConditions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l.routingRuleConditionsHelp),
            gap,
            TextFormField(
              key: const ValueKey('rule-profiles'),
              controller: _profiles,
              decoration: deco(
                l.routingRuleProfiles,
                hint: 'meeting, warranty',
              ),
            ),
            gap,
            TextFormField(
              key: const ValueKey('rule-tags'),
              controller: _tags,
              decoration: deco(l.routingRuleTags),
            ),
            gap,
            TextFormField(
              key: const ValueKey('rule-keywords'),
              controller: _keywords,
              decoration: deco(l.routingRuleKeywords),
            ),
            gap,
            TextFormField(
              key: const ValueKey('rule-speakers'),
              controller: _speakers,
              decoration: deco(l.routingRuleSpeakers),
            ),
            gap,
            SwitchListTile(
              key: const ValueKey('rule-continue'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.routingRuleContinue),
              subtitle: Text(l.routingRuleContinueHelp),
              value: _continue,
              onChanged: (v) => setState(() => _continue = v),
            ),
            SwitchListTile(
              key: const ValueKey('rule-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.routingRuleEnabled),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            gap,
            FilledButton(
              key: const ValueKey('rule-save'),
              onPressed: _saving || targets.isEmpty ? null : _save,
              child: Text(l.routingRuleSave),
            ),
          ],
        ),
      ),
    );
  }
}
