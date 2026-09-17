import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';
import '../../providers/public_config_provider.dart';
import '../../theme/app_theme.dart';
import 'legal_components.dart';

class CGUPage extends ConsumerWidget {
  const CGUPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(publicConfigProvider);
    final supportEmail = config?.displaySupportEmail ?? '';
    final supportPhone = config?.displaySupportPhone ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // ✅ Même logique que ProfileScreen._logout : GoRouter avec fallback
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          tooltip: 'Retour',
        ),
        title: const Text(
          'Conditions d\'utilisation',
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
          _buildHeader(),
          const SizedBox(height: 32),

          // ── Introduction ────────────────────────────────────────
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
                    'En créant un compte ou en utilisant la plateforme SendProColis, '
                        'vous acceptez les présentes conditions d\'utilisation. Elles '
                        'décrivent de manière claire les règles applicables à votre '
                        'utilisation du service, conformément au fonctionnement réel de '
                        'la plateforme.',
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

          // ── 1. Objet du service ─────────────────────────────────
          _buildSection(
            number: '1',
            title: 'Objet du service',
            icon: Icons.apps_rounded,
            children: [
              const LegalBodyText(
                'SendProColis est une plateforme de mise en relation qui permet '
                    'aux expéditeurs de publier des colis et aux chauffeurs de '
                    'proposer leurs services pour les transporter. SendProColis '
                    'facilite la mise en relation, la négociation, le suivi et le '
                    'paiement de ces livraisons.',
              ),
              const LegalBodyText(
                'SendProColis agit en qualité d\'intermédiaire et ne réalise pas '
                    'lui-même le transport des colis. Le contrat de transport est '
                    'conclu directement entre l\'expéditeur et le chauffeur.',
              ),
            ],
          ),

          // ── 2. Définitions ──────────────────────────────────────
          _buildSection(
            number: '2',
            title: 'Définitions',
            icon: Icons.menu_book_rounded,
            children: [
              const LegalDataGrid([
                LegalInfo('Plateforme',
                    'l\'application mobile et le site web SendProColis.'),
                LegalInfo('Client / Expéditeur',
                    'l\'utilisateur qui publie un colis à faire transporter.'),
                LegalInfo('Chauffeur',
                    'l\'utilisateur qui accepte et réalise une livraison.'),
                LegalInfo('Colis',
                    'l\'objet ou le bien confié au transport via la plateforme.'),
                LegalInfo('Destinataire',
                    'la personne à qui le colis est remis à l\'arrivée.'),
                LegalInfo('Wallet',
                    'le portefeuille virtuel du chauffeur, alimenté par ses gains.'),
                LegalInfo('Points',
                    'les points de fidélité attribués aux utilisateurs.'),
              ]),
            ],
          ),

          // ── 3. Création et utilisation du compte ────────────────
          _buildSection(
            number: '3',
            title: 'Création et utilisation du compte',
            icon: Icons.person_add_rounded,
            children: [
              const LegalBodyText(
                'La création d\'un compte est gratuite. Elle nécessite un numéro '
                    'de téléphone valide et la création d\'un code PIN (ou d\'un mot '
                    'de passe). L\'utilisateur s\'engage à :',
              ),
              const LegalBullet(
                  'fournir des informations exactes, complètes et à jour ;'),
              const LegalBullet(
                  'ne pas créer de faux compte ni usurper l\'identité d\'un tiers ;'),
              const LegalBullet(
                  'garder confidentiels ses identifiants de connexion ;'),
              const LegalBullet(
                  'signaler toute utilisation frauduleuse de son compte.'),
              const SizedBox(height: 4),
              _buildNote(
                'Chaque utilisateur est responsable de toute activité effectuée '
                    'via son compte.',
                icon: Icons.shield_rounded,
                color: AppTheme.teal600,
                bg: AppTheme.teal50,
              ),
            ],
          ),

          // ── 4. Rôles client et chauffeur ────────────────────────
          _buildSection(
            number: '4',
            title: 'Rôles client et chauffeur',
            icon: Icons.people_rounded,
            children: [
              const LegalBodyText(
                'L\'inscription en tant que chauffeur nécessite des informations '
                    'complémentaires (document d\'identification, informations du '
                    'véhicule) soumises à vérification par SendProColis. Un chauffeur '
                    'ne peut réaliser de livraison que si son profil est actif.',
              ),
              const LegalBodyText(
                'Le client publie des colis, reçoit les offres des chauffeurs et '
                    'peut, selon le cas, choisir directement un chauffeur ou accepter '
                    'une offre.',
              ),
            ],
          ),

          // ── 5. Publication d'un colis ───────────────────────────
          _buildSection(
            number: '5',
            title: 'Publication d\'un colis',
            icon: Icons.inventory_2_rounded,
            children: [
              const LegalBodyText(
                'Lors de la publication d\'un colis, le client renseigne les '
                    'informations nécessaires : nom et coordonnées de l\'expéditeur et '
                    'du destinataire, description, type, poids et dimensions du colis, '
                    'zones de départ et de destination, et le cas échéant un prix '
                    'proposé, une option d\'urgence ou d\'assurance.',
              ),
              const LegalBodyText(
                'Le client peut publier son colis en « libre service » pour '
                    'recevoir des offres de chauffeurs, ou le proposer directement à '
                    'un chauffeur de son choix.',
              ),
              _buildNote(
                'Le client est seul responsable de l\'exactitude des informations '
                    'qu\'il fournit, notamment les coordonnées et adresses de départ '
                    'et de destination.',
              ),
            ],
          ),

          // ── 6. Acceptation d'une livraison ──────────────────────
          _buildSection(
            number: '6',
            title: 'Acceptation d\'une livraison',
            icon: Icons.handshake_rounded,
            children: [
              const LegalBodyText(
                'Un chauffeur peut proposer ses services sur un colis publié, sous '
                    'la forme d\'une offre ou d\'une proposition de prix. Le client '
                    'est libre d\'accepter ou de refuser ces offres. La livraison est '
                    'confirmée lorsque le client et le chauffeur se sont mis d\'accord '
                    'sur le prix, selon les règles de la plateforme.',
              ),
            ],
          ),

          // ── 7. Négociation ──────────────────────────────────────
          _buildSection(
            number: '7',
            title: 'Négociation',
            icon: Icons.chat_bubble_rounded,
            children: [
              const LegalBodyText(
                'Le client et le chauffeur peuvent négocier le prix d\'une '
                    'livraison, à tour de rôle, avant de confirmer leur accord. '
                    'Chaque partie peut accepter la proposition de l\'autre ou faire '
                    'une contre-proposition. Aucune partie ne peut accepter sa propre '
                    'proposition.',
              ),
            ],
          ),

          // ── 8. Paiement ─────────────────────────────────────────
          _buildSection(
            number: '8',
            title: 'Paiement',
            icon: Icons.payments_rounded,
            children: [
              const LegalBodyText(
                'Le paiement s\'effectue par les moyens proposés par la plateforme '
                    '(argent mobile, carte bancaire, ou espèces selon les règles en '
                    'vigueur). Les paiements sont traités via des prestataires de '
                    'paiement partenaires.',
              ),
              const LegalBodyText(
                'Le montant à régler est celui convenu entre le client et le '
                    'chauffeur, auquel peuvent s\'ajouter les frais applicables '
                    'affichés au moment de l\'opération.',
              ),
            ],
          ),

          // ── 9. Wallet et points ─────────────────────────────────
          _buildSection(
            number: '9',
            title: 'Wallet et points du chauffeur',
            icon: Icons.account_balance_wallet_rounded,
            children: [
              const LegalBodyText(
                'Les gains du chauffeur sont crédités sur son portefeuille '
                    '(wallet) selon les règles de la plateforme, après confirmation de '
                    'la livraison. Le chauffeur peut retirer ses gains dans les '
                    'conditions prévues (montants minimum et maximum, fréquences).',
              ),
              const LegalBodyText(
                'Des points peuvent être attribués aux utilisateurs pour certaines '
                    'actions (par exemple une livraison réalisée) et utilisés selon '
                    'les règles en vigueur.',
              ),
            ],
          ),

          // ── 10. Commissions ─────────────────────────────────────
          _buildSection(
            number: '10',
            title: 'Commissions',
            icon: Icons.percent_rounded,
            children: [
              const LegalBodyText(
                'SendProColis prélève une commission sur les livraisons réalisées '
                    'via la plateforme. Cette commission est calculée selon les règles '
                    'configurées par l\'administrateur (pourcentage, montant minimum '
                    'et maximum). La commission peut être prélevée sur le wallet, sur '
                    'les points ou, le cas échéant, enregistrée en dette.',
              ),
              const SizedBox(height: 8),
              LegalNoteBox(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppTheme.amber700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les tarifs, frais, commissions et pénalités applicables '
                            'sont ceux affichés sur la plateforme au moment de '
                            'l\'opération concernée, selon les règles en vigueur.',
                        style: AppFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.amber700,
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

          // ── 11. Annulations ─────────────────────────────────────
          _buildSection(
            number: '11',
            title: 'Annulations',
            icon: Icons.cancel_rounded,
            children: [
              const LegalBodyText(
                'Un colis peut être annulé selon son état d\'avancement et les '
                    'règles de la plateforme. Les conditions d\'annulation et leurs '
                    'conséquences financières (remboursement éventuel, pénalités) sont '
                    'déterminées par la plateforme au moment de l\'annulation, en '
                    'fonction du statut du colis et de la partie à l\'origine de '
                    'l\'annulation.',
              ),
              const LegalBodyText(
                'Les motifs d\'annulation et leurs conséquences sont décrits dans '
                    'la page dédiée « Annulation et remboursement » de la plateforme.',
              ),
            ],
          ),

          // ── 12. Pénalités ───────────────────────────────────────
          _buildSection(
            number: '12',
            title: 'Pénalités',
            icon: Icons.gavel_rounded,
            children: [
              const LegalBodyText(
                'En cas d\'annulation, des pénalités peuvent s\'appliquer selon '
                    'les règles configurées. Ces pénalités peuvent être à la charge du '
                    'client, du chauffeur, être partagées entre eux ou ne pas '
                    's\'appliquer lorsque la cause de l\'annulation le justifie. '
                    'Certaines situations peuvent être exemptées de pénalité.',
              ),
              const LegalBodyText(
                'Les montants et règles de répartition applicables sont ceux '
                    'affichés sur la plateforme au moment de l\'opération concernée.',
              ),
            ],
          ),

          // ── 13. Force majeure ───────────────────────────────────
          _buildSection(
            number: '13',
            title: 'Cas de force majeure',
            icon: Icons.flash_on_rounded,
            children: [
              const LegalBodyText(
                'Aucune des parties ne pourra être tenue responsable d\'un '
                    'manquement à ses obligations lorsque ce manquement résulte d\'un '
                    'cas de force majeure, c\'est-à-dire d\'un événement imprévisible, '
                    'irrésistible et extérieur aux parties (catastrophe naturelle, '
                    'grève, restriction des autorités, etc.).',
              ),
            ],
          ),

          // ── 14. Suivi et géolocalisation ────────────────────────
          _buildSection(
            number: '14',
            title: 'Suivi et géolocalisation',
            icon: Icons.location_on_rounded,
            children: [
              const LegalBodyText(
                'Pendant une livraison active, le client peut suivre la '
                    'progression de son colis, notamment la position du chauffeur '
                    'lorsque celle-ci est disponible. La position n\'est exposée que '
                    'pendant la période nécessaire au suivi de la livraison concernée, '
                    'et cesse lorsque la livraison n\'est plus active.',
              ),
              const LegalBodyText(
                'Le suivi de la position n\'a pas pour objet de permettre une '
                    'surveillance permanente du chauffeur, et n\'expose que la '
                    'dernière position utile au suivi, avec son horodatage. Pour plus '
                    'de détails, voir notre politique de confidentialité.',
              ),
            ],
          ),

          // ── 15. Responsabilités du client ───────────────────────
          _buildSection(
            number: '15',
            title: 'Responsabilités du client',
            icon: Icons.person_rounded,
            children: [
              const LegalBodyText('Le client s\'engage notamment à :'),
              const LegalBullet(
                  'décrire le colis avec exactitude (nature, poids, dimensions) ;'),
              const LegalBullet(
                  'ne confier que des colis autorisés (voir section 17) ;'),
              const LegalBullet(
                  'fournir des coordonnées et adresses exactes ;'),
              const LegalBullet(
                  'régler les montants convenus et les frais applicables ;'),
              const LegalBullet(
                  'respecter les règles de la plateforme et les lois en vigueur.'),
            ],
          ),

          // ── 16. Responsabilités du chauffeur ────────────────────
          _buildSection(
            number: '16',
            title: 'Responsabilités du chauffeur',
            icon: Icons.local_shipping_rounded,
            children: [
              const LegalBodyText('Le chauffeur s\'engage notamment à :'),
              const LegalBullet(
                  'disposer d\'un profil vérifié et d\'un véhicule adapté au transport ;'),
              const LegalBullet(
                  'réaliser la livraison avec soin et diligence, dans les conditions convenues ;'),
              const LegalBullet(
                  'respecter le code de la route et la réglementation applicable ;'),
              const LegalBullet(
                  'remettre le colis au destinataire selon le processus de confirmation prévu ;'),
              const LegalBullet(
                  'déclarer les paiements perçus en espèces selon les règles de la plateforme.'),
            ],
          ),

          // ── 17. Colis interdits ─────────────────────────────────
          _buildSection(
            number: '17',
            title: 'Contenus interdits / colis interdits',
            icon: Icons.block_rounded,
            children: [
              const LegalBodyText(
                'Certains biens ne peuvent pas être transportés via la plateforme '
                    '(produits illicites, dangereux ou interdits). La liste des colis '
                    'interdits est détaillée dans la page dédiée « Colis interdits ». '
                    'Le client s\'engage à ne publier aucun colis interdit.',
              ),
            ],
          ),

          // ── 18. Fraude et abus ──────────────────────────────────
          _buildSection(
            number: '18',
            title: 'Fraude et abus',
            icon: Icons.security_rounded,
            children: [
              const LegalBodyText(
                'Toute tentative de fraude, d\'abus ou de contournement des règles '
                    'de la plateforme (faux comptes, fausses informations, '
                    'transactions réalisées hors plateforme pour contourner les '
                    'commissions, utilisation abusive des annulations, etc.) est '
                    'interdite.',
              ),
              const LegalBodyText(
                'SendProColis peut prendre les mesures nécessaires, y compris la '
                    'suspension ou la suppression du compte concerné, et se réserve le '
                    'droit d\'engager toute action utile.',
              ),
            ],
          ),

          // ── 19. Suspension / suppression ────────────────────────
          _buildSection(
            number: '19',
            title: 'Suspension ou suppression d\'un compte',
            icon: Icons.person_off_rounded,
            children: [
              const LegalBodyText(
                'SendProColis peut suspendre ou supprimer un compte en cas de '
                    'non-respect des présentes conditions, de fraude, d\'abus, de '
                    'fausses informations ou de comportement portant atteinte à la '
                    'sécurité de la plateforme ou des autres utilisateurs.',
              ),
              const LegalBodyText(
                'L\'utilisateur peut également demander la suppression de son '
                    'compte à tout moment, dans les conditions prévues par la '
                    'plateforme.',
              ),
            ],
          ),

          // ── 20. Disponibilité du service ────────────────────────
          _buildSection(
            number: '20',
            title: 'Disponibilité du service',
            icon: Icons.cloud_done_rounded,
            children: [
              const LegalBodyText(
                'SendProColis s\'efforce d\'assurer la disponibilité de la '
                    'plateforme. Celle-ci peut toutefois être interrompue '
                    'temporairement pour des raisons de maintenance, de mise à jour ou '
                    'en cas d\'incident technique. SendProColis s\'efforce d\'en '
                    'limiter la durée et d\'en informer les utilisateurs.',
              ),
            ],
          ),

          // ── 21. Limitation de responsabilité ────────────────────
          _buildSection(
            number: '21',
            title: 'Limitation de responsabilité',
            icon: Icons.report_problem_rounded,
            children: [
              const LegalBodyText(
                'En sa qualité d\'intermédiaire, SendProColis ne peut être tenue '
                    'responsable :',
              ),
              const LegalBullet(
                  'des actes des utilisateurs (client ou chauffeur) ;'),
              const LegalBullet(
                  'de la perte, de l\'avarie ou du retard du colis, qui relèvent du contrat de transport conclu entre le client et le chauffeur ;'),
              const LegalBullet(
                  'des dommages indirects, pertes de revenus ou préjudices commerciaux ;'),
              const LegalBullet(
                  'des interruptions de service et des cas de force majeure.'),
            ],
          ),

          // ── 22. Propriété intellectuelle ────────────────────────
          _buildSection(
            number: '22',
            title: 'Propriété intellectuelle',
            icon: Icons.copyright_rounded,
            children: [
              const LegalBodyText(
                'Les éléments de la plateforme (marque, logo, design, code source, '
                    'contenus) sont protégés par les lois relatives à la propriété '
                    'intellectuelle. Toute reproduction, modification ou exploitation '
                    'non autorisée est interdite.',
              ),
            ],
          ),

          // ── 23. Données personnelles ────────────────────────────
          _buildSection(
            number: '23',
            title: 'Données personnelles',
            icon: Icons.privacy_tip_rounded,
            children: [
              const LegalBodyText(
                'Le traitement de vos données personnelles est décrit dans notre '
                    'politique de confidentialité. Les présentes conditions et la '
                    'politique de confidentialité forment un ensemble.',
              ),
            ],
          ),

          // ── 24. Modification des conditions ─────────────────────
          _buildSection(
            number: '24',
            title: 'Modification des conditions',
            icon: Icons.update_rounded,
            children: [
              const LegalBodyText(
                'SendProColis peut modifier les présentes conditions à tout '
                    'moment. Les utilisateurs seront informés des modifications '
                    'substantielles par notification sur la plateforme ou par e-mail. '
                    'L\'utilisation continue de la plateforme après cette information '
                    'vaut acceptation des nouvelles conditions.',
              ),
            ],
          ),

          // ── 25. Droit applicable ────────────────────────────────
          _buildSection(
            number: '25',
            title: 'Droit applicable et règlement des litiges',
            icon: Icons.balance_rounded,
            children: [
              const LegalBodyText(
                'Les présentes conditions sont régies par le droit sénégalais. En '
                    'cas de litige, les parties s\'efforceront de parvenir à une '
                    'solution amiable avant toute action. À défaut, le litige sera '
                    'soumis aux tribunaux compétents de Dakar, Sénégal.',
              ),
            ],
          ),

          // ── 26. Contact ─────────────────────────────────────────
          _buildSection(
            number: '26',
            title: 'Contact',
            icon: Icons.contact_support_rounded,
            children: [
              const LegalBodyText(
                'Pour toute question relative aux présentes conditions, vous '
                    'pouvez contacter SendProColis :',
              ),
              const SizedBox(height: 8),
              _buildContactCard(supportEmail, supportPhone),
            ],
          ),

          const SizedBox(height: 40),

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
            Icons.description_rounded,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Conditions générales d\'utilisation',
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
          'Règles d\'utilisation de la plateforme SendProColis',
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

  Widget _buildContactCard(String supportEmail, String supportPhone) {
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
          if (supportPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(
              Icons.phone_rounded,
              'Téléphone',
              supportPhone,
            ),
          ],
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
