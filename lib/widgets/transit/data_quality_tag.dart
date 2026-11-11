// Étiquette obligatoire à côté de toute info transport :
// distingue une donnée réelle (GPS frais, horaire officiel) d'une estimation.
// Convention : jamais afficher une position/horaire sans un de ces tags.
import 'package:flutter/material.dart';

enum DataQuality { live, scheduled, estimated, unavailable }

class _TagStyle {
  final Color bg, fg, dot;
  final String label;
  const _TagStyle(this.bg, this.fg, this.dot, this.label);
}

const Map<DataQuality, _TagStyle> _styles = {
  DataQuality.live:        _TagStyle(Color(0xFFDCFCE7), Color(0xFF065F46), Color(0xFF10B981), 'Direct'),
  DataQuality.scheduled:   _TagStyle(Color(0xFFDBEAFE), Color(0xFF1E40AF), Color(0xFF3B82F6), 'Horaire'),
  DataQuality.estimated:   _TagStyle(Color(0xFFFEF3C7), Color(0xFF92400E), Color(0xFFF59E0B), 'Estimé'),
  DataQuality.unavailable: _TagStyle(Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFEF4444), 'Indisponible'),
};

class DataQualityTag extends StatefulWidget {
  final DataQuality quality;
  final String? label;
  final int? freshnessSeconds;
  const DataQualityTag({super.key, required this.quality, this.label, this.freshnessSeconds});

  @override
  State<DataQualityTag> createState() => _DataQualityTagState();
}

class _DataQualityTagState extends State<DataQualityTag> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  bool get _isLive => widget.quality == DataQuality.live;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    if (_isLive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant DataQualityTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La pulsation n'a de sens qu'en Direct : hors live on arrête le contrôleur
    // pour éviter de garder une frame planifiée en permanence (coûteux en CPU
    // et bloque pumpAndSettle dans les tests widgets).
    if (_isLive && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!_isLive && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final style = _styles[widget.quality]!;
    final text = widget.label
        ?? (widget.quality == DataQuality.live && widget.freshnessSeconds != null
              ? 'Direct · ${widget.freshnessSeconds}s'
              : style.label);
    final isLive = widget.quality == DataQuality.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = isLive ? _ctrl.value : 0.0;
              return Container(
                width: 8 + (isLive ? t * 6 : 0),
                height: 8 + (isLive ? t * 6 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: style.dot.withValues(alpha: isLive ? (1 - t) : 1),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: style.fg, fontWeight: FontWeight.w700, fontSize: 11,
              letterSpacing: 0.03, height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
