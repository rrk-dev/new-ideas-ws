import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultvoice/core/l10n/l10n.dart';
import 'package:vaultvoice/core/theme/app_tokens.dart';
import 'package:vaultvoice/features/recording/data/recording_providers.dart';
import 'package:vaultvoice/features/recording/domain/level_meter.dart';

/// Fixed-size ring of the most recent [AudioLevel] readings (APP-09).
/// Notifies listeners on every [add]/[clear] so only the painter repaints.
class WaveformBuffer extends ChangeNotifier {
  WaveformBuffer(this.capacity)
    : assert(capacity > 0, 'capacity must be positive'),
      _ring = List<AudioLevel>.filled(capacity, AudioLevel.silent);

  final int capacity;
  final List<AudioLevel> _ring;
  var _next = 0;
  var _count = 0;

  /// Number of real readings held (≤ [capacity]).
  int get length => _count;

  /// The latest reading, or [AudioLevel.silent] when empty.
  AudioLevel get latest =>
      _count == 0 ? AudioLevel.silent : _ring[(_next - 1) % capacity];

  void add(AudioLevel level) {
    _ring[_next] = level;
    _next = (_next + 1) % capacity;
    _count = math.min(_count + 1, capacity);
    notifyListeners();
  }

  void clear() {
    if (_count == 0) return;
    _ring.fillRange(0, capacity, AudioLevel.silent);
    _next = 0;
    _count = 0;
    notifyListeners();
  }

  /// Exactly [capacity] readings, oldest first, the newest last (right edge);
  /// slots not yet filled are silent.
  List<AudioLevel> get readings => List<AudioLevel>.generate(
    capacity,
    (i) => _ring[(_next + i) % capacity],
    growable: false,
  );
}

/// Calm scrolling level bars: newest reading on the right, rounded bars in
/// the primary colour, the error colour while clipping. Replaces the thin
/// level bar on the Record screen. Shows flat low bars when not [active].
class LiveWaveform extends ConsumerStatefulWidget {
  const LiveWaveform({required this.active, super.key});

  /// True while a recording is running; idle/paused show flat low bars.
  final bool active;

  @override
  ConsumerState<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends ConsumerState<LiveWaveform> {
  final _buffer = WaveformBuffer(AppSizes.waveformCapacity);

  @override
  void didUpdateWidget(LiveWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _buffer.clear();
  }

  @override
  void dispose() {
    _buffer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordingLevelsProvider, (_, next) {
      final level = next.value;
      if (level != null && widget.active) _buffer.add(level);
    });
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: Semantics(
            label: l10n.recordingLevelLabel,
            excludeSemantics: true,
            child: SizedBox(
              height: AppSizes.waveformHeight,
              child: CustomPaint(
                key: const ValueKey('waveform-paint'),
                painter: WaveformPainter(
                  buffer: _buffer,
                  color: scheme.primary,
                  clippingColor: scheme.error,
                  reduceMotion: MediaQuery.disableAnimationsOf(context),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: _buffer,
          builder: (context, _) => _buffer.latest.clipping
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.clippingHint,
                      key: const ValueKey('clipping-hint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Paints [WaveformBuffer] readings as centred rounded bars.
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.buffer,
    required this.color,
    required this.clippingColor,
    required this.reduceMotion,
  }) : super(repaint: buffer);

  final WaveformBuffer buffer;
  final Color color;
  final Color clippingColor;

  /// Static level bars (all at the latest level) instead of scrolling.
  final bool reduceMotion;

  /// How many bars fit in [width].
  static int barCount(double width) => math.max(
    0,
    ((width + AppSizes.waveformGap) /
            (AppSizes.waveformBar + AppSizes.waveformGap))
        .floor(),
  );

  /// The readings drawn for [count] bars, oldest first, newest at the right.
  List<AudioLevel> visibleLevels(int count) {
    if (reduceMotion) {
      return List<AudioLevel>.filled(count, buffer.latest);
    }
    final all = buffer.readings;
    final n = math.min(count, all.length);
    return all.sublist(all.length - n);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final count = barCount(size.width);
    if (count == 0) return;
    final levels = visibleLevels(count);
    const step = AppSizes.waveformBar + AppSizes.waveformGap;
    final used = count * step - AppSizes.waveformGap;
    final left = (size.width - used) / 2;
    const radius = Radius.circular(AppSizes.waveformBar / 2);
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      final height = math.max(
        AppSizes.waveformBar,
        level.normalized() * size.height,
      );
      final x = left + (count - levels.length + i) * step;
      final base = level.clipping ? clippingColor : color;
      final fade = levels.length <= 1 ? 1.0 : (i + 1) / levels.length;
      final alpha =
          AppSizes.waveformMinAlpha + (1 - AppSizes.waveformMinAlpha) * fade;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            (size.height - height) / 2,
            AppSizes.waveformBar,
            height,
          ),
          radius,
        ),
        Paint()
          ..color = i == levels.length - 1
              ? base
              : base.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.buffer != buffer ||
      old.color != color ||
      old.clippingColor != clippingColor ||
      old.reduceMotion != reduceMotion;
}
