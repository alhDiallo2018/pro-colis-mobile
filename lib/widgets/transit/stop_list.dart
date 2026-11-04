// Liste verticale d'arrêts Transit/Citymapper :
// pastille numérotée + segment reliant chaque arrêt au suivant,
// avec mise en avant optionnelle de l'arrêt courant.
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum StopTone { origin, destination, current, defaultTone, pending }

class StopListItem {
  final String key;
  final String label;
  final Widget? meta;
  final StopTone tone;
  final VoidCallback? onTap;
  const StopListItem({
    required this.key,
    required this.label,
    this.meta,
    this.tone = StopTone.defaultTone,
    this.onTap,
  });
}

class StopList extends StatelessWidget {
  final List<StopListItem> items;
  final int? currentIndex;
  final Color? color;
  final bool compact;
  const StopList({super.key, required this.items, this.currentIndex, this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final rail = color ?? AppTheme.teal500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          _StopRow(
            item: items[i],
            isFirst: i == 0,
            isLast: i == items.length - 1,
            isCurrent: currentIndex == i,
            passed: currentIndex != null && i < currentIndex!,
            rail: rail,
            compact: compact,
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  final StopListItem item;
  final bool isFirst, isLast, isCurrent, passed, compact;
  final Color rail;
  const _StopRow({
    required this.item,
    required this.isFirst, required this.isLast,
    required this.isCurrent, required this.passed,
    required this.rail, required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final dotFilled = item.tone == StopTone.origin
        || item.tone == StopTone.destination
        || isCurrent
        || passed;
    final boldLabel = isFirst || isLast || isCurrent;
    final contentPadding = EdgeInsets.symmetric(vertical: compact ? 4 : 8);
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: contentPadding,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    // segment haut
                    Expanded(child: Container(
                      width: 2,
                      color: isFirst ? Colors.transparent : (passed || isCurrent ? rail : rail.withValues(alpha: 0.2)),
                    )),
                    // pastille
                    Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotFilled ? rail : Colors.white,
                        border: Border.all(color: rail, width: 2),
                        boxShadow: isCurrent ? [BoxShadow(color: rail.withValues(alpha: 0.25), blurRadius: 0, spreadRadius: 3)] : null,
                      ),
                    ),
                    // segment bas
                    Expanded(child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : (passed ? rail : rail.withValues(alpha: 0.2)),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: boldLabel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: compact ? 13 : 15,
                          color: isCurrent ? Colors.black : AppTheme.textBody,
                        ),
                      ),
                      if (item.tone == StopTone.pending)
                        Text('position estimée',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
              if (item.meta != null) Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: item.meta,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
