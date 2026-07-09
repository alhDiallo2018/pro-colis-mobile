import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProcolisSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  const ProcolisSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
  });

  @override
  State<ProcolisSwitch> createState() => _ProcolisSwitchState();
}

class _ProcolisSwitchState extends State<ProcolisSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(ProcolisSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = ColorTween(
      begin: AppTheme.slate300,
      end: AppTheme.primary,
    ).animate(_controller);

    final thumbPos = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(_controller);

    final toggle = GestureDetector(
      onTap: () {
        if (widget.onChanged != null) {
          widget.onChanged!(!widget.value);
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: trackColor.value,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Align(
              alignment: thumbPos.value,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.label == null) return toggle;

    return InkWell(
      onTap: () {
        if (widget.onChanged != null) {
          widget.onChanged!(!widget.value);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            toggle,
          ],
        ),
      ),
    );
  }
}
