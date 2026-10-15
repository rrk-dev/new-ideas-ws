import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_player.dart';
import 'package:vaultvoice/features/transcription/domain/transcript_view.dart';
import 'package:vaultvoice/features/transcription/presentation/speaker_names_dialog.dart';
import 'package:vaultvoice/features/transcription/presentation/transcript_providers.dart';

/// `m:ss` / `h:mm:ss` for a recording time.
String formatTranscriptTime(int ms) {
  final t = Duration(milliseconds: ms);
  final h = t.inHours;
  final m = t.inMinutes.remainder(60);
  final s = t.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// STT-06: review, play back and correct a transcript, then re-extract.
class TranscriptScreen extends ConsumerWidget {
  const TranscriptScreen({required this.recordingId, this.atMs, super.key});

  final String recordingId;

  /// Open at this recording position (ms): scroll to its segment and play
  /// from it (integration wave 3: APP-02 / APP-05 transcript links).
  final int? atMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final view = ref.watch(transcriptViewProvider(recordingId));
    final data = view.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.transcriptTitle),
        actions: [
          if (data != null) ...[
            IconButton(
              tooltip: l.transcriptFindReplace,
              icon: const Icon(Icons.find_replace),
              onPressed: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) =>
                      FindReplaceDialog(recordingId: recordingId, view: data),
                ),
              ),
            ),
            IconButton(
              tooltip: l.transcriptSpeakers,
              icon: const Icon(Icons.record_voice_over_outlined),
              onPressed: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => SpeakerNamesDialog(recordingId: recordingId),
                ),
              ),
            ),
            IconButton(
              tooltip: l.transcriptReExtract,
              icon: const Icon(Icons.auto_fix_high),
              onPressed: () => unawaited(_reExtract(context, ref)),
            ),
          ],
        ],
      ),
      body: view.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l.transcriptLoadFailed,
          actionLabel: l.commonTryAgain,
          onAction: () => ref.invalidate(transcriptViewProvider(recordingId)),
        ),
        data: (data) => data == null || data.segments.isEmpty
            ? StatusMessage(
                icon: Icons.notes_outlined,
                message: l.transcriptEmpty,
              )
            : _TranscriptBody(recordingId: recordingId, data: data, atMs: atMs),
      ),
    );
  }

  Future<void> _reExtract(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await ref.read(transcriptEditorProvider(recordingId)).reExtract();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          r.isOk ? l.transcriptReExtractStarted : l.transcriptReExtractFailed,
        ),
      ),
    );
  }
}

class _TranscriptBody extends ConsumerStatefulWidget {
  const _TranscriptBody({
    required this.recordingId,
    required this.data,
    this.atMs,
  });

  final String recordingId;
  final TranscriptViewData data;
  final int? atMs;

  @override
  ConsumerState<_TranscriptBody> createState() => _TranscriptBodyState();
}

class _TranscriptBodyState extends ConsumerState<_TranscriptBody> {
  final _scroll = ScrollController();
  final GlobalKey _targetKey = GlobalKey();
  bool _scrolled = false;
  bool _played = false;

  String get recordingId => widget.recordingId;
  TranscriptViewData get data => widget.data;

