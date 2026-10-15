import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';

/// Index of the line playing at [atMs]: the last line starting at or before
/// it (0 when [atMs] precedes every line); -1 for no lines.
int lineIndexAt(List<TranscriptLine> lines, int atMs) {
  if (lines.isEmpty) return -1;
  var found = 0;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startMs <= atMs) found = i;
  }
  return found;
}

/// Read-only transcript of a recording with timestamps; opened at [atMs] it
/// scrolls to and highlights that line (APP-02 detail, APP-05 source links).
class TranscriptLinesScreen extends ConsumerStatefulWidget {
  const TranscriptLinesScreen({
    required this.recordingId,
    this.atMs,
    super.key,
  });

  final String recordingId;
  final int? atMs;

  @override
  ConsumerState<TranscriptLinesScreen> createState() =>
      _TranscriptLinesScreenState();
}

class _TranscriptLinesScreenState extends ConsumerState<TranscriptLinesScreen> {
  /// Rough line height used for the first jump before the exact scroll.
  static const double _estimatedExtent = 72;

  final _controller = ScrollController();
  final GlobalKey _targetKey = GlobalKey();
  bool _scrolled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollTo(int index) {
    if (_scrolled || index <= 0) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(
        (index * _estimatedExtent).clamp(
          0,
          _controller.position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _targetKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.3);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = ref.watch(recordingTranscriptProvider(widget.recordingId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recordingTranscript)),
      body: lines.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l10n.recordingLoadFailed,
        ),
        data: (all) {
          if (all.isEmpty) {
            return StatusMessage(
              icon: Icons.notes_outlined,
              message: l10n.recordingNoTranscript,
            );
          }
          final at = widget.atMs;
          final target = at == null ? -1 : lineIndexAt(all, at);
          _scrollTo(target);
          return ListView.builder(
            controller: _controller,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: all.length,
            itemBuilder: (context, i) => TranscriptLineTile(
              key: i == target ? _targetKey : ValueKey('line-$i'),
              line: all[i],
              highlighted: i == target,
            ),
          );
        },
      ),
    );
  }
}

/// `[mm:ss] Speaker: text`.
class TranscriptLineTile extends StatelessWidget {
  const TranscriptLineTile({
    required this.line,
    this.highlighted = false,
    super.key,
  });

  final TranscriptLine line;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speaker = line.speaker;
    return Container(
      color: highlighted ? theme.colorScheme.secondaryContainer : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Semantics(
        selected: highlighted,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text(
                formatTimestamp(line.startMs),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: highlighted
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                speaker == null || speaker.isEmpty
                    ? line.text
                    : context.l10n.transcriptSpeakerLine(speaker, line.text),
                style: highlighted
                    ? TextStyle(color: theme.colorScheme.onSecondaryContainer)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
