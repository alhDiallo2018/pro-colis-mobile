import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PcBarChart extends StatelessWidget {
  final List<double> bars;
  final List<String>? labels;
  final double height;
  final bool highlightLast;

  const PcBarChart({
    super.key,
    required this.bars,
    this.labels,
    this.height = 90,
    this.highlightLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final max = bars.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return SizedBox(height: height);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bars.length, (i) {
              final isLast = i == bars.length - 1;
              final useAmber = highlightLast && isLast;
              final pct = ((bars[i] / (max == 0 ? 1 : max)) * 100).clamp(4, 100);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: isLast ? 0 : 4),
                  child: Container(
                    height: pct / 100 * height,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                      gradient: useAmber
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppTheme.teal400, AppTheme.teal600],
                            ),
                      color: useAmber ? AppTheme.amber400 : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels!.map((l) {
              return SizedBox(
                width: 24,
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: AppTheme.mono(fontSize: 10.5, color: AppTheme.slate400, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
