import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';
import '../../providers/public_config_provider.dart';
import '../../theme/app_theme.dart';
import 'legal_components.dart';

class ConfidentialitePage extends ConsumerWidget {
  const ConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(publicConfigProvider);
    final supportEmail = config?.displaySupportEmail ?? '';
    final companyName = config?.displayLegalCompanyName ?? '';
    final address = config?.displayLegalAddress ?? '';
    final registrationNumber = config?.displayLegalRegistrationNumber ?? '';
    final cdpAuthorization = config?.displayLegalCdpAuthorization ?? '';
    final privacyEmail = config?.displayLegalPrivacyEmail ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // ✅ Utiliser GoRouter pour un retour fiable
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          tooltip: 'Retour',
        ),
        title: const Text(
          'Confidentialité',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        children: [
          // ── En-tête avec icône ───────────────────────────────────
          _buildHeader(),
          const SizedBox(height: 32),

          // ── Introduction ─────────────────────────────────────────
          LegalInfoBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppTheme.teal600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SendProColis attache une grande importance à la protection de '
                        'vos données personnelles. La présente politique décrit, de '
                        'manière claire et simple, les données que nous traitons, '
                        'pourquoi nous les traitons, et les droits dont vous disposez. '
                        'Elle est cohérente avec le fonctionnement réel de la plateforme '
                        'et avec la législation sénégalaise applicable en matière de '
                        'protection des données à caractère personnel.',
                    style: AppFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.textBody,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── 1. Responsable du traitement ────────────────────────
          _buildSection(
            number: '1',
            title: 'Responsable du traitement',
            icon: Icons.business_rounded,
            children: [
              const LegalBodyText(
                'SendProColis est le responsable du traitement des données '
                    'personnelles nécessaires au fonctionnement de la plateforme de '
                    'mise en relation entre expéditeurs et chauffeurs.',
              ),
              LegalInfoBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Raison sociale', companyName),
                    _buildInfoRow('Adresse du siège', address),
                    _buildInfoRow('N° d\'immatriculation', registrationNumber),
                    _buildInfoRow('N° autorisation CDP', cdpAuthorization),
                    const SizedBox(height: 10),
                    Text(
                      'Ces informations officielles sont renseignées par '
                          'l\'administrateur de la plateforme.',
                      style: AppFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.slate500,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── 2. Données collectées ───────────────────────────────
          _buildSection(
            number: '2',
            title: 'Données collectées',
            icon: Icons.folder_open_rounded,
            children: [
              const LegalBodyText(
                'Dans le cadre de l\'utilisation de la plateforme, nous traitons '
                    'les données suivantes :',
              ),
              const LegalDataGrid([
                LegalInfo('Identité et compte',
                    'nom complet, numéro de téléphone, adresse e-mail (facultative), photo de profil, code PIN ou mot de passe (haché).'),
                LegalInfo('Coordonnées',
                    'adresse, ville et région renseignées dans votre profil ou votre carnet d\'adresses.'),
                LegalInfo('Colis',
                    'noms, téléphones et e-mails de l\'expéditeur et du destinataire, adresse de destination, description, type, poids et dimensions.'),
                LegalInfo('Trajet',
                    'zones de départ et de destination, avec leurs coordonnées géographiques.'),
                LegalInfo('Localisation du chauffeur',
                    'position GPS, uniquement pendant une livraison active (voir section 4).'),
                LegalInfo('Documents chauffeur',
                    'pièce d\'identité (recto/verso) soumise à vérification, informations du véhicule.'),
                LegalInfo('Transactions',
                    'montants, méthode et statut de paiement, historique.'),
                LegalInfo('Portefeuille et points',
                    'solde, points de fidélité, commissions et dettes éventuelles.'),
                LegalInfo('Messages',
                    'messages échangés entre utilisateurs et identifiants de notification.'),
                LegalInfo('Données techniques',
                    'adresse IP, type d\'appareil, journaux de sécurité.'),
              ]),
              const SizedBox(height: 12),
              _buildNote(
                'Nous ne collectons que les données nécessaires au fonctionnement '
                    'de la plateforme.',
              ),
            ],
          ),

          // ── 3. Finalités ────────────────────────────────────────
          _buildSection(
            number: '3',
            title: 'Finalités du traitement',
            icon: Icons.track_changes_rounded,
            children: [
              const LegalBodyText(
                'Vos données sont traitées pour les finalités suivantes :',
              ),
              const LegalDataGrid([
                LegalInfo('Gestion du compte',
                    'création, connexion et gestion de votre compte.'),
                LegalInfo('Mise en relation',
                    'mise en relation entre expéditeurs et chauffeurs.'),
                LegalInfo('Attribution et suivi',
                    'attribution, acceptation et suivi des livraisons.'),
                LegalInfo('Géolocalisation',
                    'géolocalisation et suivi du colis (voir section 4).'),
                LegalInfo('Communication',
                    'échanges entre utilisateurs pendant la livraison.'),
                LegalInfo('Paiements',
                    'paiement et gestion des commissions, points et dettes.'),
                LegalInfo('Sécurité',
                    'prévention de la fraude et sécurité de la plateforme.'),
                LegalInfo('Assistance',
                    'traitement des demandes de support et réclamations.'),
                LegalInfo('Amélioration',
                    'amélioration du service et obligations légales.'),
              ]),
            ],
          ),

          // ── 4. Géolocalisation ──────────────────────────────────
          _buildSection(
            number: '4',
            title: 'Géolocalisation et suivi en temps réel',
            icon: Icons.location_on_rounded,
            children: [
              const LegalBodyText(
                'La localisation peut être utilisée pour fournir certaines '
                    'fonctionnalités de la plateforme, notamment le suivi de votre '
                    'colis :',
              ),
              const LegalBullet(
                'La position du chauffeur peut être utilisée pendant une '
                    'livraison active pour permettre au client de suivre la '
                    'progression du colis.',
              ),
              const LegalBullet(
                'Le client peut voir la progression uniquement dans le cadre '
                    'autorisé par le service.',
              ),
              const LegalBullet(
                'L\'accès à la localisation cesse lorsque la livraison n\'est '
                    'plus active.',
              ),
              const LegalBullet(
                'La permission GPS est demandée sur l\'appareil du chauffeur.',
              ),
              const SizedBox(height: 12),
              _buildNote(
                'SendProColis ne suit pas en permanence l\'ensemble de ses '
                    'utilisateurs. Seule la dernière position utile au suivi d\'un '
                    'colis en cours est exposée.',
                icon: Icons.shield_rounded,
                // ✅ Correction : utiliser les couleurs existantes
                color: AppTheme.teal600,
                bg: AppTheme.teal50,
              ),
            ],
          ),

          // ── 5. Services Google ──────────────────────────────────
          _buildSection(
            number: '5',
            title: 'Services Google (Maps, Places, Geocoding)',
            icon: Icons.map_rounded,
            children: [
              const LegalBodyText(
                'Certaines fonctionnalités géographiques de la plateforme '
                    'peuvent utiliser les services Google Maps. Lorsque vous utilisez '
                    'ces fonctionnalités, les conditions d\'utilisation de Google et '
                    'la politique de confidentialité de Google s\'appliquent également.',
              ),
              const LegalBodyText(
                'Cela ne signifie pas que Google reçoit l\'ensemble de vos données '
                    'SendProColis : seules les informations nécessaires au '
                    'fonctionnement de ces fonctionnalités géographiques sont '
                    'concernées.',
              ),
            ],
          ),

          // ── 6. Partage des données ──────────────────────────────
          _buildSection(
            number: '6',
            title: 'Partage des données',
            icon: Icons.share_rounded,
            children: [
              const LegalBodyText(
                'Vos données ne sont accessibles qu\'aux destinataires nécessaires '
                    'au fonctionnement du service :',
              ),
              const LegalDataGrid([
                LegalInfo('Client et chauffeur',
                    'informations minimales nécessaires à la livraison.'),
                LegalInfo('Administrateurs autorisés',
                    'personnel habilité de SendProColis.'),
                LegalInfo('Support',
                    'équipe en charge de l\'assistance.'),
                LegalInfo('Prestataires de paiement',
                    'traitement des transactions (PayDunya).'),
                LegalInfo('Services cartographiques',
                    'services géographiques (Google Maps).'),
              ]),
              const SizedBox(height: 12),
              LegalNoteBox(
                teal: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 18, color: AppTheme.teal700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Engagement : chaque utilisateur n\'accède qu\'aux '
                            'informations nécessaires à sa fonction. SendProColis ne '
                            'vend pas vos données personnelles à des tiers.',
                        style: AppFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.teal700,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── 7. Conservation ─────────────────────────────────────
          _buildSection(
            number: '7',
            title: 'Conservation des données',
            icon: Icons.schedule_rounded,
            children: [
              const LegalBodyText(
                'Les données sont conservées pendant la durée nécessaire aux '
                    'finalités pour lesquelles elles sont traitées, ainsi que lorsque '
                    'leur conservation est nécessaire pour respecter les obligations '
                    'légales, résoudre les litiges ou assurer la sécurité de la '
                    'plateforme.',
              ),
              const LegalBodyText(
                'En pratique, les données de votre compte sont conservées tant que '
                    'votre compte est actif. Les historiques de colis, de paiements et '
                    'de localisation sont conservés conformément aux règles de gestion '
                    'de la plateforme et aux exigences légales applicables.',
              ),
            ],
          ),

          // ── 8. Sécurité ─────────────────────────────────────────
          _buildSection(
            number: '8',
            title: 'Sécurité des données',
            icon: Icons.security_rounded,
            children: [
              const LegalBodyText(
                'Nous mettons en œuvre des mesures techniques et '
                    'organisationnelles appropriées :',
              ),
              const LegalDataGrid([
                LegalInfo('Authentification',
                    'connexion par téléphone et code PIN ou mot de passe.'),
                LegalInfo('Autorisation par rôles',
                    'accès limité selon votre rôle (client, chauffeur, admin).'),
                LegalInfo('Contrôle d\'accès',
                    'API protégées et accès vérifiés.'),
                LegalInfo('Chiffrement',
                    'échanges chiffrés en transit (HTTPS/TLS).'),
                LegalInfo('Minimisation',
                    'seules les données strictement nécessaires sont exposées.'),
                LegalInfo('Journalisation',
                    'journalisation des actions sensibles.'),
              ]),
              const SizedBox(height: 12),
              _buildNote(
                'Aucun système n\'étant totalement infaillible, nous vous invitons '
                    'à protéger vos identifiants et à nous signaler toute utilisation '
                    'suspecte.',
              ),
            ],
          ),

          // ── 9. Vos droits ───────────────────────────────────────
          _buildSection(
            number: '9',
            title: 'Vos droits',
            icon: Icons.gavel_rounded,
            children: [
              const LegalBodyText(
                'Conformément à la réglementation applicable, vous disposez '
                    'notamment des droits suivants :',
              ),
              const LegalDataGrid([
                LegalInfo('Droit d\'accès',
                    'obtenir une copie des données vous concernant.'),
                LegalInfo('Droit de rectification',
                    'faire corriger vos données inexactes.'),
                LegalInfo('Droit à la suppression',
                    'demander la suppression de vos données.'),
                LegalInfo('Retrait du consentement',
                    'retirer votre consentement à tout moment.'),
                LegalInfo('Droit à l\'information',
                    'connaître les finalités et destinataires.'),
              ]),
              const SizedBox(height: 16),
              _buildContactCard(supportEmail, privacyEmail),
            ],
          ),

          // ── 10. Données techniques ──────────────────────────────
          _buildSection(
            number: '10',
            title: 'Données techniques et cookies',
            icon: Icons.cookie_rounded,
            children: [
              const LegalBodyText(
                'La plateforme utilise des éléments techniques strictement '
                    'nécessaires à son fonctionnement (jetons de session, préférences '
                    'd\'affichage). Aucun cookie publicitaire ou de suivi tiers n\'est '
                    'utilisé. Vous pouvez configurer votre appareil pour bloquer '
                    'certains éléments techniques, mais certaines fonctionnalités '
                    'pourraient alors ne plus être accessibles.',
              ),
            ],
          ),

          // ── 11. Modifications ───────────────────────────────────
          _buildSection(
            number: '11',
            title: 'Modifications de la politique',
            icon: Icons.update_rounded,
            children: [
              const LegalBodyText(
                'SendProColis peut mettre à jour la présente politique afin de '
                    'refléter l\'évolution de la plateforme ou de la réglementation. '
                    'Les utilisateurs seront informés des modifications substantielles '
                    'par notification ou par e-mail. Nous vous invitons à consulter '
                    'régulièrement cette page.',
              ),
            ],
          ),

          const SizedBox(height: 40),

          // ── Footer ──────────────────────────────────────────────
          _buildFooter(supportEmail),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.teal500, AppTheme.teal700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.teal500.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.privacy_tip_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Politique de confidentialité',
          textAlign: TextAlign.center,
          style: AppFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Protection de vos données personnelles',
          textAlign: TextAlign.center,
          style: AppFonts.manrope(
            fontSize: 14.5,
            color: AppTheme.slate500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.slate100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Dernière mise à jour : septembre 2026',
            style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION
  // ============================================================
  Widget _buildSection({
    required String number,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: AppFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 20, color: AppTheme.teal600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _buildInfoRow(String label, String value) {
    final displayValue = value.isNotEmpty ? value : '[À COMPLÉTER]';
    final isPlaceholder = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppFonts.manrope(
                fontSize: 13,
                color: AppTheme.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: AppFonts.manrope(
                fontSize: 13,
                color: isPlaceholder ? AppTheme.slate400 : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(String text, {IconData? icon, Color? color, Color? bg}) {
    final noteColor = color ?? AppTheme.slate500;
    final bgColor = bg ?? AppTheme.slate100;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: noteColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 16, color: noteColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.manrope(
                fontSize: 12.5,
                color: noteColor,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(String supportEmail, String privacyEmail) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.teal50,
            AppTheme.teal50.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.teal100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_support_rounded,
                  size: 20, color: AppTheme.teal700),
              const SizedBox(width: 8),
              Text(
                'Nous contacter',
                style: AppFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.teal700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            Icons.email_rounded,
            'Support',
            supportEmail.isNotEmpty ? supportEmail : '[À CONFIGURER]',
          ),
          const SizedBox(height: 8),
          _buildContactRow(
            Icons.privacy_tip_rounded,
            'Protection des données',
            privacyEmail.isNotEmpty ? privacyEmail : '[À CONFIGURER]',
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.teal600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label : ',
                  style: AppFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.teal700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: AppFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(String supportEmail) {
    return Column(
      children: [
        Divider(height: 1, color: AppTheme.slate200),
        const SizedBox(height: 20),
        Icon(
          Icons.verified_user_rounded,
          size: 28,
          color: AppTheme.teal500.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          '© ${DateTime.now().year} SendProColis',
          textAlign: TextAlign.center,
          style: AppFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tous droits réservés',
          textAlign: TextAlign.center,
          style: AppFonts.manrope(
            fontSize: 12,
            color: AppTheme.slate500,
          ),
        ),
        if (supportEmail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Dakar, Sénégal · $supportEmail',
            textAlign: TextAlign.center,
            style: AppFonts.manrope(
              fontSize: 12,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ],
    );
  }
}
