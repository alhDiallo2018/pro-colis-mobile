import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CGUPage extends StatelessWidget {
  const CGUPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('CGU'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Objet'),
          const SizedBox(height: 12),
          _bodyText(
            'Les présentes Conditions Générales d\'Utilisation (CGU) définissent '
            'les modalités d\'accès et d\'utilisation de la plateforme ProColis, '
            'éditée par SendProColis.',
          ),
          _bodyText(
            'L\'utilisation de la plateforme implique l\'acceptation pleine et '
            'entière des présentes CGU par tout utilisateur, qu\'il soit expéditeur '
            'ou chauffeur.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Description des services'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis propose les services suivants :',
          ),
          _bodyText(
            '• Mise en relation entre expéditeurs et chauffeurs pour le transport '
            'interurbain de colis.',
          ),
          _bodyText(
            '• Publication d\'annonces de colis (mode libre-service).',
          ),
          _bodyText(
            '• Publication de trajets par les chauffeurs (mode annonce).',
          ),
          _bodyText(
            '• Suivi en temps réel des colis.',
          ),
          _bodyText(
            '• Messagerie intégrée entre utilisateurs.',
          ),
          _bodyText(
            '• Système de paiement via wallet.',
          ),
          _bodyText(
            '• Système de points fidélité.',
          ),
          _bodyText(
            '• Système de notation et de réputation.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Inscription et compte'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'inscription sur ProColis est gratuite et ouverte à toute personne '
            'majeure résidant au Sénégal.',
          ),
          _bodyText(
            'L\'utilisateur s\'engage à :',
          ),
          _bodyText(
            '• Fournir des informations exactes et complètes.',
          ),
          _bodyText(
            '• Maintenir ses informations à jour.',
          ),
          _bodyText(
            '• Ne pas créer de faux compte ou usurper l\'identité d\'un tiers.',
          ),
          _bodyText(
            '• Garder confidentiels ses identifiants de connexion.',
          ),
          _bodyText(
            'L\'inscription en tant que chauffeur nécessite la fourniture de '
            'documents complémentaires soumis à vérification.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Obligations des utilisateurs'),
          const SizedBox(height: 12),
          _bodyText(
            'Chaque utilisateur s\'engage à :',
          ),
          _bodyText(
            '• Respecter les lois et règlements en vigueur au Sénégal.',
          ),
          _bodyText(
            '• Utiliser la plateforme de manière loyale et de bonne foi.',
          ),
          _bodyText(
            '• Ne pas publier de contenu illicite, diffamatoire ou abusif.',
          ),
          _bodyText(
            '• Ne pas tenter de contourner les mécanismes de sécurité.',
          ),
          _bodyText(
            '• Honorer les engagements pris via la plateforme (envois, offres).',
          ),
          _bodyText(
            '• Ne pas effectuer de transactions en dehors de la plateforme.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Rôle de la plateforme'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis agit exclusivement en tant qu\'intermédiaire technique '
            'facilitant la mise en relation entre expéditeurs et chauffeurs.',
          ),
          _bodyText(
            'ProColis n\'est pas transporteur et n\'est partie à aucun contrat '
            'de transport conclu entre les utilisateurs.',
          ),
          _bodyText(
            'ProColis ne garantit pas :',
          ),
          _bodyText(
            '• La disponibilité permanente de la plateforme.',
          ),
          _bodyText(
            '• La conclusion effective des contrats de transport.',
          ),
          _bodyText(
            '• Le comportement ou la fiabilité des utilisateurs.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Tarifs et commissions'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis prélève une commission sur chaque transaction conclue '
            'via la plateforme. Le taux de commission est indiqué dans la '
            'section Paiement de l\'application.',
          ),
          _bodyText(
            'Les prix des prestations de transport sont librement fixés par '
            'les expéditeurs et les chauffeurs.',
          ),
          _bodyText(
            'ProColis se réserve le droit de modifier ses tarifs et commissions '
            'à tout moment, sous réserve d\'en informer les utilisateurs.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('7. Paiements'),
          const SizedBox(height: 12),
          _bodyText(
            'Les paiements transitent par le système de wallet ProColis, via '
            'des prestataires tiers sécurisés.',
          ),
          _bodyText(
            'Le paiement est débité du wallet de l\'expéditeur au moment de la '
            'confirmation du transport.',
          ),
          _bodyText(
            'Les fonds sont crédités sur le wallet du chauffeur après '
            'confirmation de la livraison par le destinataire (code PIN).',
          ),
          _bodyText(
            'Les chauffeurs peuvent retirer leurs gains vers un compte bancaire '
            'ou mobile money.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('8. Annulation et remboursement'),
          const SizedBox(height: 12),
          _bodyText(
            'Les conditions d\'annulation et de remboursement sont détaillées '
            'dans la page dédiée « Annulation & remboursement ».',
          ),
          _bodyText(
            'Un expéditeur peut annuler un envoi sans frais avant l\'acceptation '
            'd\'une offre par un chauffeur.',
          ),
          _bodyText(
            'Après acceptation, des frais d\'annulation peuvent s\'appliquer.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('9. Propriété intellectuelle'),
          const SizedBox(height: 12),
          _bodyText(
            'Tous les éléments de la plateforme (marque ProColis, logo, design, '
            'code source, textes, images, base de données) sont la propriété '
            'exclusive de SendProcolis et sont protégés par le droit de la '
            'propriété intellectuelle.',
          ),
          _bodyText(
            'Toute reproduction, représentation, modification ou exploitation '
            'non autorisée est strictement interdite.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('10. Responsabilité'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis met tout en œuvre pour assurer la disponibilité et la '
            'sécurité de la plateforme, mais ne saurait être tenue responsable :',
          ),
          _bodyText(
            '• Des interruptions temporaires pour maintenance.',
          ),
          _bodyText(
            '• Des dommages résultant d\'une utilisation frauduleuse par un tiers.',
          ),
          _bodyText(
            '• De la perte ou de l\'avarie des colis (responsabilité du chauffeur).',
          ),
          _bodyText(
            '• Des litiges entre utilisateurs.',
          ),
          _bodyText(
            'La responsabilité de ProColis est limitée au montant de la commission '
            'perçue sur la transaction concernée.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('11. Résiliation'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis se réserve le droit de suspendre ou résilier un compte '
            'en cas de :',
          ),
          _bodyText(
            '• Non-respect des présentes CGU.',
          ),
          _bodyText(
            '• Activité frauduleuse ou suspecte.',
          ),
          _bodyText(
            '• Inactivité prolongée du compte (plus de 24 mois).',
          ),
          _bodyText(
            '• Réclamations multiples et répétées.',
          ),
          _bodyText(
            'L\'utilisateur peut supprimer son compte à tout moment depuis '
            'les paramètres de l\'application.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('12. Modifications des CGU'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis se réserve le droit de modifier les présentes CGU à tout '
            'moment. Les utilisateurs seront informés des modifications par '
            'notification dans l\'application.',
          ),
          _bodyText(
            'La poursuite de l\'utilisation de la plateforme après notification '
            'vaut acceptation des nouvelles CGU.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('13. Droit applicable et juridiction'),
          const SizedBox(height: 12),
          _bodyText(
            'Les présentes CGU sont régies par le droit sénégalais.',
          ),
          _bodyText(
            'Tout litige relatif à leur interprétation ou exécution sera soumis '
            'aux tribunaux compétents de Dakar, Sénégal.',
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
