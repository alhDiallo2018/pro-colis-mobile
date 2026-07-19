import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class MentionsLegalesPage extends StatelessWidget {
  const MentionsLegalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mentions légales'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Éditeur de la plateforme'),
          const SizedBox(height: 12),
          _bodyText(
            'La plateforme ProColis est éditée par SendProColis, société de droit sénégalais.',
          ),
          _bodyText(
            'Siège social : Sacré-Cœur 3, Dakar, Sénégal.',
          ),
          _bodyText(
            'NINEA : SP170720267_fictif — RCCM : SP0123456789_fictif.',
          ),
          _bodyText(
            'Email : support-commercial@sendprocolis.com.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Directeur de la publication'),
          const SizedBox(height: 12),
          _bodyText(
            'M. Serigne Fallou, Directeur général de SendProColis.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Hébergement'),
          const SizedBox(height: 12),
          _bodyText(
            'La plateforme est hébergée par OVH / OVHcloud.',
          ),
          _bodyText(
            'Siège social : 2 rue Kellermann, 59100 Roubaix, France.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Objet de la plateforme'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis est une plateforme de mise en relation entre expéditeurs '
            'et chauffeurs professionnels pour le transport de colis au Sénégal, '
            'en Afrique et à l\'international.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Fonctionnement'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis propose deux modes de mise en relation :',
          ),
          const SizedBox(height: 8),
          _subsectionTitle('Mode libre-service'),
          _bodyText(
            'L\'expéditeur publie une annonce décrivant le colis (départ, destination, '
            'poids, prix souhaité). Les chauffeurs vérifiés consultent les annonces et '
            'proposent leurs offres. L\'expéditeur choisit l\'offre qui lui convient.',
          ),
          const SizedBox(height: 8),
          _subsectionTitle('Mode annonce'),
          _bodyText(
            'Le chauffeur publie un trajet planifié. L\'expéditeur sélectionne un '
            'trajet et réserve une place pour son colis.',
          ),
          _bodyText(
            'La plateforme offre également un suivi en temps réel des colis, '
            'une messagerie intégrée, un système de points fidélité et un wallet '
            'pour les paiements.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Transport et obligations'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'expéditeur est responsable de la déclaration exacte du contenu, du poids '
            'et de la valeur du colis. Le colis doit être correctement emballé pour '
            'résister au transport.',
          ),
          _bodyText(
            'Les informations requises pour tout envoi comprennent : le nom et le '
            'numéro de téléphone de l\'expéditeur, le nom et le numéro de téléphone '
            'du destinataire, les adresses de départ et de livraison, le poids '
            'estimé et une description du contenu.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('7. Responsabilité'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis agit en tant qu\'intermédiaire technique. La plateforme ne '
            'garantit pas la conclusion effective des contrats de transport entre '
            'les utilisateurs.',
          ),
          _bodyText(
            'ProColis ne saurait être tenue responsable des dommages directs ou '
            'indirects résultant de l\'utilisation de la plateforme, sauf en cas '
            'de faute lourde ou intentionnelle.',
          ),
          _bodyText(
            'La responsabilité du transport incombe au chauffeur et à l\'expéditeur '
            'selon les termes convenus entre eux.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('8. Paiements'),
          const SizedBox(height: 12),
          _bodyText(
            'Les paiements transitent par des prestataires partenaires sécurisés.',
          ),
          _bodyText(
            'ProColis prélève une commission sur chaque transaction selon les '
            'conditions tarifaires en vigueur.',
          ),
          _bodyText(
            'Les fonds sont conservés dans le wallet du chauffeur jusqu\'au '
            'retrait vers son compte bancaire ou mobile money.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('9. Données personnelles'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis collecte les données suivantes : nom, prénom, numéro de '
            'téléphone, adresse email, adresse de localisation, informations sur '
            'les colis envoyés et reçus, données de géolocalisation pour le suivi.',
          ),
          _bodyText(
            'Finalités du traitement : création et gestion du compte, mise en '
            'relation expéditeurs-chauffeurs, suivi des colis, gestion des '
            'paiements, amélioration du service, communication marketing (avec '
            'consentement).',
          ),
          _bodyText(
            'Conformément à la loi sénégalaise sur la protection des données '
            'personnelles, vous disposez des droits d\'accès, de rectification, '
            'd\'opposition et de suppression de vos données.',
          ),
          _bodyText(
            'Pour exercer vos droits, contactez-nous à : support-commercial@sendprocolis.com.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('10. Comptes utilisateurs'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'inscription est gratuite. L\'utilisateur s\'engage à fournir des '
            'informations exactes et à les maintenir à jour. Chaque utilisateur est '
            'responsable de la confidentialité de ses identifiants.',
          ),
          _bodyText(
            'ProColis se réserve le droit de suspendre ou supprimer tout compte '
            'en cas de non-respect des présentes conditions.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('11. Chauffeurs partenaires'),
          const SizedBox(height: 12),
          _bodyText(
            'Les chauffeurs doivent fournir les documents requis : permis de '
            'conduire, carte grise, assurance, pièce d\'identité. La vérification '
            'est effectuée par ProColis via des garages partenaires.',
          ),
          _bodyText(
            'Les chauffeurs s\'engagent à respecter les délais convenus, à '
            'manipuler les colis avec soin et à respecter le code de la route.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('12. Score de réputation'),
          const SizedBox(height: 12),
          _bodyText(
            'Chaque chauffeur et expéditeur se voit attribuer un score basé sur '
            'les évaluations, le respect des délais et la qualité de service.',
          ),
          _bodyText(
            'Ce score est public et participe à la confiance entre utilisateurs '
            'de la plateforme.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('13. Wallet et points'),
          const SizedBox(height: 12),
          _bodyText(
            'Les chauffeurs disposent d\'un wallet numérique crédité après chaque '
            'livraison confirmée. Le retrait est possible vers un compte bancaire '
            'ou mobile money.',
          ),
          _bodyText(
            'Les expéditeurs accumulent des points fidélité à chaque envoi, '
            'utilisables en réduction sur leurs prochains colis.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('14. Propriété intellectuelle'),
          const SizedBox(height: 12),
          _bodyText(
            'Tous les contenus de la plateforme (marque, logo, design, code source, '
            'textes, images) sont la propriété exclusive de SendProColis.',
          ),
          _bodyText(
            'Toute reproduction ou utilisation sans autorisation préalable est '
            'strictement interdite.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('15. Réclamations'),
          const SizedBox(height: 12),
          _bodyText(
            'Toute réclamation doit être adressée à support-commercial@sendprocolis.com ou '
            'via le formulaire de contact de l\'application.',
          ),
          _bodyText(
            'ProColis s\'engage à répondre dans un délai de 48 heures ouvrées.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('16. Droit applicable'),
          const SizedBox(height: 12),
          _bodyText(
            'Les présentes mentions légales sont régies par le droit sénégalais.',
          ),
          _bodyText(
            'Tout litige relatif à l\'interprétation ou l\'exécution des présentes '
            'sera soumis aux tribunaux compétents de Dakar.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('17. Modifications'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis se réserve le droit de modifier les présentes mentions légales '
            'à tout moment. Les utilisateurs seront informés de toute modification '
            'substantielle par notification dans l\'application.',
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
