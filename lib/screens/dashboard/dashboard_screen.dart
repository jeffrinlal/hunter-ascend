import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

// ── Shield Rank Badge Painter ──────────────────────────────────────────────

/// Draws the rank shield badge behind a hunter's rank letter.
class RankShieldPainter extends CustomPainter {
  final String rank; // "E", "D", "C", "B", "A", "S"

  RankShieldPainter(this.rank);

  Color get _shieldFill {
    switch (rank) {
      case 'S': return HunterTheme.amberSurface;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.background;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.background; // E
    }
  }

  Color get _strokeColor {
    switch (rank) {
      case 'S': return HunterTheme.goldDeep;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.border;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.border; // E
    }
  }

  Color get _letterColor {
    switch (rank) {
      case 'S': return HunterTheme.gold;
      case 'A': return HunterTheme.danger;
      case 'B': return HunterTheme.primary;
      case 'C': return HunterTheme.primary;
      case 'D': return HunterTheme.success;
      default:  return HunterTheme.textSecondary; // E
    }
  }


  Color get _innerStroke {
    switch (rank) {
      case 'S': return HunterTheme.goldDark;
      case 'A': return HunterTheme.redSurface;
      case 'B': return HunterTheme.amberSurface;
      case 'C': return HunterTheme.border;
      case 'D': return HunterTheme.greenSurface;
      default:  return HunterTheme.border; // E
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield outer path
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.5, h * 0.04);
    shieldPath.lineTo(w * 0.91, h * 0.17);
    shieldPath.lineTo(w * 0.91, h * 0.51);
    shieldPath.quadraticBezierTo(w * 0.91, h * 0.78, w * 0.5, h * 0.97);
    shieldPath.quadraticBezierTo(w * 0.09, h * 0.78, w * 0.09, h * 0.51);
    shieldPath.lineTo(w * 0.09, h * 0.17);
    shieldPath.close();

    // Fill shield
    canvas.drawPath(shieldPath, Paint()..color = _shieldFill);

    // Outer border
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = rank == 'S' || rank == 'A' ? 2.0 : 1.5,
    );

    // Inner shield bevel
    final innerPath = Path();
    innerPath.moveTo(w * 0.5, h * 0.11);
    innerPath.lineTo(w * 0.83, h * 0.23);
    innerPath.lineTo(w * 0.83, h * 0.51);
    innerPath.quadraticBezierTo(w * 0.83, h * 0.73, w * 0.5, h * 0.89);
    innerPath.quadraticBezierTo(w * 0.17, h * 0.73, w * 0.17, h * 0.51);
    innerPath.lineTo(w * 0.17, h * 0.23);
    innerPath.close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = _innerStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Top horizontal line
    _drawLine(canvas, w * 0.28, h * 0.28, w * 0.72, h * 0.28, _strokeColor, 0.8);

    // Side vertical lines (D rank and above)
    if (rank != 'E') {
      _drawLine(canvas, w * 0.21, h * 0.36, w * 0.21, h * 0.67, _strokeColor, 1.5);
      _drawLine(canvas, w * 0.79, h * 0.36, w * 0.79, h * 0.67, _strokeColor, 1.5);
    }

    // Bottom line (A, S)
    if (rank == 'A' || rank == 'S') {
      _drawLine(canvas, w * 0.28, h * 0.75, w * 0.72, h * 0.75, _strokeColor, 0.8);
    }


    // Corner rivets
    _drawRivet(canvas, w * 0.22, h * 0.21, _strokeColor, rank == 'S' || rank == 'A' ? 3.0 : 2.5);
    _drawRivet(canvas, w * 0.78, h * 0.21, _strokeColor, rank == 'S' || rank == 'A' ? 3.0 : 2.5);

    // Wing curls (B, A, S)
    if (rank == 'B' || rank == 'A' || rank == 'S') {
      final wingPaint = Paint()
        ..color = _strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = rank == 'S' ? 1.5 : 1.2
        ..strokeCap = StrokeCap.round;
      final leftWing = Path();
      leftWing.moveTo(w * 0.21, h * 0.46);
      leftWing.quadraticBezierTo(w * 0.1, h * 0.51, w * 0.21, h * 0.58);
      canvas.drawPath(leftWing, wingPaint);
      final rightWing = Path();
      rightWing.moveTo(w * 0.79, h * 0.46);
      rightWing.quadraticBezierTo(w * 0.9, h * 0.51, w * 0.79, h * 0.58);
      canvas.drawPath(rightWing, wingPaint);
    }

    // Star accent (C rank)
    if (rank == 'C') {
      _drawStar(canvas, w * 0.5, h * 0.19, 5, _strokeColor, filled: true);
    }

    // Crown (A, S)
    if (rank == 'A' || rank == 'S') {
      _drawCrown(canvas, w, h);
    }

    // Gold jewel dots on crown (S only)
    if (rank == 'S') {
      _drawRivet(canvas, w * 0.37, h * 0.105, _letterColor, 2.0);
      _drawRivet(canvas, w * 0.5,  h * 0.16,  _letterColor, 2.0);
      _drawRivet(canvas, w * 0.63, h * 0.105, _letterColor, 2.0);
    }

    // Rank letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: rank,
        style: TextStyle(
          color: _letterColor,
          fontSize: w * 0.42,
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((w - textPainter.width) / 2, h * 0.42),
    );
  }


  void _drawLine(Canvas canvas, double x1, double y1, double x2, double y2, Color color, double width) {
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()..color = color..strokeWidth = width,
    );
  }

  void _drawRivet(Canvas canvas, double cx, double cy, Color color, double r) {
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, double cx, double cy, int points, Color color, {bool filled = false}) {
    final outerR = 6.0;
    final innerR = 3.0;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = filled ? PaintingStyle.fill : PaintingStyle.stroke);
  }

  void _drawCrown(Canvas canvas, double w, double h) {
    final crownPaint = Paint()
      ..color = _strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = rank == 'S' ? 1.8 : 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final crown = Path();
    crown.moveTo(w * 0.32, h * 0.17);
    crown.lineTo(w * 0.37, h * 0.10);
    crown.lineTo(w * 0.50, h * 0.16);
    crown.lineTo(w * 0.63, h * 0.10);
    crown.lineTo(w * 0.68, h * 0.17);
    canvas.drawPath(crown, crownPaint);
  }

  @override
  bool shouldRepaint(RankShieldPainter old) => old.rank != rank;
}


// ── Shield Widget ──────────────────────────────────────────────────────────

/// Compact rank-shield badge widget (wraps [RankShieldPainter]).
class RankShieldBadge extends StatelessWidget {
  final String rankLetter;
  final double size;

  const RankShieldBadge({super.key, required this.rankLetter, this.size = 58});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.18),
      painter: RankShieldPainter(rankLetter),
    );
  }
}
