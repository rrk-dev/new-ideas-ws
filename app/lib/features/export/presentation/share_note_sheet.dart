import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/diagnostics/diagnostics_providers.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/platform/share_service.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/export/data/note_sharing.dart';
import 'package:vaultvoice/features/export/data/note_sharing_providers.dart';
import 'package:vaultvoice/features/templates/domain/builtin_templates.dart';

/// App-bar action that opens [ShareNoteSheet]; hidden until the recording
/// has a note (EXP-08 — works without any vault folder).
class ShareNoteButton extends ConsumerWidget {
  const ShareNoteButton({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formats =
        ref.watch(shareableFormatsProvider(recordingId)).value ?? const {};
    if (formats.isEmpty) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('note-share'),
      tooltip: context.l10n.noteShare,
      icon: const Icon(Icons.ios_share),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) =>
            ShareNoteSheet(recordingId: recordingId, formats: formats),
      ),
    );
  }
}

/// Pick a format, then share the note as a `.md` file or as text, or copy
/// it. Only runs on an explicit tap; the OS share sheet decides where the
/// note goes.
class ShareNoteSheet extends ConsumerStatefulWidget {
  const ShareNoteSheet({
    required this.recordingId,
    required this.formats,
    super.key,
  });

  final String recordingId;
  final Set<TemplateFlavor> formats;

  @override
  ConsumerState<ShareNoteSheet> createState() => _ShareNoteSheetState();
}

enum _Action { file, text, copy }

class _ShareNoteSheetState extends ConsumerState<ShareNoteSheet> {
  late TemplateFlavor _format = widget.formats.contains(TemplateFlavor.obsidian)
      ? TemplateFlavor.obsidian
      : widget.formats.first;
  bool _busy = false;

  Future<void> _run(_Action action) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    void say(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));
    try {
      final sharing = await ref.read(noteSharingProvider.future);
      final note = await sharing.render(widget.recordingId, _format);
      final ShareableNote value;
      switch (note) {
        case Err():
          say(l.noteShareFailed);
          return;
        case Ok(value: final v):
          value = v;
      }
      final share = ref.read(shareServiceProvider);
      final subject = value.fileName.replaceFirst(RegExp(r'\.md$'), '');
      final outcome = switch (action) {
        _Action.copy => null,
        _Action.text => await share.shareText(
          value.markdown,
          subject: subject,
          origin: origin,
        ),
        _Action.file => await share.shareFile(
          await NoteSharing.writeShareFile(
            ref.read(appPathsProvider).temp,
            value,
          ),
          mimeType: 'text/markdown',
          subject: subject,
          origin: origin,
        ),
      };
      if (action == _Action.copy) {
        await Clipboard.setData(ClipboardData(text: value.markdown));
        say(l.noteCopied);
      } else if (outcome == ShareOutcome.unavailable) {
        say(l.noteShareUnavailable);
        return;
      }
      if (navigator.canPop()) navigator.pop();
    } on Object {
      say(l.noteShareFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String label(TemplateFlavor f) => switch (f) {
      TemplateFlavor.obsidian => l.noteFormatObsidian,
      TemplateFlavor.logseq => l.noteFormatLogseq,
      TemplateFlavor.plain => l.noteFormatPlain,
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.noteShareTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l.noteShareFormat),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<TemplateFlavor>(
              key: const ValueKey('note-share-format'),
              segments: [
                for (final f in TemplateFlavor.values)
                  if (widget.formats.contains(f))
                    ButtonSegment(value: f, label: Text(label(f))),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.single),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              key: const ValueKey('note-share-file'),
              leading: const Icon(Icons.description_outlined),
              title: Text(l.noteShareFile),
              enabled: !_busy,
              onTap: () => _run(_Action.file),
            ),
            ListTile(
              key: const ValueKey('note-share-text'),
              leading: const Icon(Icons.short_text),
              title: Text(l.noteShareText),
              enabled: !_busy,
              onTap: () => _run(_Action.text),
            ),
            ListTile(
              key: const ValueKey('note-copy'),
              leading: const Icon(Icons.copy),
              title: Text(l.noteCopy),
              enabled: !_busy,
              onTap: () => _run(_Action.copy),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l.noteShareHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
