import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/core/widgets/status_message.dart';
import 'package:vaultvoice/features/review/data/review_providers.dart';

/// Settings › Export › Review before export (APP-05): per profile, export
/// automatically or open the result for review first.
class ReviewSettingsScreen extends ConsumerWidget {
  const ReviewSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(reviewProfilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewSettingsTitle)),
      body: profiles.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
        ),
        error: (_, _) => StatusMessage(
          icon: Icons.error_outline,
          message: l10n.reviewSettingsLoadFailed,
          actionLabel: l10n.commonTryAgain,
          onAction: () => ref.invalidate(reviewProfilesProvider),
        ),
        data: (list) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l10n.reviewSettingsIntro),
            ),
            for (final p in list)
              SwitchListTile(
                key: ValueKey('review-mode-${p.id}'),
                title: Text(p.name),
                subtitle: Text(
                  ref.watch(reviewModeProvider(p.id)).value ?? false
                      ? l10n.reviewModeReview
                      : l10n.reviewModeAuto,
                ),
                value: ref.watch(reviewModeProvider(p.id)).value ?? false,
                onChanged: (v) =>
                    ref.read(reviewServiceProvider).setMode(p.id, review: v),
              ),
          ],
        ),
      ),
    );
  }
}
