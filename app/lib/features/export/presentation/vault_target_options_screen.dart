import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/field_helper.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/export/data/routing_providers.dart';
import 'package:vaultvoice/features/export/domain/export_collision.dart';
import 'package:vaultvoice/features/export/domain/vault_target_options.dart';
import 'package:vaultvoice/features/export/presentation/routing_rule_editor_screen.dart'
    show filenamePatternError;
import 'package:vaultvoice/features/settings/presentation/setting_texts.dart';
import 'package:vaultvoice/features/settings/presentation/settings_providers.dart';

/// Export options of one vault folder (EXP-05): collision mode, file name
/// pattern override and the optional sidecars (off by default).
class VaultTargetOptionsScreen extends ConsumerWidget {
  const VaultTargetOptionsScreen({required this.targetId, super.key});

  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final targets = ref.watch(vaultTargetsProvider);
    final options = ref.watch(vaultTargetOptionsProvider);
    Widget scaffold(Widget body, {String? title}) => Scaffold(
      appBar: AppBar(title: Text(title ?? l.vaultTargetOptionsTitle)),
      body: body,
    );
    if (targets.isLoading || options.isLoading) {
      return scaffold(
        Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
      );
    }
    if (targets.hasError || options.hasError) {
      return scaffold(
        StatusMessage(
          icon: Icons.error_outline,
          message: l.vaultFoldersLoadFailed,
        ),
      );
    }
    final target = targets.value!.where((t) => t.id == targetId).firstOrNull;
    if (target == null) {
      return scaffold(
        StatusMessage(icon: Icons.search_off, message: l.vaultTargetNotFound),
      );
    }
    final all = options.value!;
    return scaffold(
      _OptionsForm(
        key: ValueKey('target-options-$targetId'),
        targetId: targetId,
        all: all,
        initial: all[targetId] ?? VaultTargetOptions.defaults,
      ),
      title: target.name,
    );
  }
}

class _OptionsForm extends ConsumerStatefulWidget {
  const _OptionsForm({
    required this.targetId,
    required this.all,
    required this.initial,
    super.key,
  });

  final String targetId;
  final Map<String, VaultTargetOptions> all;
  final VaultTargetOptions initial;

  @override
  ConsumerState<_OptionsForm> createState() => _OptionsFormState();
}

class _OptionsFormState extends ConsumerState<_OptionsForm> {
  late VaultTargetOptions _value = widget.initial;
  late final _pattern = TextEditingController(
    text: widget.initial.filenamePattern ?? '',
  );
  String? _patternError;

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  Future<void> _save(VaultTargetOptions next) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    setState(() => _value = next);
    final saved = await saveTargetOptions(
      ref.read(settingsStoreProvider),
      widget.all,
      widget.targetId,
      next,
    );
    if (saved case Err()) {
      messenger.showSnackBar(SnackBar(content: Text(l.vaultTargetSaveFailed)));
    }
  }

  void _savePattern() {
    final raw = _pattern.text.trim();
    final code = filenamePatternError(raw);
    setState(
      () => _patternError = code == null
          ? null
          : SettingTexts.patternError(context.l10n, code),
    );
    if (code != null) return;
    _save(_value.copyWith(filenamePattern: () => raw.isEmpty ? null : raw))
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(CollisionMode? m) => switch (m) {
      null => l.vaultTargetCollisionDefault,
      CollisionMode.suffix => l.optionCollisionSuffix,
      CollisionMode.overwrite => l.optionCollisionOverwrite,
      CollisionMode.skip => l.optionCollisionSkip,
    };
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DropdownButtonFormField<CollisionMode?>(
            key: const ValueKey('target-collision'),
            initialValue: _value.collision,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.vaultTargetCollision,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final m in <CollisionMode?>[null, ...CollisionMode.values])
                DropdownMenuItem(
                  value: m,
                  child: Text(label(m), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (m) => _save(_value.copyWith(collision: () => m)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextField(
            key: const ValueKey('target-pattern'),
            controller: _pattern,
            decoration: InputDecoration(
              labelText: l.vaultTargetFilename,
              helper: FieldHelper(l.routingRuleFilenameHint),
              errorText: _patternError,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _savePattern(),
            onTapOutside: (_) => _savePattern(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          key: const ValueKey('target-transcript'),
          title: Text(l.vaultTargetTranscript),
          subtitle: Text(l.vaultTargetTranscriptHelp),
          value: _value.transcriptSidecar,
          onChanged: (v) => _save(_value.copyWith(transcriptSidecar: v)),
        ),
        SwitchListTile(
          key: const ValueKey('target-audio'),
          title: Text(l.vaultTargetAudio),
          subtitle: Text(l.vaultTargetAudioHelp),
          value: _value.audioSidecar,
          onChanged: (v) => _save(_value.copyWith(audioSidecar: v)),
        ),
      ],
    );
  }
}
