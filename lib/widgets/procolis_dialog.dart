import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ProcolisDialogIconTone { primary, danger, green, amber }

class ProcolisDialog extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final IconData? icon;
  final ProcolisDialogIconTone? iconTone;
  final String title;
  final Widget? content;
  final List<Widget>? actions;

  const ProcolisDialog({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.icon,
    this.iconTone,
    required this.title,
    this.content,
    this.actions,
  });

  @override
  State<ProcolisDialog> createState() => _ProcolisDialogState();
}

class _ProcolisDialogState extends State<ProcolisDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
      value: widget.isOpen ? 1 : 0,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(covariant ProcolisDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      if (widget.isOpen) {
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

  Color _iconToneColor() {
    switch (widget.iconTone) {
      case ProcolisDialogIconTone.primary:
        return AppTheme.primary;
      case ProcolisDialogIconTone.danger:
        return AppTheme.errorColor;
      case ProcolisDialogIconTone.green:
        return AppTheme.successColor;
      case ProcolisDialogIconTone.amber:
        return AppTheme.warningColor;
    }
  }

  Color _iconToneBackground() {
    switch (widget.iconTone) {
      case ProcolisDialogIconTone.primary:
        return AppTheme.teal50;
      case ProcolisDialogIconTone.danger:
        return AppTheme.red50;
      case ProcolisDialogIconTone.green:
        return AppTheme.green50;
      case ProcolisDialogIconTone.amber:
        return AppTheme.amber50;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen && _controller.value == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withOpacity( 0.4 * _fadeAnimation.value),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: 380,
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 48,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity( 0.16),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          if (widget.icon != null) ...[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _iconToneBackground(),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                widget.icon,
                                color: _iconToneColor(),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (widget.content != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: DefaultTextStyle(
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!,
                                textAlign: TextAlign.center,
                                child: widget.content!,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (widget.actions != null &&
                              widget.actions!.isNotEmpty) ...[
                            const Divider(height: 1, color: AppTheme.slate200),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              child: Row(
                                children: widget.actions!
                                    .map(
                                      (action) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: action,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProcolisDialogActions extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool primaryLoading;
  final bool primaryDestructive;

  const ProcolisDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLoading = false,
    this.primaryDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (secondaryLabel != null)
          Expanded(
            child: OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.slate300),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: Text(
                secondaryLabel!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
              ),
            ),
          ),
        if (secondaryLabel != null) const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: primaryLoading ? null : onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryDestructive
                  ? AppTheme.errorColor
                  : AppTheme.primary,
              disabledBackgroundColor: AppTheme.slate200,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: primaryLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    primaryLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}
