import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ColisInterditsPage extends StatelessWidget {
  const ColisInterditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Colis interdits'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.red50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.red100),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.red400, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le transport de colis interdits expose l\'expéditeur et le '
                    'chauffeur à des poursuites pénales.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.red500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('1. Produits strictement interdits'),
          const SizedBox(height: 12),
          _bodyText(
            'Les articles suivants sont strictement interdits au transport sur '
            'la plateforme ProColis :',
          ),
          const SizedBox(height: 8),
          _subsectionTitle('Drogues et substances illicites'),
          _bodyText(
            'Toutes substances classées comme stupéfiants, drogues, psychotropes '
            'ou précurseurs par la loi sénégalaise.',
          ),
          _subsectionTitle('Armes et explosifs'),
          _bodyText(
            'Armes à feu, armes blanches, munitions, explosifs, feux d\'artifice, '
            'produits pyrotechniques de toute nature.',
          ),
          _subsectionTitle('Produits chimiques dangereux'),
          _bodyText(
            'Liquides inflammables (essence, alcool à brûler), produits corrosifs, '
            'gaz comprimés, matières radioactives, produits toxiques.',
          ),
          _subsectionTitle('Animaux vivants'),
          _bodyText(
            'Aucun animal vivant n\'est accepté au transport, quelle que soit '
            'sa taille.',
          ),
          _subsectionTitle('Produits périssables non conditionnés'),
          _bodyText(
            'Denrées alimentaires nécessitant une chaîne du froid, produits '
            'frais non emballés hermétiquement.',
          ),
          _subsectionTitle('Objets de valeur non déclarés'),
          _bodyText(
            'Espèces, bijoux, pierres précieuses, métaux précieux, titres '
            'financiers, objets d\'art de grande valeur.',
          ),
          _subsectionTitle('Produits contrefaits'),
          _bodyText(
            'Toute marchandise de contrefaçon, copie illicite, produit portant '
            'atteinte aux droits de propriété intellectuelle.',
          ),
          _subsectionTitle('Tabac et alcool non déclarés'),
          _bodyText(
            'Produits soumis à réglementation particulière sans les autorisations '
            'requises.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('2. Produits réglementés'),
          const SizedBox(height: 12),
          _bodyText(
            'Les produits suivants sont autorisés sous réserve de déclaration '
            'préalable et d\'emballage conforme :',
          ),
          _bodyText(
            '• Médicaments : uniquement dans leur emballage d\'origine, avec '
            'ordonnance si disponible.',
          ),
          _bodyText(
            '• Produits électroniques avec batterie au lithium : batterie '
            'protégée contre les courts-circuits.',
          ),
          _bodyText(
            '• Liquides (boissons, cosmétiques) : emballage étanche et résistant.',
          ),
          _bodyText(
            '• Produits fragiles (verre, céramique) : emballage renforcé '
            'avec protection antichoc.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('3. Conséquences du non-respect'),
          const SizedBox(height: 12),
          _bodyText(
            'Le transport d\'un colis interdit entraîne :',
          ),
          _bodyText(
            '• L\'annulation immédiate de l\'envoi sans remboursement.',
          ),
          _bodyText(
            '• La suspension ou suppression du compte de l\'expéditeur.',
          ),
          _bodyText(
            '• Le signalement aux autorités compétentes.',
          ),
          _bodyText(
            '• L\'éventuelle responsabilité pénale de l\'expéditeur.',
          ),
          _bodyText(
            '• Le chauffeur est dégagé de toute responsabilité et peut refuser '
            'le transport sans pénalité.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('4. Conseils d\'emballage'),
          const SizedBox(height: 12),
          _bodyText(
            'Pour un transport en toute sécurité :',
          ),
          _bodyText(
            '• Utilisez un carton solide adapté au poids du contenu.',
          ),
          _bodyText(
            '• Remplissez les espaces vides avec du papier bulle ou du papier '
            'froissé.',
          ),
          _bodyText(
            '• Fermez hermétiquement le colis avec du ruban adhésif résistant.',
          ),
          _bodyText(
            '• Pour les liquides, placez le récipient dans un sac étanche.',
          ),
          _bodyText(
            '• Indiquez clairement « FRAGILE » si nécessaire.',
          ),
          _bodyText(
            '• Retirez ou masquez les anciennes étiquettes d\'expédition.',
          ),
          _bodyText(
            '• Ne dépassez pas 30 kg par colis.',
          ),
          const SizedBox(height: 20),
          _sectionTitle('5. Droit de refus du chauffeur'),
          const SizedBox(height: 12),
          _bodyText(
            'Le chauffeur a le droit de refuser un colis dans les cas suivants :',
          ),
          _bodyText('• Emballage manifestement insuffisant.'),
          _bodyText('• Suspicion de contenu interdit.'),
          _bodyText('• Colis dégageant une odeur suspecte.'),
          _bodyText('• Colis dont le poids réel dépasse le poids déclaré.'),
          _bodyText(
            'En cas de refus justifié, l\'expéditeur n\'a droit à aucun '
            'remboursement des frais engagés.',
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
