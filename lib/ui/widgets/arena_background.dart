import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Industrial arena: perspective grid, drifting embers, scanlines, vignette.
class ArenaBackground extends StatefulWidget {
  const ArenaBackground({
    super.key,
    required this.child,
    this.danger = false,
    this.reduceMotion = false,
  });

  final Widget child;
  final bool danger;
  final bool reduceMotion;

  @override
  State<ArenaBackground> createState() => _ArenaBackgroundState();
}

class _ArenaBackgroundState extends State<ArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            return CustomPaint(
              painter: _ArenaPainter(
                t: widget.reduceMotion ? 0.15 : _c.value,
                danger: widget.danger,
                reduceMotion: widget.reduceMotion,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

class _ArenaPainter extends CustomPainter {
  _ArenaPainter({
    required this.t,
    required this.danger,
    required this.reduceMotion,
  });

  final double t;
  final bool danger;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = danger ? AppColors.red : AppColors.amber;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A141C), AppColors.bg, AppColors.bgDeep],
          stops: [0, 0.45, 1],
        ).createShader(rect),
    );

    // Overhead glow behind the bomb.
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.30),
      size.width * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: danger ? 0.16 : 0.10),
            Colors.transparent,
          ],
          stops: const [0, 1],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.30),
            radius: size.width * 0.62,
          ),
        ),
    );

    _drawGrid(canvas, size);
    _drawEmbers(canvas, size);
    _drawScanlines(canvas, size);

    // Vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
          stops: const [0.55, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Corner tick marks.
    final tick = Paint()
      ..color = glow.withValues(alpha: 0.28)
      ..strokeWidth = 1.5;
    const m = 18.0;
    const l = 16.0;
    for (final p in [
      Offset(m, m),
      Offset(size.width - m, m),
      Offset(m, size.height - m),
      Offset(size.width - m, size.height - m),
    ]) {
      final sx = p.dx < size.width / 2 ? 1.0 : -1.0;
      final sy = p.dy < size.height / 2 ? 1.0 : -1.0;
      canvas.drawLine(p, p.translate(l * sx, 0), tick);
      canvas.drawLine(p, p.translate(0, l * sy), tick);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final horizon = size.height * 0.56;
    final paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.055)
      ..strokeWidth = 1.0;

    // Horizontal perspective lines.
    for (var i = 1; i <= 14; i++) {
      final p = i / 14;
      final y = horizon + math.pow(p, 1.9) * (size.height - horizon);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Converging verticals.
    final vanish = Offset(size.width / 2, horizon - 40);
    for (var i = -8; i <= 8; i++) {
      final x = size.width / 2 + i * size.width * 0.12;
      canvas.drawLine(vanish, Offset(x, size.height), paint);
    }
    // Horizon line.
    canvas.drawLine(
      Offset(0, horizon),
      Offset(size.width, horizon),
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );
  }

  void _drawEmbers(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 26; i++) {
      final baseX = rng.nextDouble();
      final phase = rng.nextDouble();
      final drift = (phase + t * (reduceMotion ? 0 : 1)) % 1;
      final y = size.height * (1 - drift);
      final x =
          size.width * baseX + math.sin((drift + phase) * math.pi * 2) * 14;
      final alpha = (0.10 + rng.nextDouble() * 0.22) *
          (0.4 + 0.6 * (1 - drift));
      paint.color = (i % 3 == 0 ? AppColors.amber : AppColors.cyan)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.9 + rng.nextDouble() * 1.5, paint);
    }
    if (reduceMotion) return;
    // Slow rising ember sparks at the bottom.
    for (var i = 0; i < 6; i++) {
      final p = (t * 2 + i / 6) % 1;
      final x = size.width * (0.2 + 0.12 * i) +
          math.sin(p * math.pi * 4 + i) * 10;
      final y = size.height * (1.05 - p * 0.5);
      canvas.drawCircle(
        Offset(x, y),
        1.4,
        Paint()..color = AppColors.amber.withValues(alpha: 0.5 * (1 - p)),
      );
    }
  }

  void _drawScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ArenaPainter old) =>
      old.t != t || old.danger != danger;
}
