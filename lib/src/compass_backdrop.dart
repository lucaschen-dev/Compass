import 'package:material_ui/material_ui.dart';

class CompassBackdrop extends StatelessWidget {
  const CompassBackdrop({super.key, required this.child})
    : schoolColor = null,
      _atTop = false;

  const CompassBackdrop.school({
    super.key,
    required this.child,
    this.schoolColor,
  }) : _atTop = true;

  final Widget child;
  final int? schoolColor;
  final bool _atTop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomPaint(
      painter: _WavePainter(
        accent: compassSchoolAccent(theme, schoolColor),
        dark: theme.brightness == Brightness.dark,
        atTop: _atTop,
      ),
      child: child,
    );
  }
}

Color compassSchoolAccent(ThemeData theme, int? schoolColor) {
  if (schoolColor == null) return theme.colorScheme.primary;
  final accent = Color(0xff000000 | schoolColor);
  final dark = theme.brightness == Brightness.dark;
  return Color.lerp(accent, theme.colorScheme.onSurface, dark ? .30 : .18)!;
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.accent,
    required this.dark,
    required this.atTop,
  });

  final Color accent;
  final bool dark;
  final bool atTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final width = size.width;
    final height = atTop
        ? (size.height * .23).clamp(80.0, 180.0)
        : (size.height * .32).clamp(100.0, 290.0);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (atTop) {
      canvas.translate(0, height);
      canvas.scale(1, -1);
    } else {
      canvas.translate(0, size.height - height);
    }

    final bounds = Rect.fromLTWH(0, 0, width, height);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(
            alpha: atTop ? (dark ? .085 : .05) : (dark ? .16 : .085),
          ),
        ],
      ).createShader(bounds);
    final wave = _contour(width, height, 0)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(wave, fill);

    final strength = atTop ? (dark ? .13 : .085) : (dark ? .19 : .14);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: strength),
          accent.withValues(alpha: 0),
        ],
        stops: const [0, .60, 1],
      ).createShader(bounds);
    canvas
      ..drawPath(_contour(width, height, 0), stroke)
      ..drawPath(_contour(width, height, height * .16), stroke)
      ..restore();
  }

  Path _contour(double width, double height, double offset) => Path()
    ..moveTo(0, height * .46 + offset)
    ..cubicTo(
      width * .20,
      height * .52 + offset,
      width * .31,
      height * .88 + offset,
      width * .57,
      height * .59 + offset,
    )
    ..cubicTo(
      width * .76,
      height * .38 + offset,
      width * .83,
      height * .24 + offset,
      width,
      height * .30 + offset,
    );

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      accent != oldDelegate.accent ||
      dark != oldDelegate.dark ||
      atTop != oldDelegate.atTop;
}
