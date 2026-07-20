import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../../theme/app_theme.dart';

class ConfidentialitePage extends StatelessWidget {
  const ConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Confidentialité'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('1. Données collectées'),
          const SizedBox(height: 12),
          _bodyText(
            'Nous collectons les catégories de données suivantes :',
          ),
          _subsectionTitle('Données d\'identité'),
          _bodyText(
            'Nom, prénom, numéro de téléphone, adresse email, date de naissance, '
            'photo de profil.',
          ),
          _subsectionTitle('Données de localisation'),
          _bodyText(
            'Adresses de départ et de livraison, géolocalisation en temps réel '
            'pour le suivi des colis (avec consentement explicite).',
          ),
          _subsectionTitle('Données de transaction'),
          _bodyText(
            'Historique des envois, montants payés, méthode de paiement, '
            'transactions wallet.',
          ),
          _subsectionTitle('Données techniques'),
          _bodyText(
            'Type d\'appareil, système d\'exploitation, adresse IP, identifiants '
            'de session, journaux d\'activité.',
          ),
          _subsectionTitle('Données de vérification'),
          _bodyText(
            'Pièce d\'identité, permis de conduire, carte grise, attestation '
            'd\'assurance (pour les chauffeurs).',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Finalités du traitement'),
          const SizedBox(height: 12),
          _bodyText(
            'Vos données sont traitées pour les finalités suivantes :',
          ),
          _bodyText(
            '• Création et gestion du compte utilisateur.',
          ),
          _bodyText(
            '• Mise en relation expéditeurs-chauffeurs.',
          ),
          _bodyText(
            '• Suivi en temps réel des colis.',
          ),
          _bodyText(
            '• Traitement des paiements et des retraits wallet.',
          ),
          _bodyText(
            '• Vérification de l\'identité et des documents des chauffeurs.',
          ),
          _bodyText(
            '• Notation et système de réputation.',
          ),
          _bodyText(
            '• Envoi de notifications liées au service (statuts colis, offres).',
          ),
          _bodyText(
            '• Amélioration continue de la plateforme.',
          ),
          _bodyText(
            '• Communication marketing et promotions (avec consentement explicite).',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Base légale'),
          const SizedBox(height: 12),
          _bodyText(
            'Le traitement de vos données repose sur les bases légales suivantes :',
          ),
          _bodyText(
            '• Exécution du contrat : pour la fourniture du service de mise en '
            'relation et de transport.',
          ),
          _bodyText(
            '• Consentement : pour la géolocalisation, les communications marketing.',
          ),
          _bodyText(
            '• Obligation légale : pour la conservation des données de transaction '
            'et de vérification.',
          ),
          _bodyText(
            '• Intérêt légitime : pour la sécurité de la plateforme et la '
            'prévention de la fraude.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Durée de conservation'),
          const SizedBox(height: 12),
          _bodyText(
            'Les données sont conservées pour les durées suivantes :',
          ),
          _bodyText(
            '• Données du compte : pendant toute la durée d\'activité du compte '
            'et jusqu\'à 3 ans après la dernière utilisation.',
          ),
          _bodyText(
            '• Données de transaction : 10 ans (obligation légale).',
          ),
          _bodyText(
            '• Documents de vérification : 5 ans après la fin de l\'activité.',
          ),
          _bodyText(
            '• Données de géolocalisation : 30 jours maximum.',
          ),
          _bodyText(
            '• Données de session : 12 mois.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Destinataires des données'),
          const SizedBox(height: 12),
          _bodyText(
            'Vos données sont accessibles uniquement aux destinataires suivants :',
          ),
          _bodyText(
            '• Personnel autorisé de SendProColis (service client, technique).',
          ),
          _bodyText(
            '• Chauffeurs partenaires : accès limité aux informations nécessaires '
            'au transport (coordonnées, adresses).',
          ),
          _bodyText(
            '• Prestataires de paiement : pour le traitement des transactions.',
          ),
          _bodyText(
            '• Hébergeur (OVHcloud) : pour le stockage sécurisé des données.',
          ),
          _bodyText(
            'Nous ne vendons ni ne partageons vos données personnelles avec des '
            'tiers à des fins commerciales.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('6. Sécurité des données'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis met en œuvre des mesures techniques et organisationnelles '
            'appropriées pour protéger vos données :',
          ),
          _bodyText(
            '• Chiffrement des données en transit (TLS 1.3).',
          ),
          _bodyText(
            '• Chiffrement des données sensibles au repos.',
          ),
          _bodyText(
            '• Authentification forte pour l\'accès aux serveurs.',
          ),
          _bodyText(
            '• Audits de sécurité réguliers.',
          ),
          _bodyText(
            '• Formation du personnel à la protection des données.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('7. Vos droits'),
          const SizedBox(height: 12),
          _bodyText(
            'Conformément à la réglementation en vigueur, vous disposez des '
            'droits suivants :',
          ),
          _bodyText(
            '• Droit d\'accès : obtenir une copie de vos données.',
          ),
          _bodyText(
            '• Droit de rectification : corriger les données inexactes.',
          ),
          _bodyText(
            '• Droit à l\'effacement : demander la suppression de vos données.',
          ),
          _bodyText(
            '• Droit d\'opposition : refuser certains traitements.',
          ),
          _bodyText(
            '• Droit à la portabilité : récupérer vos données dans un format lisible.',
          ),
          _bodyText(
            '• Droit de retrait du consentement : à tout moment, pour les traitements '
            'fondés sur le consentement.',
          ),
          _bodyText(
            'Pour exercer vos droits, écrivez à : support-commercial@sendprocolis.com.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('8. Délégué à la protection des données (DPO)'),
          const SizedBox(height: 12),
          _bodyText(
            'Notre DPO est joignable à l\'adresse suivante : '
            'support-commercial@sendprocolis.com.',
          ),
          _bodyText(
            'Sacré-Cœur 3, Dakar, Sénégal.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('9. Cookies et traceurs'),
          const SizedBox(height: 12),
          _bodyText(
            'L\'application mobile ProColis utilise des identifiants techniques '
            'nécessaires à son fonctionnement (jetons de session, préférences '
            'locales).',
          ),
          _bodyText(
            'Aucun cookie de suivi publicitaire tiers n\'est utilisé dans '
            'l\'application mobile.',
          ),
          _bodyText(
            'Des outils d\'analyse anonymes peuvent être utilisés pour améliorer '
            'l\'expérience utilisateur.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('10. Modifications de la politique'),
          const SizedBox(height: 12),
          _bodyText(
            'Cette politique de confidentialité peut être mise à jour '
            'périodiquement.',
          ),
          _bodyText(
            'Les modifications substantielles seront notifiées dans l\'application '
            'et par email.',
          ),
          _bodyText(
            'Nous vous invitons à consulter régulièrement cette page.',
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
