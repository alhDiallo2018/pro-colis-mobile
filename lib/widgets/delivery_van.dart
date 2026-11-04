import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Illustration animée d'une camionnette de livraison : va-et-vient latéral
/// + légère oscillation verticale. Utilisée sur les écrans d'auth / onboarding.
class DeliveryVan extends StatefulWidget {
  const DeliveryVan({
    super.key,
    this.height = 90,
    this.travel = 0.18,
    this.loopSeconds = 4,
  });

  /// Hauteur de la camionnette (la largeur suit le ratio 3:2).
  final double height;

  /// Amplitude du mouvement latéral, en fraction de la largeur disponible.
  final double travel;

  /// Durée d'un cycle complet (aller + retour), en secondes.
  final int loopSeconds;

  @override
  State<DeliveryVan> createState() => _DeliveryVanState();
}

class _DeliveryVanState extends State<DeliveryVan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.loopSeconds),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.height * 1.5;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value) * 2 - 1;
          final screenWidth = MediaQuery.sizeOf(context).width;
          final availableTravel =
              (screenWidth - width).clamp(0.0, double.infinity) * widget.travel;
          final dx = t * availableTravel;
          final dy = -2 + (1 - t.abs()) * 2;
          final tilt = -t * 0.015;
          return Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translateByDouble(dx, dy, 0, 1)
                ..rotateZ(tilt),
              child: SizedBox(
                height: widget.height,
                width: width,
                child: CustomPaint(
                  painter: _VanPainter(
                    wheelSpin: _controller.value * 2 * math.pi,
                    phase: _controller.value,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VanPainter extends CustomPainter {
  _VanPainter({required this.wheelSpin, required this.phase});

  final double wheelSpin;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    // Viewbox 120x80 — mêmes proportions que l'illustration web.
    final sx = size.width / 120;
    final sy = size.height / 80;

    double x(double v) => v * sx;
    double y(double v) => v * sy;

    final teal = AppTheme.teal500;
    final amber = AppTheme.amber400;
    final amberLight = AppTheme.amber200;

    // Ombre portée au sol.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x(60), y(72)), width: x(96), height: y(8)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Caisse cargo (rect arrondi teal).
    final cargoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x(10), y(20), x(60), y(42)),
      Radius.circular(x(6)),
    );
    canvas.drawRRect(cargoRect, Paint()..color = teal);

    // Reflet haut de la caisse.
    canvas.drawRRect(
      cargoRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x(10), y(20), x(60), y(42))),
    );

    // Séparation des portes arrière.
    canvas.drawLine(
      Offset(x(40), y(24)),
      Offset(x(40), y(58)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..strokeWidth = 1.2,
    );

    // Poignée de porte.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(38.5), y(40), x(3), y(6)),
        Radius.circular(x(1)),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );

    // Cabine (polygone ambre).
    final cabinPath = Path()
      ..moveTo(x(70), y(32))
      ..lineTo(x(88), y(32))
      ..quadraticBezierTo(x(94), y(32), x(97), y(37))
      ..lineTo(x(105), y(50))
      ..lineTo(x(105), y(62))
      ..quadraticBezierTo(x(105), y(64), x(103), y(64))
      ..lineTo(x(70), y(64))
      ..close();
    canvas.drawPath(cabinPath, Paint()..color = amber);

    // Reflet cabine.
    final cabinHighlightPath = Path()
      ..moveTo(x(70), y(32))
      ..lineTo(x(88), y(32))
      ..quadraticBezierTo(x(94), y(32), x(97), y(37))
      ..lineTo(x(105), y(50))
      ..lineTo(x(70), y(50))
      ..close();
    canvas.drawPath(
      cabinHighlightPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x(70), y(32), x(35), y(18))),
    );

    // Pare-brise.
    final windshieldPath = Path()
      ..moveTo(x(73), y(36))
      ..lineTo(x(87), y(36))
      ..quadraticBezierTo(x(91), y(36), x(93), y(39))
      ..lineTo(x(98), y(47))
      ..lineTo(x(75), y(47))
      ..close();
    canvas.drawPath(windshieldPath, Paint()..color = const Color(0xFFB8E3F0));
    canvas.drawPath(
      windshieldPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.65),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(x(73), y(36), x(25), y(11))),
    );

    // Fenêtre latérale.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(75), y(51), x(18), y(8)),
        Radius.circular(x(2)),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    // Phare avant.
    canvas.drawCircle(
      Offset(x(102), y(55)),
      x(2.5),
      Paint()..color = const Color(0xFFFFF8DC),
    );
    canvas.drawCircle(
      Offset(x(102), y(55)),
      x(1.5),
      Paint()..color = const Color(0xFFFFD700),
    );

    // Roues (tournent avec l'animation).
    _drawWheel(canvas, Offset(x(26), y(63)), x(10));
    _drawWheel(canvas, Offset(x(84), y(63)), x(10));

    // Swoosh ambre sur le flanc (logo discret).
    final swooshPath = Path()
      ..moveTo(x(18), y(34))
      ..quadraticBezierTo(x(24), y(30), x(32), y(32))
      ..quadraticBezierTo(x(40), y(34), x(46), y(30));
    canvas.drawPath(
      swooshPath,
      Paint()
        ..color = amberLight
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Lignes de vitesse décalées par la phase.
    final speedOpacity = (0.4 + 0.3 * phase).clamp(0.0, 1.0);
    final offset = (phase * 4) % 4;
    canvas.drawLine(
      Offset(x(2 - offset), y(40)),
      Offset(x(8 - offset), y(40)),
      Paint()
        ..color = amber.withValues(alpha: speedOpacity)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x(0 - offset * 0.6), y(48)),
      Offset(x(7 - offset * 0.6), y(48)),
      Paint()
        ..color = amber.withValues(alpha: speedOpacity * 0.6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Léger nuage d'échappement.
    canvas.drawCircle(
      Offset(x(-2 + phase * 2), y(58)),
      x(3),
      Paint()
        ..color = Colors.white
            .withValues(alpha: (0.3 + 0.2 * (1 - phase)).clamp(0.0, 0.5)),
    );
  }

  void _drawWheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF111717));
    canvas.drawCircle(center, radius - 1, Paint()..color = const Color(0xFF2A3838));
    canvas.drawCircle(center, radius * 0.4, Paint()..color = const Color(0xFFC4CFCF));
    canvas.drawCircle(center, radius * 0.15, Paint()..color = const Color(0xFF677474));
    // 3 rayons qui tournent pour matérialiser le roulement.
    final spokePaint = Paint()
      ..color = const Color(0xFF677474)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final angle = wheelSpin + (i * 2 * math.pi / 3);
      final dx = radius * 0.4 * math.cos(angle);
      final dy = radius * 0.4 * math.sin(angle);
      canvas.drawLine(center, Offset(center.dx + dx, center.dy + dy), spokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VanPainter oldDelegate) =>
      oldDelegate.wheelSpin != wheelSpin || oldDelegate.phase != phase;
}
