import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Illustration animée d'une camionnette en roulage : la caisse oscille
/// légèrement sur sa suspension, les roues tournent en continu vers l'avant,
/// les lignes de vitesse fuient vers l'arrière, et quelques colis dansent
/// au-dessus de la cargo. Pas d'aller-retour : le mouvement est toujours
/// progressif pour rester naturel.
class DeliveryVan extends StatefulWidget {
  const DeliveryVan({
    super.key,
    this.height = 90,
    this.loopSeconds = 3,
  });

  final double height;

  /// Durée d'un cycle complet de l'animation (roues, suspension, colis).
  final int loopSeconds;

  @override
  State<DeliveryVan> createState() => _DeliveryVanState();
}

class _DeliveryVanState extends State<DeliveryVan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.loopSeconds),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage système « réduire les animations » (accessibilité) —
    // également vrai dans les tests widgets, ce qui permet à pumpAndSettle de
    // converger sur les écrans d'auth où cette illustration est présente.
    final disabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!disabled && !_animating) {
      _controller.repeat();
      _animating = true;
    } else if (disabled && _animating) {
      _controller.stop();
      _animating = false;
    }
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
          final phase = _controller.value;
          // Suspension : sinusoïde symétrique → la caisse monte/descend
          // doucement sans à-coup. Deux oscillations par cycle pour simuler
          // les cahots d'une route.
          final bounce = math.sin(phase * 2 * math.pi * 2) * 1.3;
          // Micro-tangage avant/arrière, lié à la suspension.
          final tilt = math.sin(phase * 2 * math.pi * 2 + 0.4) * 0.012;
          return Center(
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0, bounce, 0, 1)
                ..rotateZ(tilt),
              child: SizedBox(
                height: widget.height,
                width: width,
                child: CustomPaint(
                  painter: _VanPainter(phase: phase),
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
  _VanPainter({required this.phase});

  /// Progression linéaire 0 → 1 → 0 → 1 …
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

    // Lignes de vitesse qui fuient vers l'arrière (gauche) en continu.
    _paintSpeedLines(canvas, x, y, amber);

    // Ombre portée au sol — légère pulsation avec la suspension.
    final shadowSquish = 1 + math.sin(phase * 2 * math.pi * 2) * 0.05;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(x(60), y(72)),
          width: x(96) * shadowSquish,
          height: y(8)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Colis qui dansent au-dessus de la cargo.
    _paintParcels(canvas, x, y, amber, teal);

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

    // Phare avant avec léger halo pulsé.
    final halo = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi * 2));
    canvas.drawCircle(
      Offset(x(102), y(55)),
      x(3.5),
      Paint()..color = const Color(0xFFFFF8DC).withValues(alpha: halo * 0.35),
    );
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

    // Roues (tournent toujours vers l'avant avec l'animation).
    final wheelSpin = phase * 2 * math.pi;
    _drawWheel(canvas, Offset(x(26), y(63)), x(10), wheelSpin);
    _drawWheel(canvas, Offset(x(84), y(63)), x(10), wheelSpin);

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

    // Petit nuage d'échappement qui s'éloigne puis se dissipe.
    final exhaustProgress = phase; // 0 → 1
    canvas.drawCircle(
      Offset(x(-2 - exhaustProgress * 10), y(58 - exhaustProgress * 4)),
      x(2 + exhaustProgress * 2),
      Paint()
        ..color = Colors.white
            .withValues(alpha: (0.35 * (1 - exhaustProgress)).clamp(0.0, 0.4)),
    );
  }

  void _paintSpeedLines(Canvas canvas, double Function(double) x,
      double Function(double) y, Color amber) {
    // Trois lignes qui défilent vers la gauche (relativement au véhicule qui
    // avance vers la droite). Chaque ligne a sa propre vitesse pour éviter le
    // défilement « rideau » uniforme.
    const lines = [
      (yPos: 40.0, span: 10.0, speed: 1.6, opacity: 0.55),
      (yPos: 48.0, span: 8.0, speed: 1.2, opacity: 0.40),
      (yPos: 56.0, span: 12.0, speed: 2.0, opacity: 0.30),
    ];
    for (final line in lines) {
      // On fait défiler une bande de longueur `period` = span + gap.
      const period = 24.0;
      final shift = (phase * period * line.speed) % period;
      // Trois répétitions suffisent à couvrir la largeur devant la camionnette.
      for (var i = -1; i <= 2; i++) {
        final startX = i * period - shift;
        canvas.drawLine(
          Offset(x(startX), y(line.yPos)),
          Offset(x(startX + line.span), y(line.yPos)),
          Paint()
            ..color = amber.withValues(alpha: line.opacity)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintParcels(Canvas canvas, double Function(double) x,
      double Function(double) y, Color amber, Color teal) {
    // Trois colis qui bobbent au-dessus de la cargo avec un déphasage pour un
    // effet de vague. Chacun a une légère rotation pour sembler vivant sans
    // devenir agité.
    final parcels = [
      _ParcelSpec(cx: 22, baseY: 14, size: 7, phaseOffset: 0.0, tint: amber),
      _ParcelSpec(
          cx: 36, baseY: 11, size: 8, phaseOffset: 0.33, tint: Colors.white),
      _ParcelSpec(
          cx: 52, baseY: 14, size: 7, phaseOffset: 0.66, tint: amber),
    ];
    for (final p in parcels) {
      final t = (phase + p.phaseOffset) % 1.0;
      // Bob vertical (sinusoïde) + micro-rotation.
      final bob = math.sin(t * 2 * math.pi) * 1.5;
      final rot = math.sin(t * 2 * math.pi + math.pi / 6) * 0.12;
      final cx = x(p.cx);
      final cy = y(p.baseY) + bob;
      final half = x(p.size) / 2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      // Ombre sous le colis.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, half + 2), width: half * 1.6, height: 1.5),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      // Corps du colis.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
          Radius.circular(x(1.2)),
        ),
        Paint()..color = p.tint,
      );
      // Rubans en croix.
      final ribbonPaint = Paint()
        ..color = teal.withValues(alpha: 0.65)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(-half, 0), Offset(half, 0), ribbonPaint);
      canvas.drawLine(Offset(0, -half), Offset(0, half), ribbonPaint);
      canvas.restore();
    }
  }

  void _drawWheel(Canvas canvas, Offset center, double radius, double spin) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF111717));
    canvas.drawCircle(
        center, radius - 1, Paint()..color = const Color(0xFF2A3838));
    canvas.drawCircle(
        center, radius * 0.4, Paint()..color = const Color(0xFFC4CFCF));
    canvas.drawCircle(
        center, radius * 0.15, Paint()..color = const Color(0xFF677474));
    // 3 rayons qui tournent pour matérialiser le roulement vers l'avant.
    final spokePaint = Paint()
      ..color = const Color(0xFF677474)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final angle = spin + (i * 2 * math.pi / 3);
      final dx = radius * 0.4 * math.cos(angle);
      final dy = radius * 0.4 * math.sin(angle);
      canvas.drawLine(center, Offset(center.dx + dx, center.dy + dy), spokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VanPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _ParcelSpec {
  const _ParcelSpec({
    required this.cx,
    required this.baseY,
    required this.size,
    required this.phaseOffset,
    required this.tint,
  });
  final double cx;
  final double baseY;
  final double size;
  final double phaseOffset;
  final Color tint;
}
