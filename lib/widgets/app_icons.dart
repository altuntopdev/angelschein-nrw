import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

extension CategoryAccent on ExamCategory {
  Color get accentColor => AppColors.categoryAccents[ExamCategory.values.indexOf(this)];
}

/// Small stroke-based category icons drawn on a 24x24 design grid,
/// matching the "Derin Su" visual direction (no icon-font glyphs).
class CategoryIconPainter extends CustomPainter {
  final ExamCategory category;
  final Color color;
  final double strokeWidth;

  CategoryIconPainter({required this.category, required this.color, this.strokeWidth = 1.8});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (category) {
      case ExamCategory.allgemeineFischkunde:
        _fishBody(canvas, stroke);
        canvas.drawCircle(const Offset(7, 11), 0.9, fill);
      case ExamCategory.spezielleFischkunde:
        final body = Path()
          ..moveTo(3, 12)
          ..cubicTo(5.5, 8.5, 10, 6.5, 14, 6.5)
          ..cubicTo(16.5, 6.5, 18.5, 8.5, 20.5, 12)
          ..cubicTo(18.5, 15.5, 16.5, 17.5, 14, 17.5)
          ..cubicTo(10, 17.5, 5.5, 15.5, 3, 12)
          ..close();
        canvas.drawPath(body, stroke);
        final arc = Path()..moveTo(9, 9.2)..cubicTo(9.8, 9.9, 10.2, 10.9, 10.2, 12)..cubicTo(10.2, 13.1, 9.8, 14.1, 9, 14.8);
        canvas.drawPath(arc, stroke);
        canvas.drawCircle(const Offset(6.5, 11), 0.9, fill);
      case ExamCategory.gewaesserkundeUndFischhege:
        final drop = Path()
          ..moveTo(12, 3)
          ..cubicTo(15.5, 7.5, 18, 11, 18, 14)
          ..arcToPoint(const Offset(6, 14), radius: const Radius.circular(6))
          ..cubicTo(6, 11, 8.5, 7.5, 12, 3)
          ..close();
        canvas.drawPath(drop, stroke);
        final highlight = Path()..moveTo(8.6, 14.6)..cubicTo(8.6, 16, 9.7, 17, 11, 17.2);
        canvas.drawPath(highlight, stroke);
      case ExamCategory.naturUndTierschutz:
        final leaf = Path()
          ..moveTo(5, 19)
          ..cubicTo(5, 12, 10, 6, 19, 5)
          ..cubicTo(18, 14, 12, 19, 5, 19)
          ..close();
        canvas.drawPath(leaf, stroke);
        canvas.drawLine(const Offset(6.3, 17.7), const Offset(15.3, 6.7), stroke);
      case ExamCategory.geraetekunde:
        canvas.drawLine(const Offset(4, 20), const Offset(18, 5), stroke);
        canvas.drawLine(const Offset(18, 5), const Offset(19.6, 3.4), stroke);
        canvas.drawCircle(const Offset(15, 9), 2, stroke);
        final hook = Path()..moveTo(4, 20)..cubicTo(2.8, 20.6, 2.4, 22, 3.2, 23)..cubicTo(4, 24, 5.4, 23.7, 5.8, 22.5);
        canvas.drawPath(hook, stroke);
      case ExamCategory.gesetzeskunde:
        canvas.drawLine(const Offset(12, 3), const Offset(12, 21), stroke);
        canvas.drawLine(const Offset(5, 7), const Offset(19, 7), stroke);
        canvas.drawLine(const Offset(9, 21), const Offset(15, 21), stroke);
        final leftPan = Path()..moveTo(5, 7)..lineTo(2.5, 12)..arcToPoint(const Offset(7.5, 12), radius: const Radius.circular(3))..close();
        canvas.drawPath(leftPan, stroke);
        final rightPan = Path()..moveTo(19, 7)..lineTo(16.5, 12)..arcToPoint(const Offset(21.5, 12), radius: const Radius.circular(3))..close();
        canvas.drawPath(rightPan, stroke);
    }

    canvas.restore();
  }

  void _fishBody(Canvas canvas, Paint stroke) {
    final body = Path()
      ..moveTo(2, 12)
      ..cubicTo(5, 8, 10, 6, 15, 6)
      ..cubicTo(18, 6, 20, 8, 22, 12)
      ..cubicTo(20, 16, 18, 18, 15, 18)
      ..cubicTo(10, 18, 5, 16, 2, 12)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawLine(const Offset(15, 9), const Offset(18, 6), stroke);
    canvas.drawLine(const Offset(15, 15), const Offset(18, 18), stroke);
  }

  @override
  bool shouldRepaint(covariant CategoryIconPainter oldDelegate) =>
      oldDelegate.category != category || oldDelegate.color != color;
}

class CategoryIcon extends StatelessWidget {
  final ExamCategory category;
  final Color color;
  final double size;

  const CategoryIcon({super.key, required this.category, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: CategoryIconPainter(category: category, color: color),
    );
  }
}

/// The friendly geometric fish mascot used on the onboarding screen.
class FishMascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 118, size.height / 90);

    final body = Paint()..color = const Color(0xFFFFC94D);
    final finPaint = Paint()..color = const Color(0xFFFF9F43);
    final eyePaint = Paint()..color = const Color(0xFF0B3D57);
    final highlightPaint = Paint()..color = Colors.white;
    final mouthPaint = Paint()
      ..color = const Color(0xFF0B3D57)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(Rect.fromCenter(center: const Offset(52, 45), width: 92, height: 68), body);

    final tail = Path()..moveTo(96, 45)..lineTo(118, 22)..lineTo(118, 68)..close();
    canvas.drawPath(tail, finPaint);

    final topFin = Path()
      ..moveTo(40, 16)
      ..cubicTo(50, 4, 66, 4, 72, 14)
      ..cubicTo(62, 18, 48, 18, 40, 16)
      ..close();
    canvas.drawPath(topFin, finPaint);

    canvas.drawCircle(const Offset(34, 40), 7, eyePaint);
    canvas.drawCircle(const Offset(36, 38), 2.2, highlightPaint);

    final mouth = Path()..moveTo(18, 52)..quadraticBezierTo(30, 62, 44, 54);
    canvas.drawPath(mouth, mouthPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FishMascotPainter oldDelegate) => false;
}

class FishMascot extends StatelessWidget {
  final double width;
  final double height;
  const FishMascot({super.key, this.width = 118, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: FishMascotPainter());
  }
}
