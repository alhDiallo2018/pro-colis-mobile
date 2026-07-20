import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../theme/app_theme.dart';

class PcStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final void Function(int step)? onStepTapped;

  const PcStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels = const [],
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isCompleted = index < currentStep;
        final label = index < stepLabels.length ? stepLabels[index] : '';
        return Expanded(
          child: GestureDetector(
            onTap: onStepTapped != null ? () => onStepTapped!(index) : null,
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? AppTheme.primary : AppTheme.slate200,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppTheme.primary : AppTheme.slate200,
                      ),
                      alignment: Alignment.center,
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: AppFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive ? Colors.white : AppTheme.slate400,
                              ),
                            ),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: AppFonts.manrope(
                          fontSize: 10,
                          color: isActive ? AppTheme.textPrimary : AppTheme.slate400,
                        ),
                      ),
                    ],
                  ],
                ),
                if (index < totalSteps - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? AppTheme.primary : AppTheme.slate200,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class PcTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const PcTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.cardColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  boxShadow: selected
                      ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.textPrimary : AppTheme.slate500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PcPanel extends StatefulWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  const PcPanel({
    super.key,
    required this.title,
    this.icon,
    this.children = const [],
    this.initiallyExpanded = true,
  });

  @override
  State<PcPanel> createState() => _PcPanelState();
}

class _PcPanelState extends State<PcPanel> with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _rotation = Tween<double>(begin: 0.0, end: 0.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (_expanded) _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 20, color: AppTheme.primary),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                  RotationTransition(
                    turns: _rotation,
                    child: Icon(Icons.keyboard_arrow_down, color: AppTheme.slate400, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class PcPlaceholder extends StatelessWidget {
  final int lines;
  final double? width;

  const PcPlaceholder({super.key, this.lines = 3, this.width});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (i) {
        final w = i == lines - 1 && width == null ? 0.6 : 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          width: (width ?? MediaQuery.of(context).size.width - 48) * w,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.slate200,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
