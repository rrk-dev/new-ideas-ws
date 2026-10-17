import 'package:flutter/material.dart';
import 'package:vaultvoice/core/app_info.dart';

/// Lumen brand colours (APP-07). Mirrors `design/brand/README.md`; the
/// contrast of every foreground/background pair is covered by a test.
abstract final class LumenColors {
  static const teal = Color(0xFF0F766E);
  static const mint = Color(0xFF2DD4BF);
  static const paper = Color(0xFFF6F7F5);
  static const ink = Color(0xFF0F1715);
  static const mist = Color(0xFFF4F7F6);
  static const glow = Color(0xFFFFF4C9);
  static const lightText = Color(0xFF17211F);
  static const darkText = Color(0xFFE8EEEC);
}

/// The Lumen mark: five rounded voice bars and a small orb of light, drawn in
/// code from the same geometry as `design/brand/lumen-mark-*.svg`.
class LumenMark extends StatelessWidget {
  const LumenMark({this.size = 48, this.color, this.orbColor, super.key});

  final double size;

  /// Bar colour; defaults to teal (light theme) or mint (dark theme).
  final Color? color;
  final Color? orbColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bars = color ?? (dark ? LumenColors.mint : LumenColors.teal);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size * _LumenMarkPainter.aspect, size),
        painter: _LumenMarkPainter(
          bars,
          orbColor ?? (dark ? LumenColors.glow : bars),
        ),
      ),
    );
  }
}

class _LumenMarkPainter extends CustomPainter {
  const _LumenMarkPainter(this.bars, this.orb);

  static const _width = 644.0;
  static const _height = 560.0;
  static const double aspect = _width / _height;

  // x, y, height in the 1024 icon grid; bars are 76 wide with full radius.
  static const _bars = [
    (224.0, 460.0, 200.0),
    (349.0, 380.0, 360.0),
    (474.0, 310.0, 500.0),
    (599.0, 395.0, 330.0),
    (724.0, 465.0, 190.0),
  ];

  final Color bars;
  final Color orb;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / _width, size.height / _height)
      ..translate(-190, -250);
    final paint = Paint()
      ..color = bars
      ..isAntiAlias = true;
    for (final (x, y, h) in _bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 76, h),
          const Radius.circular(38),
        ),
        paint,
      );
    }
    canvas.drawCircle(const Offset(762, 290), 54, paint..color = orb);
  }

  @override
  bool shouldRepaint(_LumenMarkPainter old) =>
      old.bars != bars || old.orb != orb;
}

/// Mark plus the "Lumen" name, used on onboarding and in About.
class LumenWordmark extends StatelessWidget {
  const LumenWordmark({this.markSize = 40, super.key});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      label: kAppName,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LumenMark(size: markSize),
            SizedBox(width: markSize * 0.4),
            Text(
              kAppName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: markSize * 0.8,
                fontWeight: FontWeight.w300,
                letterSpacing: 1.5,
                color: dark ? LumenColors.darkText : LumenColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
