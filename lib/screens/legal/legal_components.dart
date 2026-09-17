import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../../theme/app_theme.dart';

/// Composants de mise en page partagés par les pages légales (CGU,
/// confidentialité, etc.). Ils reprennent la mise en page des pages légales web
/// (titres de section soulignés, grilles de cartes, encadrés d'information).

class LegalSectionTitle extends StatelessWidget {
  final String text;
  const LegalSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.teal100, width: 2),
          ),
        ),
        child: Text(
          text,
          style: AppFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class LegalBodyText extends StatelessWidget {
  final String text;
  const LegalBodyText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.manrope(
          fontSize: 14,
          color: AppTheme.textBody,
          height: 1.6,
        ),
      ),
    );
  }
}

class LegalBullet extends StatelessWidget {
  final String text;
  const LegalBullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: AppFonts.manrope(
              fontSize: 14,
              color: AppTheme.teal500,
              height: 1.6,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppFonts.manrope(
                fontSize: 14,
                color: AppTheme.textBody,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalInfo {
  final String label;
  final String desc;
  const LegalInfo(this.label, this.desc);
}

class LegalDataGrid extends StatelessWidget {
  final List<LegalInfo> items;
  const LegalDataGrid(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 40 - 12) / 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items
            .map((item) => SizedBox(width: width, child: LegalDataCard(item)))
            .toList(),
      ),
    );
  }
}

class LegalDataCard extends StatelessWidget {
  final LegalInfo info;
  const LegalDataCard(this.info, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.label,
            style: AppFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.desc,
            style: AppFonts.manrope(
              fontSize: 12,
              color: AppTheme.slate500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class LegalInfoBox extends StatelessWidget {
  final Widget child;
  const LegalInfoBox({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: child,
    );
  }
}

class LegalNoteBox extends StatelessWidget {
  final Widget child;
  final bool teal;
  const LegalNoteBox({required this.child, this.teal = false, super.key});

  @override
  Widget build(BuildContext context) {
    final bg = teal ? AppTheme.teal50 : AppTheme.amber50;
    final border = teal ? AppTheme.teal100 : AppTheme.amber200;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
