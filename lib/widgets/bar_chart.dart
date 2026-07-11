import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BarChart extends StatelessWidget {
  final List<double> bars;
  final List<String>? labels;
  final double height;
  final bool highlightLast;

  const BarChart({
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
              final isAmber = highlightLast && isLast;
              final ratio = ((bars[i] / max) * 100).clamp(4, 100);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: double.infinity,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: '${ratio}%',
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(5)),
                        gradient: isAmber
                            ? const LinearGradient(
                                colors: [AppTheme.amber400, AppTheme.amber500],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : LinearGradient(
                                colors: [
                                  AppTheme.teal400.withOpacity(0.55 +
                                      (i / (bars.length > 1 ? bars.length : 1)) *
                                          0.45),
                                  AppTheme.teal600.withOpacity(0.55 +
                                      (i / (bars.length > 1 ? bars.length : 1)) *
                                          0.45),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                      ),
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
            children: labels!
                .map((l) => Expanded(
                      child: Text(
                        l,
                        textAlign: TextAlign.center,
                        style: AppTheme.mono(
                          fontSize: 10.5,
                          color: AppTheme.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
