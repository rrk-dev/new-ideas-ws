import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/widgets/section_header.dart';
import 'package:vaultvoice/features/settings/domain/setting_definitions.dart';
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Key of the tile editing [settingKey] (tests find tiles by it).
ValueKey<String> settingTileKey(String settingKey) =>
    ValueKey('setting-$settingKey');

/// Section header inside the settings list.
class SettingsSectionHeader extends SectionHeader {
  const SettingsSectionHeader(super.title, {super.key});
}

/// Edits one [SettingDef]; read-only (with a lock) when managed (LIC-04).
class SettingTile extends ConsumerWidget {
  const SettingTile(this.def, {super.key});

  final SettingDef<Object> def;

  Future<void> _write(BuildContext context, WidgetRef ref, Object v) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.l10n.settingSaveFailed;
    final result = await ref.read(settingsWriterProvider).set(def, v);
    if (!result.isOk) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingStateProvider(def.key));
    final title = SettingTexts.title(context.l10n, def.key);
    final value = state.value?.value ?? def.defaultValue;
    final managed = state.value?.managed ?? false;
    final description = SettingTexts.description(context.l10n, def.key);
    final key = settingTileKey(def.key);
    Widget? subtitleFor(String? text) {
      final lines = [?text, if (managed) context.l10n.settingManaged];
      return lines.isEmpty ? null : Text(lines.join('\n'));
    }

    final lock = Icon(
      Icons.lock_outline,
      semanticLabel: context.l10n.settingManaged,
    );
    final setting = def;
    switch (setting) {
      case ToggleSetting():
        return SwitchListTile(
          key: key,
          title: Text(title),
          subtitle: subtitleFor(description),
          secondary: managed ? lock : null,
          value: value as bool,
          onChanged: managed || !state.hasValue
              ? null
              : (v) => _write(context, ref, v),
        );
      case ChoiceSetting():
        final current = value as String;
        return ListTile(
          key: key,
          title: Text(title),
          subtitle: subtitleFor(SettingTexts.option(context.l10n, current)),
          trailing: managed ? lock : const Icon(Icons.chevron_right),
          enabled: !managed && state.hasValue,
          onTap: () async {
            final picked = await showDialog<String>(
              context: context,
              builder: (_) => ChoiceDialog(def: setting, current: current),
            );
            if (picked != null && picked != current && context.mounted) {
              await _write(context, ref, picked);
            }
          },
        );
      case TextSetting():
        final current = value as String;
        return ListTile(
          key: key,
          title: Text(title),
          subtitle: subtitleFor(current),
          trailing: managed ? lock : const Icon(Icons.edit_outlined),
          enabled: !managed && state.hasValue,
          onTap: () async {
            final entered = await showDialog<String>(
              context: context,
              builder: (_) => TextSettingDialog(def: setting, current: current),
            );
            if (entered != null && entered != current && context.mounted) {
              await _write(context, ref, entered);
            }
          },
        );
    }
  }
}

/// Single-choice picker; pops the chosen option id.
class ChoiceDialog extends StatelessWidget {
  const ChoiceDialog({required this.def, required this.current, super.key});

  final ChoiceSetting def;
  final String current;

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: Text(SettingTexts.title(context.l10n, def.key)),
    children: [
      for (final o in def.options)
        Semantics(
          selected: o == current,
          inMutuallyExclusiveGroup: true,
          child: ListTile(
            key: ValueKey('option-$o'),
            leading: Icon(
              o == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(SettingTexts.option(context.l10n, o)),
            onTap: () => Navigator.of(context).pop(o),
          ),
        ),
    ],
  );
}

/// Text entry with validation; pops the trimmed value on Save.
class TextSettingDialog extends StatefulWidget {
  const TextSettingDialog({
    required this.def,
    required this.current,
    super.key,
  });

  final TextSetting def;
  final String current;

  @override
  State<TextSettingDialog> createState() => _TextSettingDialogState();
}

class _TextSettingDialogState extends State<TextSettingDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = _controller.text.trim();
    final code = widget.def.validate(v);
    if (code != null) {
      setState(() => _error = SettingTexts.patternError(context.l10n, code));
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(SettingTexts.title(context.l10n, widget.def.key)),
    content: TextField(
      key: const ValueKey('setting-text-field'),
      controller: _controller,
      autofocus: true,
      maxLength: widget.def.maxLength,
      decoration: InputDecoration(errorText: _error),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => _controller.text = widget.def.defaultValue,
        child: Text(context.l10n.commonReset),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.commonCancel),
      ),
      FilledButton(onPressed: _save, child: Text(context.l10n.commonSave)),
    ],
  );
}
