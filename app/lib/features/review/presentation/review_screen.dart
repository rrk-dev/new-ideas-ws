import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/routing/app_routes.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/library/data/library_providers.dart';
import 'package:vaultvoice/features/library/domain/recording_detail.dart';
import 'package:vaultvoice/features/library/presentation/transcript_navigation.dart';
import 'package:vaultvoice/features/pipeline/presentation/processing_providers.dart';
import 'package:vaultvoice/features/pipeline/presentation/recording_status_screen.dart';
import 'package:vaultvoice/features/profiles/domain/profile.dart';
import 'package:vaultvoice/features/review/data/review_providers.dart';
import 'package:vaultvoice/features/review/domain/review_policy.dart';
import 'package:vaultvoice/features/review/presentation/schema_form.dart';

/// Review & edit the extracted result before export (APP-05): a form
/// generated from the profile schema, source links to the transcript/audio
/// position of each item, a rendered Markdown preview, and "Export" which
/// saves the edits and lets the pipeline write the note.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.recordingId, super.key});

  final String recordingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final extraction = ref.watch(recordingExtractionProvider(recordingId));
    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: body,
    );
    return extraction.when(
      loading: () => scaffold(
        Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
      ),
      error: (_, _) => scaffold(
        StatusMessage(
          icon: Icons.error_outline,
          message: l10n.recordingLoadFailed,
        ),
      ),
      data: (ext) {
        if (ext == null) {
          return scaffold(
            StatusMessage(
              icon: Icons.hourglass_empty,
              message: l10n.recordingNoExtraction,
            ),
          );
        }
        final profile = ref.watch(reviewProfileProvider(ext.profileId));
        return profile.when(
          loading: () => scaffold(
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.commonLoading,
              ),
            ),
          ),
          error: (_, _) => scaffold(
            StatusMessage(
              icon: Icons.error_outline,
              message: l10n.reviewProfileMissing,
            ),
          ),
          data: (p) => p == null
              ? scaffold(
                  StatusMessage(
                    icon: Icons.error_outline,
                    message: l10n.reviewProfileMissing,
                  ),
                )
              : _ReviewEditor(
                  key: ValueKey(ext.id),
                  recordingId: recordingId,
                  extraction: ext,
                  profile: p,
                ),
        );
      },
    );
  }
}

class _ReviewEditor extends ConsumerStatefulWidget {
  const _ReviewEditor({
    required this.recordingId,
    required this.extraction,
    required this.profile,
    super.key,
  });

  final String recordingId;
  final ExtractionView extraction;
  final Profile profile;

  @override
  ConsumerState<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<_ReviewEditor> {
  late Map<String, Object?> _data = {
    for (final k in widget.profile.schema.properties.keys)
      k:
          widget.extraction.data[k] ??
          emptyValueFor(widget.profile.schema.properties[k]!),
  };
  bool _busy = false;
  bool _inputValid = true;

  void _openSource(int atMs) => ref
      .read(transcriptNavigatorProvider)
      .open(context, widget.recordingId, atMs: atMs);

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    final views = await ref.read(processingViewsProvider.future);
    final job = currentViewFor(views, widget.recordingId)?.job;
    final result = await ref
        .read(reviewServiceProvider)
        .approveAndExport(
          extractionId: widget.extraction.id,
          edited: _data,
          valid: true,
          job: job,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.isOk ? l10n.reviewExported : l10n.reviewFailed),
      ),
    );
    if (result.isOk) {
      RecordingStatusRoute(recordingId: widget.recordingId).go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issues = validateEdited(widget.profile.schema, _data);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.reviewTabEdit),
              Tab(text: l10n.reviewTabPreview),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              key: const ValueKey('review-form'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.reviewIntro(widget.profile.name)),
                const SizedBox(height: AppSpacing.sm),
                SchemaForm(
                  schema: widget.profile.schema,
                  value: _data,
                  onChanged: (v) => setState(() => _data = v),
                  onSourceTap: _openSource,
                  onInputValidityChanged: (ok) =>
                      setState(() => _inputValid = ok),
                ),
              ],
            ),
            _Preview(
              recordingId: widget.recordingId,
              extractionId: widget.extraction.id,
              data: _data,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (issues.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      l10n.reviewInvalid(issues.length),
                      key: const ValueKey('review-issues'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  key: const ValueKey('review-export'),
                  onPressed: _busy || !_inputValid || issues.isNotEmpty
                      ? null
                      : _export,
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.reviewExport),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The note as it would be written, rendered from the current edits.
class _Preview extends ConsumerWidget {
  const _Preview({
    required this.recordingId,
    required this.extractionId,
    required this.data,
  });

  final String recordingId;
  final String extractionId;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final renderer = ref.watch(previewRendererProvider);
    return renderer.when(
      loading: () => Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
      ),
      error: (_, _) => StatusMessage(
        icon: Icons.error_outline,
        message: l10n.reviewPreviewFailed,
      ),
      data: (render) => FutureBuilder(
        future: ref
            .read(reviewServiceProvider)
            .preview(
              recordingId: recordingId,
              extractionId: extractionId,
              edited: data,
              renderer: render,
            ),
        builder: (context, snapshot) {
          final md = snapshot.data?.valueOrNull;
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.commonLoading,
              ),
            );
          }
          if (md == null) {
            return StatusMessage(
              icon: Icons.error_outline,
              message: l10n.reviewPreviewFailed,
            );
          }
          return SingleChildScrollView(
            key: const ValueKey('review-preview'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              md,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          );
        },
      ),
    );
  }
}
