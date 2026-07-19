import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ReclamationsPage extends StatelessWidget {
  const ReclamationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Réclamations'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Comment déposer une réclamation'),
          const SizedBox(height: 12),
          _bodyText(
            'Vous pouvez déposer une réclamation via les canaux suivants :',
          ),
          _bodyText(
            '• Directement depuis l\'application : Menu > Support > Réclamations.',
          ),
          _bodyText('• Par email : support-commercial@sendprocolis.com.'),
          _bodyText(
            '• Par téléphone : via le chat support dans l\'application.',
          ),
          _bodyText(
            'Nous vous recommandons d\'utiliser l\'application pour un traitement '
            'plus rapide et un meilleur suivi.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Informations à fournir'),
          const SizedBox(height: 12),
          _bodyText(
            'Pour un traitement efficace, votre réclamation doit inclure :',
          ),
          _bodyText('• Le numéro de suivi du colis concerné.'),
          _bodyText('• La date de l\'envoi ou de l\'incident.'),
          _bodyText('• Une description claire et précise du problème.'),
          _bodyText(
            '• Des photos du colis endommagé (si applicable).',
          ),
          _bodyText(
            '• Les captures d\'écran des échanges avec le chauffeur (si utile).',
          ),
          _bodyText(
            '• Le montant réclamé le cas échéant.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Délais de traitement'),
          const SizedBox(height: 12),
          _bodyText('Accusé de réception : sous 24 heures ouvrées.'),
          _bodyText(
            'Réclamation simple (retard, contact) : 48 heures ouvrées.',
          ),
          _bodyText(
            'Réclamation complexe (perte, avarie, litige) : 5 jours ouvrés.',
          ),
          _bodyText(
            'Les délais peuvent être prolongés si l\'enquête nécessite des '
            'informations complémentaires ou l\'intervention de tiers.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Types de réclamations'),
          const SizedBox(height: 12),
          _subsectionTitle('Retard de livraison'),
          _bodyText(
            'Signalez un retard supérieur au délai annoncé par le chauffeur. '
            'Notre équipe contacte le chauffeur et vous informe de la nouvelle '
            'estimation.',
          ),
          _subsectionTitle('Colis endommagé'),
          _bodyText(
            'Si le colis arrive endommagé, refusez la livraison ou signalez-le '
            'immédiatement avec des photos. La réclamation doit être déposée dans '
            'les 48 heures.',
          ),
          _subsectionTitle('Colis perdu'),
          _bodyText(
            'Si le colis est déclaré perdu par le chauffeur ou si le suivi '
            'n\'évolue plus depuis 48 heures, déposez une réclamation. Une enquête '
            'est ouverte immédiatement.',
          ),
          _subsectionTitle('Litige avec un chauffeur'),
          _bodyText(
            'Comportement inapproprié, non-respect des conditions, ou tout autre '
            'différend avec le chauffeur.',
          ),
          _subsectionTitle('Problème de paiement'),
          _bodyText(
            'Débit non autorisé, montant incorrect, problème de retrait wallet.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Escalade et médiation'),
          const SizedBox(height: 12),
          _bodyText(
            'Si la réponse apportée ne vous satisfait pas, vous pouvez :',
          ),
          _bodyText(
            '• Demander une réévaluation de votre dossier par un responsable.',
          ),
          _bodyText(
            '• Saisir le service médiation de ProColis.',
          ),
          _bodyText(
            '• En dernier recours, saisir les autorités compétentes '
            '(tribunaux de Dakar).',
          ),
          _bodyText(
            'ProColis s\'engage à traiter toutes les réclamations avec '
            'impartialité et transparence.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Suivi de votre réclamation'),
          const SizedBox(height: 12),
          _bodyText(
            'Chaque réclamation reçoit un numéro unique de suivi. Vous pouvez '
            'consulter l\'état d\'avancement de votre dossier à tout moment dans '
            'l\'application, section « Mes réclamations ».',
          ),
          _bodyText(
            'Vous recevrez des notifications à chaque étape du traitement.',
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
        style: GoogleFonts.plusJakartaSans(
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
        style: GoogleFonts.manrope(
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
