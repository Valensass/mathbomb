import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Full-screen detonation: flash, fireball, shockwave, sparks and debris.
class BombBurst extends StatelessWidget {
  const BombBurst({super.key, required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BurstPainter(t.clamp(0.0, 1.0)),
        size: Size.infinite,
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final maxR = size.width * 0.9;

    // Initial white flash.
    final flash = (1 - t * 2.4).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * flash),
      );
    }

    final ease = 1 - math.pow(1 - t, 3).toDouble();

    // Fireball.
    final fireR = maxR * 0.55 * ease;
    if (fireR > 1) {
      canvas.drawCircle(
        center,
        fireR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: (0.9 * (1 - t)).clamp(0, 1)),
              AppColors.amber.withValues(alpha: (0.85 * (1 - t)).clamp(0, 1)),
              AppColors.red.withValues(alpha: (0.6 * (1 - t)).clamp(0, 1)),
              Colors.transparent,
            ],
            stops: const [0, 0.25, 0.6, 1],
          ).createShader(Rect.fromCircle(center: center, radius: fireR)),
      );
    }

    // Shockwave rings.
    for (final lag in [0.0, 0.12]) {
      final rt = ((t - lag) / (1 - lag)).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final r = maxR * (1 - math.pow(1 - rt, 2)).toDouble();
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 * (1 - rt) + 0.5
          ..color = Colors.white.withValues(alpha: 0.35 * (1 - rt)),
      );
      canvas.drawCircle(
        center,
        r * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - rt) + 0.4
          ..color = AppColors.amber.withValues(alpha: 0.3 * (1 - rt)),
      );
    }

    // Sparks.
    final rng = math.Random(42);
    for (var i = 0; i < 64; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 0.35 + rng.nextDouble() * 0.95;
      final dist = maxR * speed * ease;
      final p = center +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.92);
      final alpha = (1 - t) * (0.5 + rng.nextDouble() * 0.5);
      final color = i % 4 == 0 ? Colors.white : AppColors.amber;
      canvas.drawCircle(
        p,
        (2.5 + rng.nextDouble() * 3.5) * (1 - t) + 0.4,
        Paint()..color = color.withValues(alpha: alpha.clamp(0, 1)),
      );
    }

    // Debris shards.
    for (var i = 0; i < 14; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = maxR * (0.5 + rng.nextDouble() * 0.5) * ease;
      final p = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + t * 8);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: 6 + rng.nextDouble() * 8,
          height: 2 + rng.nextDouble() * 3,
        ),
        Paint()
          ..color = const Color(0xFF1A2228)
              .withValues(alpha: (1 - t).clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class FlashOverlay extends StatelessWidget {
  const FlashOverlay({super.key, required this.t, this.color = AppColors.red});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Starts and ends fully transparent so an idle overlay cannot tint the UI.
    final opacity = math.sin(t.clamp(0.0, 1.0) * math.pi) * 0.30;
    return IgnorePointer(
      child: ColoredBox(color: color.withValues(alpha: opacity)),
    );
  }
}

/// A quick "+points" floating label.
class ScorePop extends StatelessWidget {
  const ScorePop({
    super.key,
    required this.points,
    required this.t,
    this.color = AppColors.amber,
  });

  final int points;
  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -50 * t),
          child: Text(
            '+$points',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.8), blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