  /// Index (in [TranscriptViewData.segments]) of the segment at atMs.
  int? get _target {
    final at = widget.atMs;
    if (at == null) return null;
    final i = activeSegmentIndex(data.segments, at);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    if (widget.atMs != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Lazy list: jump near the target by its share of the list, then bring
  /// the built tile fully into view.
  void _scrollToTarget([int attempt = 0]) {
    if (!mounted || _scrolled) return;
    final ctx = _targetKey.currentContext;
    if (ctx != null) {
      _scrolled = true;
      Scrollable.ensureVisible(ctx, alignment: 0.2);
      return;
    }
    final target = _target;
    if (target == null || !_scroll.hasClients || attempt > 3) return;
    final items = data.items;
    final pos = items.indexWhere(
      (it) => it is SegmentItem && it.index == target,
    );
    if (pos > 0) {
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo((max * pos / items.length).clamp(0, max));
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToTarget(attempt + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(transcriptPlaybackProvider(recordingId));
    final at = widget.atMs;
    // PRODUCT-DECISION (integration W3): a transcript link plays from its
    // position once playback is ready ("play from here").
    if (at != null && !_played && playback.value != null) {
      _played = true;
      unawaited(playback.value!.playFrom(at));
    }
    final target = _target;
    final items = data.items;
    final hasLowConfidence = data.segments.any(
      (s) => s.lowConfidence.isNotEmpty,
    );
    return Column(
      children: [
        if (hasLowConfidence)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Text(
              context.l10n.transcriptLowConfidenceHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: StreamBuilder<int>(
            stream: playback.value?.recordingPositionMs,
            builder: (context, position) {
              final active = position.hasData
                  ? activeSegmentIndex(data.segments, position.data!)
                  : -1;
              return ListView.builder(
                controller: _scroll,
                itemCount: items.length,
                itemBuilder: (context, i) => switch (items[i]) {
                  SegmentItem(:final segment, :final index) => SegmentTile(
                    key: index == target
                        ? _targetKey
                        : ValueKey('segment-${segment.id}'),
                    recordingId: recordingId,
                    segment: segment,
                    active: index == active,
                    onPlay: playback.value == null
                        ? null
                        : () => unawaited(
                            playback.value!.playFrom(segment.startMs),
                          ),
                  ),
                  MarkerItem(:final marker) => MarkerTile(
                    key: ValueKey('marker-${marker.id}'),
                    marker: marker,
                  ),
                },
              );
            },
          ),
        ),
        _PlayerBar(playback: playback.value),
      ],
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.playback});

  final TranscriptPlayback? playback;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = playback;
    return Material(
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: p == null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(l.transcriptPlaybackUnavailable),
                )
              : StreamBuilder<bool>(
                  stream: p.playing,
                  builder: (context, snap) {
                    final playing = snap.data ?? false;
                    return Row(
                      children: [
                        IconButton(
                          tooltip: playing
                              ? l.transcriptPause
                              : l.transcriptPlay,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          onPressed: () =>
                              unawaited(p.toggle(playing: playing)),
                        ),
                        StreamBuilder<int>(
                          stream: p.recordingPositionMs,
                          builder: (context, pos) =>
                              Text(formatTranscriptTime(pos.data ?? 0)),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// One transcript segment: speaker chip, time, text with low-confidence
/// words underlined; tap plays from its start, the edit button edits it
/// inline.
class SegmentTile extends ConsumerStatefulWidget {
  const SegmentTile({
    required this.recordingId,
    required this.segment,
    required this.active,
    required this.onPlay,
    super.key,
  });

  final String recordingId;
  final TranscriptSegmentView segment;
  final bool active;
  final VoidCallback? onPlay;

  @override
  ConsumerState<SegmentTile> createState() => _SegmentTileState();
}

class _SegmentTileState extends ConsumerState<SegmentTile> {
  TextEditingController? _edit;

  @override
  void dispose() {
    _edit?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _edit!.text;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await ref
        .read(transcriptEditorProvider(widget.recordingId))
        .editSegment(widget.segment.id, text);
    if (!mounted) return;
    if (r.isOk) {
      setState(() {
        _edit?.dispose();
        _edit = null;
      });
    } else {
      messenger?.showSnackBar(SnackBar(content: Text(l.transcriptEditFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = widget.segment;
    final time = formatTranscriptTime(s.startMs);
    final header = Row(
      children: [
        if (s.speaker != null) ...[
          Chip(label: Text(s.speaker!), visualDensity: VisualDensity.compact),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(time, style: theme.textTheme.labelMedium),
        if (s.edited) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            l.transcriptEdited,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const Spacer(),
        if (_edit == null)
          IconButton(
            tooltip: l.transcriptEditSegment(time),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                setState(() => _edit = TextEditingController(text: s.text)),
          ),
      ],
    );
    final Widget body;
    if (_edit != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: _edit,
            autofocus: true,
            maxLines: null,
            decoration: InputDecoration(
              labelText: l.transcriptEditSegment(time),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _edit?.dispose();
                  _edit = null;
                }),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: () => unawaited(_save()),
                child: Text(l.commonSave),
              ),
            ],
          ),
        ],
      );
    } else {
      body = Semantics(
        button: widget.onPlay != null,
        label: l.transcriptSegmentLabel(
          s.speaker ?? l.transcriptNoSpeaker,
          time,
          s.text,
        ),
        excludeSemantics: true,
        child: InkWell(
          onTap: widget.onPlay,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text.rich(
                lowConfidenceText(s, theme.textTheme.bodyLarge, theme),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      color: widget.active ? theme.colorScheme.secondaryContainer : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, body],
      ),
    );
  }
}

/// The segment text with every low-confidence range underlined (wavy, in
/// the theme's error colour) — not colour alone, so it is visible to
/// colour-blind users too.
TextSpan lowConfidenceText(
  TranscriptSegmentView s,
  TextStyle? base,
  ThemeData theme,
) {
  final ranges = s.lowConfidence;
  if (ranges.isEmpty) return TextSpan(text: s.text, style: base);
  final low = (base ?? const TextStyle()).copyWith(
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.wavy,
    decorationColor: theme.colorScheme.error,
  );
  final children = <TextSpan>[];
  var at = 0;
  for (final r in ranges) {
    if (r.start > at) {
      children.add(TextSpan(text: s.text.substring(at, r.start)));
    }
    children.add(TextSpan(text: s.text.substring(r.start, r.end), style: low));
    at = r.end;
  }
  if (at < s.text.length) children.add(TextSpan(text: s.text.substring(at)));
  return TextSpan(style: base, children: children);
}

/// A timeline marker between segments.
class MarkerTile extends StatelessWidget {
  const MarkerTile({required this.marker, super.key});

  final TranscriptMarkerView marker;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final kind = switch (marker.kind) {
      TranscriptMarkerKind.user => l.transcriptMarkerUser,
      TranscriptMarkerKind.gap => l.transcriptMarkerGap,
      TranscriptMarkerKind.callInterruption => l.transcriptMarkerCall,
    };
    final icon = switch (marker.kind) {
      TranscriptMarkerKind.user => Icons.flag_outlined,
      TranscriptMarkerKind.gap => Icons.more_horiz,
      TranscriptMarkerKind.callInterruption => Icons.phone_disabled_outlined,
    };
    final time = formatTranscriptTime(marker.atMs);
    final label = marker.label;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        label == null || label.isEmpty ? kind : label,
        semanticsLabel: l.transcriptMarkerLabel(
          label == null || label.isEmpty ? kind : label,
          time,
        ),
      ),
      trailing: Text(time),
    );
  }
}

/// Find & replace over this transcript only.
class FindReplaceDialog extends ConsumerStatefulWidget {
  const FindReplaceDialog({
    required this.recordingId,
    required this.view,
    super.key,
  });

  final String recordingId;
  final TranscriptViewData view;

  @override
  ConsumerState<FindReplaceDialog> createState() => _FindReplaceDialogState();
}

class _FindReplaceDialogState extends ConsumerState<FindReplaceDialog> {
  final _find = TextEditingController();
  final _replace = TextEditingController();
  bool _caseSensitive = false;

  @override
  void dispose() {
    _find.dispose();
    _replace.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = await ref
        .read(transcriptEditorProvider(widget.recordingId))
        .replaceAll(
          widget.view,
          _find.text,
          _replace.text,
          caseSensitive: _caseSensitive,
        );
    if (!mounted) return;
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          r.valueOrNull == null
              ? l.transcriptEditFailed
              : l.transcriptReplaced(r.valueOrNull!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matches = findInTranscript(
      widget.view.segments,
      _find.text,
      caseSensitive: _caseSensitive,
    ).length;
    return AlertDialog(
      title: Text(l.transcriptFindReplace),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _find,
              autofocus: true,
              decoration: InputDecoration(labelText: l.transcriptFind),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _replace,
              decoration: InputDecoration(labelText: l.transcriptReplaceWith),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _caseSensitive,
              title: Text(l.transcriptMatchCase),
              onChanged: (v) => setState(() => _caseSensitive = v ?? false),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l.transcriptMatchCount(matches)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: matches == 0 ? null : () => unawaited(_apply()),
          child: Text(l.transcriptReplaceAll),
        ),
      ],
    );
  }
}
