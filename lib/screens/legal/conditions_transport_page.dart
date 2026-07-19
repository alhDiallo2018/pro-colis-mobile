import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ConditionsTransportPage extends StatelessWidget {
  const ConditionsTransportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Conditions de transport'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Acceptation des conditions'),
          const SizedBox(height: 12),
          _bodyText(
            'En utilisant la plateforme ProColis pour l\'envoi ou le transport '
            'de colis, vous acceptez sans réserve les présentes conditions de '
            'transport. Ces conditions s\'appliquent à tous les utilisateurs, '
            'expéditeurs comme chauffeurs.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Obligations de l\'expéditeur'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'expéditeur s\'engage à :',
          ),
          _bodyText(
            '• Déclarer avec exactitude le contenu, le poids et les dimensions du colis.',
          ),
          _bodyText(
            '• Emballer le colis de manière adéquate pour résister au transport.',
          ),
          _bodyText(
            '• Fournir les coordonnées complètes et exactes du destinataire.',
          ),
          _bodyText(
            '• Ne pas expédier d\'articles interdits (voir la liste des colis interdits).',
          ),
          _bodyText(
            '• Communiquer au destinataire le code PIN de livraison.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Colis interdits'),
          const SizedBox(height: 12),
          _bodyText(
            'Sont strictement interdits au transport :',
          ),
          _bodyText(
            '• Substances illicites, drogues, psychotropes.',
          ),
          _bodyText(
            '• Armes, explosifs, munitions.',
          ),
          _bodyText(
            '• Produits périssables non réfrigérés.',
          ),
          _bodyText(
            '• Animaux vivants.',
          ),
          _bodyText(
            '• Objets de valeur non déclarés (bijoux, espèces, métaux précieux).',
          ),
          _bodyText(
            '• Produits contrefaits.',
          ),
          _bodyText(
            '• Liquides inflammables, produits chimiques dangereux.',
          ),
          _bodyText(
            'Consultez la page Colis interdits pour la liste complète.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Droit de contrôle'),
          const SizedBox(height: 12),
          _bodyText(
            'Le chauffeur se réserve le droit de refuser un colis dont l\'emballage '
            'est insuffisant ou dont le contenu lui paraît suspect.',
          ),
          _bodyText(
            'En cas de doute raisonnable, le chauffeur peut demander l\'ouverture '
            'du colis en présence de l\'expéditeur pour vérification.',
          ),
          _bodyText(
            'ProColis et le chauffeur se réservent le droit de signaler tout colis '
            'suspect aux autorités compétentes.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Délais de transport'),
          const SizedBox(height: 12),
          _bodyText(
            'Les délais de livraison indiqués sont des estimations fournies par '
            'le chauffeur. ProColis ne garantit pas les délais et ne saurait être '
            'tenue responsable des retards liés aux conditions de circulation, '
            'intempéries ou autres événements imprévisibles.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Livraison'),
          const SizedBox(height: 12),
          _bodyText(
            'La livraison est réputée effectuée lorsque le destinataire communique '
            'le code PIN au chauffeur et accuse réception du colis.',
          ),
          _bodyText(
            'En cas d\'absence du destinataire, le chauffeur contacte l\'expéditeur '
            'pour convenir d\'une solution (nouvelle tentative, dépôt en agence, '
            'retour à l\'expéditeur).',
          ),
          _bodyText(
            'Après deux tentatives infructueuses, le colis est retourné à '
            'l\'expéditeur. Les frais de retour sont à la charge de l\'expéditeur.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('7. Annulation et modification'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'expéditeur peut annuler un envoi avant la prise en charge par '
            'le chauffeur. Des frais d\'annulation peuvent s\'appliquer.',
          ),
          _bodyText(
            'Le chauffeur peut annuler une prise en charge en cas de force majeure. '
            'Il doit en informer l\'expéditeur dans les plus brefs délais.',
          ),
          _bodyText(
            'Consultez notre politique d\'annulation et remboursement pour plus '
            'de détails.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('8. Responsabilité en cas de perte ou d\'avarie'),
          const SizedBox(height: 12),
          _bodyText(
            'Le chauffeur est responsable de l\'intégrité du colis dès sa prise '
            'en charge jusqu\'à la livraison.',
          ),
          _bodyText(
            'En cas de perte ou d\'avarie, l\'expéditeur doit déposer une '
            'réclamation dans les 48 heures suivant la date prévue de livraison.',
          ),
          _bodyText(
            'L\'indemnisation est plafonnée à la valeur déclarée du colis, dans '
            'la limite de 500 000 FCFA, sauf souscription d\'une assurance '
            'complémentaire.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('9. Réclamations'),
          const SizedBox(height: 12),
          _bodyText(
            'Toute réclamation relative au transport doit être déposée via '
            'l\'application dans la section dédiée ou par email à '
            'support-commercial@sendprocolis.com.',
          ),
          _bodyText(
            'La réclamation doit inclure : le numéro de suivi, la description '
            'du problème, des photos du colis endommagé si applicable, et toute '
            'pièce justificative.',
          ),
          _bodyText(
            'Le délai de traitement est de 5 jours ouvrés maximum.',
          ),
          const SizedBox(height: 32),
          _bodyText(
            'Dernière mise à jour : juillet 2026.',
          ),
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
