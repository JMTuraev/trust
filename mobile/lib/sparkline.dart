// Sparkline — prototype/bosh-ekran.dc.html «4-tur» freymlaridagi SVG'ning aynan porti.
//
// Prototip uni uch qatlamda chizadi:
//   1) to'ldirilgan path (`... L{last},46 L0,46 Z`) — rang 12% dan 0% gacha so'nadi;
//   2) ustidan stroke path (`C` — kubik bezier, round cap/join, 2.0–2.2px);
//   3) oxirgi nuqtada to'la doira (hero r=3.5, kichik karta r=3).
// Misol (4a hero): M0,33 C22,32 44,31 66,31.5 … C262,15.5 288,11 310,8
//
// Rang qoidasi: kirim -> Pal.green, chiqim -> Pal.red. Boshqa rang ishlatilmaydi
// (rangni chaqiruvchi beradi — bu fayl theme'ga bog'lanmaydi).
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Qayta ishlatiladigan sparkline: qiymatlar ro'yxati + rang.
/// Balandlikni chaqiruvchi beradi (prototip: hero 46px, kichik karta 30px).
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double stroke; // prototip: hero 2.2, kichik karta 2.0
  final double dot; // prototip: hero r=3.5, kichik karta r=3
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.stroke = 2.2,
    this.dot = 3.5,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        painter: SparkPainter(values: values, color: color, stroke: stroke, dot: dot),
      );
}

class SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double stroke;
  final double dot;
  const SparkPainter({
    required this.values,
    required this.color,
    this.stroke = 2.2,
    this.dot = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    // Xavfsizlik: NaN/Infinity kirsa ham chizuv yiqilmasin
    final vs = <double>[for (final v in values) v.isFinite ? v : 0.0];
    if (vs.isEmpty) return; // 0 nuqta — hech narsa chizilmaydi

    // Chekka bo'shliq: oxirgi nuqta doirasi va stroke qirqilib qolmasin.
    // Prototipda ham shunday: viewBox eni 320 bo'lsa-da oxirgi nuqta x=310 da.
    final pad = dot + stroke / 2;
    const left = 0.0;
    final right = math.max(left, w - pad);
    final top = math.min(pad, h / 2);
    final bottom = math.max(top, h - pad);

    var lo = vs.first, hi = vs.first;
    for (final v in vs) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final range = hi - lo;

    Offset pt(int i) {
      final x = vs.length == 1 ? right : left + (right - left) * (i / (vs.length - 1));
      // Barcha qiymat teng (range == 0) — o'rtada tekis chiziq, NaN yo'q
      final t = range <= 0 ? 0.5 : (vs[i] - lo) / range;
      return Offset(x, bottom - (bottom - top) * t);
    }

    final pts = <Offset>[for (var i = 0; i < vs.length; i++) pt(i)];
    final last = pts.last;

    // 1 nuqta — chiziq yo'q, faqat oxirgi nuqta doirasi qoladi
    if (pts.length >= 2) {
      // Silliq egri: Catmull-Rom -> kubik bezier (siniq polyline EMAS)
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 0; i < pts.length - 1; i++) {
        final p0 = pts[i == 0 ? 0 : i - 1];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[i + 2 < pts.length ? i + 2 : pts.length - 1];
        final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
        final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
        line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }

      // 1) Ostidagi to'ldirish — prototipdagidek pastki qirg'oqqacha yopiladi
      final area = Path.from(line)
        ..lineTo(last.dx, h)
        ..lineTo(pts.first.dx, h)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .12), color.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );

      // 2) Chiziqning o'zi
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 3) Oxirgi nuqta
    canvas.drawCircle(last, dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SparkPainter old) =>
      old.color != color ||
      old.stroke != stroke ||
      old.dot != dot ||
      !listEquals(old.values, values);
}

/// Bo'sh holat («Bo'sh holat» freymi): sparkline o'rnidagi nuqtali «kutish» chizig'i.
/// Prototip: M0,22 C60,21.5 120,21 180,21 C240,21 280,21 320,20.5 —
/// stroke-width 2, stroke-dasharray "1 7", rang var(--pt6) (Pal.t6).
class SparkDots extends StatelessWidget {
  final Color color;
  const SparkDots({super.key, required this.color});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: SparkDotsPainter(color));
}

class SparkDotsPainter extends CustomPainter {
  final Color color;
  const SparkDotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    // Prototipdagi viewBox 0 0 320 30 da chiziq y≈22 -> balandlikning 22/30 ulushi
    final y = h * 22 / 30;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // dasharray "1 7": 1px chiziq (round cap bilan nuqtaga aylanadi) + 7px bo'shliq
    for (var x = 0.0; x < w; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 1, w), y), paint);
    }
  }

  @override
  bool shouldRepaint(SparkDotsPainter old) => old.color != color;
}
