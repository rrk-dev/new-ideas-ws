import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';

/// Live input meter + clipping hint (AUD-02). Rebuilds only itself — inside
/// a [RepaintBoundary] — on each reading (20 Hz), so the rest of the screen
/// never repaints for the meter.
class LevelMeterBar extends ConsumerWidget {
  const LevelMeterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(recordingLevelsProvider).value ?? AudioLevel.silent;
    return LevelMeterView(level: level);
  }
}

/// Stateless rendering of one [AudioLevel] (golden/widget-testable).
class LevelMeterView extends StatelessWidget {
  const LevelMeterView({required this.level, super.key});

  final AudioLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: Semantics(
            label: l10n.recordingLevelLabel,
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                key: const ValueKey('level-meter'),
                value: level.normalized(),
                minHeight: AppSpacing.sm,
                color: level.clipping ? scheme.error : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
        if (level.clipping)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.clippingHint,
                key: const ValueKey('clipping-hint'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
