/// Thin-line vector illustrations for `DsEmptyState` and the style guide,
/// in the spirit of the real Club Sandwich logo mark — a simple
/// line-drawn character/note, not a filled icon. Hand-drawn as
/// `CustomPainter`s (no image assets), stroked at ~1.5-2px in a single
/// muted color so they read as a family rather than as decoration.
library;

import 'package:flutter/material.dart';

import '../tokens/ds_tokens.dart';

class DsEmptyBoxIllustration extends StatelessWidget {
  const DsEmptyBoxIllustration({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    return CustomPaint(
      painter: _EmptyBoxPainter(color ?? tokens.colors.border),
      child: const SizedBox.expand(),
    );
  }
}

class _EmptyBoxPainter extends CustomPainter {
  _EmptyBoxPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final top = h * 0.32;
    final bottom = h * 0.78;
    final left = w * 0.12;
    final right = w * 0.88;
    final midX = w / 2;

    final lid = Path()
      ..moveTo(left, top)
      ..lineTo(midX, h * 0.14)
      ..lineTo(right, top)
      ..lineTo(right * 0.86, top + h * 0.12)
      ..lineTo(w * 0.14, top + h * 0.12)
      ..close();
    canvas.drawPath(lid, paint);

    final box = Path()
      ..moveTo(w * 0.14, top + h * 0.12)
      ..lineTo(w * 0.18, bottom)
      ..lineTo(w * 0.82, bottom)
      ..lineTo(right * 0.86, top + h * 0.12);
    canvas.drawPath(box, paint);

    canvas.drawLine(
      Offset(midX - w * 0.08, top + h * 0.12),
      Offset(midX - w * 0.1, bottom * 0.62),
      paint,
    );
    canvas.drawLine(
      Offset(midX + w * 0.08, top + h * 0.12),
      Offset(midX + w * 0.1, bottom * 0.62),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _EmptyBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DsSearchIllustration extends StatelessWidget {
  const DsSearchIllustration({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    return CustomPaint(
      painter: _SearchPainter(color ?? tokens.colors.border),
      child: const SizedBox.expand(),
    );
  }
}

class _SearchPainter extends CustomPainter {
  _SearchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.44, size.height * 0.44);
    final radius = size.width * 0.26;

    canvas.drawCircle(center, radius, paint);

    final handleStart = center + Offset(radius * 0.72, radius * 0.72);
    final handleEnd = Offset(size.width * 0.86, size.height * 0.86);
    canvas.drawLine(handleStart, handleEnd, paint);

    // A few small "no result" sparkle dashes around the glass.
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.2),
      1.5,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.82),
      1.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DsAllDoneIllustration extends StatelessWidget {
  const DsAllDoneIllustration({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    return CustomPaint(
      painter: _AllDonePainter(color ?? tokens.colors.secondary),
      child: const SizedBox.expand(),
    );
  }
}

/// A stylized musical note, echoing the real logo's motif — for positive
/// "you're all caught up" empty states.
class _AllDonePainter extends CustomPainter {
  _AllDonePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final noteHeadCenter = Offset(size.width * 0.4, size.height * 0.72);
    final noteHeadRadius = size.width * 0.14;

    canvas.drawOval(
      Rect.fromCenter(
        center: noteHeadCenter,
        width: noteHeadRadius * 2.2,
        height: noteHeadRadius * 1.7,
      ),
      fill,
    );

    final stemTop = Offset(size.width * 0.52, size.height * 0.18);
    final stemBottom = Offset(size.width * 0.52, size.height * 0.72);
    canvas.drawLine(stemTop, stemBottom, stroke);

    final flag = Path()
      ..moveTo(stemTop.dx, stemTop.dy)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.3,
        size.width * 0.7,
        size.height * 0.5,
      );
    canvas.drawPath(flag, stroke);
  }

  @override
  bool shouldRepaint(covariant _AllDonePainter oldDelegate) =>
      oldDelegate.color != color;
}
