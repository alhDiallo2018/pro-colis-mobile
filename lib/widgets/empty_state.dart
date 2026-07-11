import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color? tone;
  final Widget? action;
  final double iconSize;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox,
    required this.title,
    this.message,
    this.tone,
    this.action,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final baseTone = tone ?? AppTheme.slate500;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize * 1.4,
              height: iconSize * 1.4,
              decoration: BoxDecoration(
                color: baseTone.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: baseTone),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
