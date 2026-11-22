import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// The bomb casing with a live screen and a burning fuse.
class BombDevice extends StatefulWidget {
  const BombDevice({
    super.key,
    required this.prompt,
    required this.fuseFraction,
    required this.tier,
    required this.modulesCut,
    required this.modulesTotal,
    this.danger = false,
    this.reduceMotion = false,
    this.dimmed = false,
  });

  final String prompt;
  final double fuseFraction;
  final int tier;
  final int modulesCut;
  final int modulesTotal;
  final bool danger;
  final bool reduceMotion;
  final bool dimmed;

  @override
  State<BombDevice> createState() => _BombDeviceState();
}

class _BombDeviceState extends State<BombDevice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.red : AppColors.amber;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: widget.dimmed ? 0.4 : 1,
      child: SizedBox(
        height: 218,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 360.0);
            return Center(
              child: SizedBox(
                width: width,
                height: 218,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Fuse + spark, painted behind/around the casing.
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _flicker,
                        builder: (context, _) => CustomPaint(
                          painter: _FusePainter(
                            fraction: widget.fuseFraction.clamp(0.0, 1.0),
                            flicker: widget.reduceMotion ? 0.5 : _flicker.value,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 26,
                      height: 178,
                      child: _Casing(
                        prompt: widget.prompt,
                        tier: widget.tier,
                        modulesCut: widget.modulesCut,
                        modulesTotal: widget.modulesTotal,
                        danger: widget.danger,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Casing extends StatelessWidget {
  const _Casing({
    required this.prompt,
    required this.tier,
    required this.modulesCut,
    required this.modulesTotal,
    required this.danger,
  });

  final String prompt;
  final int tier;
  final int modulesCut;
  final int modulesTotal;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.red : AppColors.amber;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C3B47), Color(0xFF121B22), Color(0xFF0A1116)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(
          color: Color.lerp(const Color(0xFF4C616F), accent, 0.18)!,
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: accent.withValues(alpha: danger ? 0.30 : 0.14),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          children: [
            // Hazard strip along the top.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 16,
              child: CustomPaint(painter: _HazardPainter()),
            ),
            // Screws.
            for (final pos in const [
              Offset(7, 32),
              Offset(7, 148),
            ])
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: const _Screw(),
              ),
            for (final pos in const [
              Offset(7, 32),
              Offset(7, 148),
            ])
              Positioned(
                right: pos.dx,
                top: pos.dy,
                child: const _Screw(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'DETONATOR',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          color: AppColors.muted.withValues(alpha: 0.85),
                        ),
                      ),
                      const Spacer(),
                      _Led(active: true, color: accent),
                      const SizedBox(width: 4),
                      _Led(active: danger, color: AppColors.red),
                      const SizedBox(width: 4),
                      _Led(active: false, color: AppColors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF04120D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.10),
                            blurRadius: 18,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ScreenGrainPainter(color: accent),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  prompt,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 38,
                                    height: 1.05,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: accent,
                                    shadows: [
                                      Shadow(
                                        color: accent.withValues(alpha: 0.75),
                                        blurRadius: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'TIER $tier',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                      const Spacer(),
                      for (var i = 0; i < modulesTotal; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < modulesCut
                                  ? AppColors.green
                                  : AppColors.line,
                              boxShadow: i < modulesCut
                                  ? [
                                      BoxShadow(
                                        color: AppColors.green.withValues(
                                          alpha: 0.6,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Screw extends StatelessWidget {
  const _Screw();

  @override
  Widget build(BuildContext context) {
    const size = 7.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF6E8492), Color(0xFF2A3740)],
        ),
        border: Border.all(color: const Color(0xFF0A1015), width: 0.8),
      ),
      child: Center(
        child: Container(
          width: size * 0.55,
          height: 1,
          color: const Color(0xFF0B1217),
        ),
      ),
    );
  }
}

class _Led extends StatelessWidget {
  const _Led({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withValues(alpha: 0.18),
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 7)]
            : null,
      ),
    );
  }
}

class _HazardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF171F25),
    );
    final stripe = Paint()..color = AppColors.amber.withValues(alpha: 0.75);
    const step = 14.0;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + step / 2, size.height)
        ..lineTo(x + step / 2 + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, stripe);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_HazardPainter oldDelegate) => false;
}

class _ScreenGrainPainter extends CustomPainter {
  _ScreenGrainPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.35),
          ],
          stops: const [0.6, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ScreenGrainPainter old) => old.color != color;
}

class _FusePainter extends CustomPainter {
  _FusePainter({
    required this.fraction,
    required this.flicker,
    required this.color,
  });

  final double fraction;
  final double flicker;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.70, 34);
    final end = Offset(size.width - 10, 6);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * 0.80,
        14,
        size.width * 0.86,
        2,
        end.dx,
        end.dy,
      );
    final metric = path.computeMetrics().first;
    final length = metric.length;
    final remaining = (length * fraction).clamp(2.0, length);

    // Burnt tail (from the device to the spark): charred.
    canvas.drawPath(
      metric.extractPath(0, length - remaining),
      Paint()
        ..color = const Color(0xFF1C2226)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    // Live fuse.
    canvas.drawPath(
      metric.extractPath(0, remaining),
      Paint()
        ..color = const Color(0xFFB78B5C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );

    final sparkAt = metric.getTangentForOffset(remaining)?.position ?? start;
    final pulse = 0.7 + 0.3 * math.sin(flicker * math.pi * 2);
    canvas.drawCircle(
      sparkAt,
      10 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            color,
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: sparkAt, radius: 10 * pulse)),
    );
    // Micro sparks.
    final rng = math.Random(11);
    for (var i = 0; i < 5; i++) {
      final a = rng.nextDouble() * math.pi * 2 + flicker * 6;
      final d = 4 + rng.nextDouble() * 9;
      canvas.drawCircle(
        sparkAt + Offset(math.cos(a) * d, math.sin(a) * d),
        1.1,
        Paint()..color = color.withValues(alpha: 0.5 + rng.nextDouble() * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(_FusePainter old) =>
      old.fraction != fraction || old.flicker != flicker;
}
