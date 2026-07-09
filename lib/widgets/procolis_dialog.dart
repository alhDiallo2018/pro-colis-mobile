import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ProcolisDialogIconTone { primary, danger, green, amber }

class ProcolisDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    final tone = iconTone ?? ProcolisDialogIconTone.primary;
    Color iconBg;
    Color iconFg;
    switch (tone) {
      case ProcolisDialogIconTone.danger:
        iconBg = AppTheme.red50;
        iconFg = AppTheme.red400;
        break;
      case ProcolisDialogIconTone.green:
        iconBg = AppTheme.green50;
        iconFg = AppTheme.green600;
        break;
      case ProcolisDialogIconTone.amber:
        iconBg = AppTheme.amber50;
        iconFg = AppTheme.amber500;
        break;
      case ProcolisDialogIconTone.primary:
        iconBg = AppTheme.primaryLight;
        iconFg = AppTheme.primary;
        break;
    }

    return Material(
      color: const Color(0x730A3A43),
      child: Center(
        child: GestureDetector(
          onTap: onClose,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B464F).withOpacity(0.14),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 28, color: iconFg),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (content != null) ...[
                        const SizedBox(height: 12),
                        content!,
                      ],
                      if (actions != null) ...[
                        const SizedBox(height: 22),
                        ...actions!,
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
  }
}

class ProcolisDialogActions extends StatelessWidget {
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool destructive;

  const ProcolisDialogActions({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    this.onSecondary,
    this.onPrimary,
    this.primaryLoading = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: primaryLoading ? null : onSecondary,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.slate300),
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Text(secondaryLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: primaryLoading ? null : onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? AppTheme.red400 : AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: primaryLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}
