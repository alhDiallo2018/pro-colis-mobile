// lib/widgets/form_draft_ui.dart
//
// Éléments d'interface partagés par les formulaires qui gèrent un brouillon :
// le bandeau de reprise affiché à la réouverture, et la confirmation présentée
// quand l'utilisateur quitte une saisie non publiée.

import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Ce que l'utilisateur a décidé en quittant un formulaire renseigné.
enum DraftExitChoice { cancel, keep, discard }

const List<String> _months = [
  'jan',
  'fév',
  'mar',
  'avr',
  'mai',
  'juin',
  'juil',
  'août',
  'sep',
  'oct',
  'nov',
  'déc'
];

/// « aujourd'hui 14:32 », « hier 09:05 », sinon « 28 juil · 18:40 ».
String formatDraftTimestamp(DateTime savedAt) {
  final now = DateTime.now();
  final hh = savedAt.hour.toString().padLeft(2, '0');
  final mm = savedAt.minute.toString().padLeft(2, '0');

  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(savedAt.year, savedAt.month, savedAt.day);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'aujourd’hui $hh:$mm';
  if (diff == 1) return 'hier $hh:$mm';
  return '${savedAt.day} ${_months[savedAt.month - 1]} · $hh:$mm';
}

/// Bandeau proposant de reprendre une saisie interrompue.
class DraftRestoreBanner extends StatelessWidget {
  const DraftRestoreBanner({
    super.key,
    required this.savedAt,
    required this.onRestore,
    required this.onDiscard,
  });

  final DateTime savedAt;
  final VoidCallback onRestore;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.amber50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.amber600.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppTheme.amber600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reprendre votre saisie ?',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.amber600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              'Brouillon enregistré ${formatDraftTimestamp(savedAt)}.',
              style: AppFonts.manrope(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PcButton(
                  'Reprendre',
                  icon: Icons.restore_rounded,
                  size: PcButtonSize.sm,
                  block: true,
                  onPressed: onRestore,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PcButton(
                  'Repartir à zéro',
                  variant: PcButtonVariant.secondary,
                  size: PcButtonSize.sm,
                  block: true,
                  onPressed: onDiscard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirmation présentée quand on quitte un formulaire renseigné.
///
/// Renvoie `null` si la boîte est fermée sans choisir, ce que l'appelant doit
/// traiter comme [DraftExitChoice.cancel] — le cas le moins destructeur.
Future<DraftExitChoice?> showDraftExitDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<DraftExitChoice>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      icon: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          color: AppTheme.amber50,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.save_outlined, size: 26, color: AppTheme.amber600),
      ),
      title: Text(
        'Quitter le formulaire ?',
        textAlign: TextAlign.center,
        style: AppFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: AppFonts.manrope(
          fontSize: 13.5,
          color: AppTheme.textSecondary,
          height: 1.45,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      actions: [
        Column(
          children: [
            PcButton(
              'Garder le brouillon',
              icon: Icons.check_rounded,
              size: PcButtonSize.md,
              block: true,
              onPressed: () =>
                  Navigator.pop(dialogContext, DraftExitChoice.keep),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Annuler',
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.md,
                    block: true,
                    onPressed: () =>
                        Navigator.pop(dialogContext, DraftExitChoice.cancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PcButton(
                    'Supprimer',
                    variant: PcButtonVariant.danger,
                    size: PcButtonSize.md,
                    block: true,
                    onPressed: () =>
                        Navigator.pop(dialogContext, DraftExitChoice.discard),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
