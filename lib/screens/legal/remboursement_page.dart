import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../../theme/app_theme.dart';

class RemboursementPage extends StatelessWidget {
  const RemboursementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Annulation & remboursement'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Annulation avant acceptation'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'expéditeur peut annuler gratuitement une annonce de colis à '
            'tout moment, tant qu\'aucun chauffeur n\'a accepté le transport.',
          ),
          _bodyText(
            'Aucun frais n\'est appliqué. Le montant éventuellement débité est '
            'intégralement recrédité sur le wallet.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Annulation après acceptation par le chauffeur'),
          const SizedBox(height: 12),
          _subsectionTitle('Annulation par l\'expéditeur'),
          _bodyText(
            'Si l\'expéditeur annule après acceptation par un chauffeur mais '
            'avant la prise en charge du colis, des frais d\'annulation de 10% '
            'du montant du transport sont retenus (minimum 500 FCFA).',
          ),
          _bodyText(
            'Ces frais compensent le temps et le déplacement du chauffeur.',
          ),
          _subsectionTitle('Annulation par le chauffeur'),
          _bodyText(
            'Si le chauffeur annule après acceptation, l\'expéditeur est '
            'intégralement remboursé. Le chauffeur peut voir son score de '
            'réputation impacté.',
          ),
          _bodyText(
            'En cas de force majeure (panne, accident), le chauffeur doit '
            'fournir un justificatif pour éviter la pénalité.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Conditions de remboursement'),
          const SizedBox(height: 12),
          _bodyText(
            'Un remboursement intégral est accordé dans les cas suivants :',
          ),
          _bodyText('• Annulation par le chauffeur après acceptation.'),
          _bodyText('• Non-respect du délai de livraison de plus de 24h.'),
          _bodyText(
            '• Perte du colis confirmée après enquête.',
          ),
          _bodyText('• Colis livré avec avarie majeure (colis détruit).'),
          _bodyText(
            '• Non-conformité du service (chauffeur différent de celui annoncé).',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Colis perdu ou endommagé'),
          const SizedBox(height: 12),
          _bodyText(
            'En cas de perte confirmée du colis, l\'expéditeur est remboursé du '
            'montant de la prestation et peut prétendre à une indemnisation '
            'plafonnée à la valeur déclarée, dans la limite de 500 000 FCFA.',
          ),
          _bodyText(
            'Une assurance complémentaire peut être souscrite au moment de la '
            'publication du colis pour une couverture étendue.',
          ),
          _bodyText(
            'En cas d\'avarie partielle, une indemnisation proportionnelle '
            'aux dommages est proposée après expertise.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Délais de remboursement'),
          const SizedBox(height: 12),
          _bodyText(
            'Remboursement automatique (annulation simple) : instantané, '
            'le montant est recrédité immédiatement sur votre wallet.',
          ),
          _bodyText(
            'Remboursement après litige (perte, avarie) : 5 à 10 jours '
            'ouvrés après validation du dossier par notre équipe.',
          ),
          _bodyText(
            'Le remboursement est effectué sur le wallet ProColis. Le retrait '
            'vers un compte externe suit les délais habituels de retrait.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Cas de non-remboursement'),
          const SizedBox(height: 12),
          _bodyText(
            'Aucun remboursement n\'est accordé dans les cas suivants :',
          ),
          _bodyText(
            '• Colis livré et réceptionné avec code PIN valide.',
          ),
          _bodyText(
            '• Refus de réception par le destinataire sans motif légitime.',
          ),
          _bodyText(
            '• Informations de livraison erronées fournies par l\'expéditeur.',
          ),
          _bodyText(
            '• Colis interdit découvert après prise en charge.',
          ),
          _bodyText(
            '• Emballage manifestement insuffisant ayant causé l\'avarie.',
          ),
          _bodyText(
            '• Réclamation déposée plus de 48h après la livraison.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('7. Procédure de remboursement'),
          const SizedBox(height: 12),
          _bodyText(
            'Pour demander un remboursement :',
          ),
          _bodyText(
            '1. Accédez à la section Réclamations dans l\'application.',
          ),
          _bodyText(
            '2. Sélectionnez le colis concerné et décrivez le problème.',
          ),
          _bodyText(
            '3. Joignez les justificatifs nécessaires (photos, captures d\'écran).',
          ),
          _bodyText(
            '4. Notre équipe examine votre demande sous 5 jours ouvrés.',
          ),
          _bodyText(
            '5. Vous recevez une notification avec la décision et le montant '
            'remboursé le cas échéant.',
          ),
          const SizedBox(height: 32),
          _bodyText('Dernière mise à jour : juillet 2026.'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: AppFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary,
        ),
      ),
    );

Widget _bodyText(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppFonts.manrope(
          fontSize: 14,
          color: AppTheme.textSecondary,
          height: 1.6,
        ),
      ),
    );

Widget _subsectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: AppFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
