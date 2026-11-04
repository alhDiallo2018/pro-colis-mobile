// Pastille Citymapper-style : couleur-opérateur + numéro de ligne.
// Équivalent mobile du <LineBadge /> côté web.
import 'package:flutter/material.dart';

enum TransitOperator { ddd, aftu }

enum TransitDirection { aller, retour }

class LineBadgeStyle {
  final Color background;
  final Color foreground;
  final String label;
  const LineBadgeStyle(this.background, this.foreground, this.label);
}

const LineBadgeStyle _dddStyle = LineBadgeStyle(Color(0xFFE85D04), Colors.white, 'DDD');
const LineBadgeStyle _aftuStyle = LineBadgeStyle(Color(0xFF1D4ED8), Colors.white, 'AFTU');

LineBadgeStyle styleFor(TransitOperator op) =>
    op == TransitOperator.ddd ? _dddStyle : _aftuStyle;

enum LineBadgeSize { sm, md, lg }

class LineBadge extends StatelessWidget {
  final TransitOperator operator;
  final String number;
  final LineBadgeSize size;
  const LineBadge({super.key, required this.operator, required this.number, this.size = LineBadgeSize.md});

  @override
  Widget build(BuildContext context) {
    final style = styleFor(operator);
    final metrics = switch (size) {
      LineBadgeSize.sm => _Metrics(minWidth: 32, height: 28, fontSize: 13, radius: 8, horizontalPad: 8),
      LineBadgeSize.md => _Metrics(minWidth: 44, height: 40, fontSize: 17, radius: 10, horizontalPad: 12),
      LineBadgeSize.lg => _Metrics(minWidth: 56, height: 52, fontSize: 22, radius: 12, horizontalPad: 14),
    };
    return Container(
      constraints: BoxConstraints(minWidth: metrics.minWidth),
      height: metrics.height,
      padding: EdgeInsets.symmetric(horizontal: metrics.horizontalPad),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(metrics.radius),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: TextStyle(
          color: style.foreground,
          fontWeight: FontWeight.w800,
          fontSize: metrics.fontSize,
          letterSpacing: 0.01,
        ),
      ),
    );
  }
}

class _Metrics {
  final double minWidth, height, fontSize, radius, horizontalPad;
  const _Metrics({
    required this.minWidth, required this.height,
    required this.fontSize, required this.radius, required this.horizontalPad,
  });
}
