import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SegmentedControl extends StatefulWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<SegmentedControl> createState() => _SegmentedControlState();
}

class _SegmentedControlState extends State<SegmentedControl> {
  final GlobalKey _containerKey = GlobalKey();
  final Map<int, GlobalKey> _segmentKeys = {};
  Offset _indicatorOffset = Offset.zero;
  double _indicatorWidth = 0;
  bool _firstBuild = true;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.options.length; i++) {
      _segmentKeys[i] = GlobalKey();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateIndicator(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant SegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _updateIndicator();
    }
    if (oldWidget.options.length != widget.options.length) {
      for (var i = 0; i < widget.options.length; i++) {
        if (!_segmentKeys.containsKey(i)) {
          _segmentKeys[i] = GlobalKey();
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateIndicator(animate: false);
      });
    }
  }

  void _updateIndicator({bool animate = true}) {
    final containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final segmentBox = _segmentKeys[widget.selectedIndex]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (containerBox == null || segmentBox == null) return;

    final containerPos = containerBox.localToGlobal(Offset.zero);
    final segmentPos = segmentBox.localToGlobal(Offset.zero);

    final horizontalPadding = 4.0;

    if (animate) {
      setState(() {
        _indicatorOffset = Offset(
          segmentPos.dx - containerPos.dx - horizontalPadding,
          0,
        );
        _indicatorWidth = segmentBox.size.width + horizontalPadding * 2;
        _firstBuild = false;
      });
    } else {
      _indicatorOffset = Offset(
        segmentPos.dx - containerPos.dx - horizontalPadding,
        0,
      );
      _indicatorWidth = segmentBox.size.width + horizontalPadding * 2;
      _firstBuild = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _containerKey,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            left: _firstBuild ? null : _indicatorOffset.dx,
            top: 3,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              width: _firstBuild ? 0 : _indicatorWidth,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: AppTheme.brandShadow(),
              ),
            ),
          ),
          Row(
            children: List.generate(widget.options.length, (index) {
              final isSelected = index == widget.selectedIndex;
              return Expanded(
                child: GestureDetector(
                  key: _segmentKeys[index],
                  onTap: () {
                    if (!isSelected) {
                      widget.onChanged(index);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        widget.options[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
