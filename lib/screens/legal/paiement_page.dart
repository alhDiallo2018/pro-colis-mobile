import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PaiementPage extends StatelessWidget {
  const PaiementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Méthodes de paiement'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis accepte les méthodes de paiement suivantes via son '
            'système de wallet :',
          ),
          _bodyText('• Mobile Money (Orange Money, Wave, Free Money).'),
          _bodyText('• Carte bancaire (Visa, Mastercard).'),
          _bodyText('• Virement bancaire (pour les montants importants).'),
          _bodyText(
            'Tous les paiements sont effectués en Francs CFA (XOF).',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Traitement des paiements'),
          const SizedBox(height: 12),
          _bodyText(
            'Les paiements sont traités par des prestataires de services de '
            'paiement agréés, garantissant la sécurité des transactions.',
          ),
          _bodyText(
            'Lorsqu\'un expéditeur crée un colis, le montant du transport est '
            'débité de son wallet et placé sous séquestre jusqu\'à la livraison.',
          ),
          _bodyText(
            'À la livraison, après confirmation par code PIN du destinataire, '
            'les fonds sont libérés et crédités sur le wallet du chauffeur.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Sécurité des paiements'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis utilise des protocoles de sécurité conformes aux standards '
            'bancaires :',
          ),
          _bodyText('• Chiffrement SSL/TLS de toutes les transactions.'),
          _bodyText('• Authentification par code PIN ou OTP pour chaque paiement.'),
          _bodyText('• Conformité avec les normes de sécurité des données (PCI DSS).'),
          _bodyText('• Surveillance continue des transactions suspectes.'),
          _bodyText(
            'ProColis ne stocke jamais vos données bancaires complètes.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Commissions'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis prélève une commission de service sur chaque transaction. '
            'Le taux est transparent et indiqué avant chaque confirmation de '
            'transport.',
          ),
          _bodyText(
            'Commission expéditeur : incluse dans le prix affiché lors de la '
            'publication du colis.',
          ),
          _bodyText(
            'Commission chauffeur : déduite automatiquement du montant crédité '
            'après livraison.',
          ),
          _bodyText(
            'Les frais de retrait (wallet vers compte bancaire ou mobile money) '
            'sont à la charge du bénéficiaire selon les tarifs du prestataire.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Délais de traitement'),
          const SizedBox(height: 12),
          _bodyText(
            'Rechargement du wallet : instantané pour le mobile money, '
            '24-48 heures pour les virements bancaires.',
          ),
          _bodyText(
            'Libération des fonds après livraison : instantanée après '
            'confirmation du code PIN.',
          ),
          _bodyText(
            'Retrait vers compte bancaire : 24-72 heures ouvrées selon '
            'la banque.',
          ),
          _bodyText('Retrait vers mobile money : instantané ou sous 2 heures.'),
          const SizedBox(height: 20),
          _sectionTitle('6. Remboursements'),
          const SizedBox(height: 12),
          _bodyText(
            'Les conditions de remboursement sont détaillées dans la page '
            '« Annulation & remboursement ».',
          ),
          _bodyText(
            'En cas d\'annulation avant acceptation d\'une offre, le montant '
            'est immédiatement recrédité sur le wallet de l\'expéditeur.',
          ),
          _bodyText(
            'En cas de litige, le remboursement est traité après examen '
            'du dossier par notre équipe.',
          ),
          _bodyText('Délai de remboursement : 5 à 10 jours ouvrés.'),
          const SizedBox(height: 20),
          _sectionTitle('7. Litiges et contestations'),
          const SizedBox(height: 12),
          _bodyText(
            'En cas de contestation d\'un paiement ou d\'un débit non reconnu, '
            'veuillez contacter immédiatement notre service client :',
          ),
          _bodyText('• Email : reclamations@sendprocolis.com'),
          _bodyText('• Via l\'application : section Réclamations'),
          _bodyText(
            'Le litige sera examiné sous 5 jours ouvrés. En cas de débit '
            'injustifié, le montant sera intégralement remboursé.',
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
