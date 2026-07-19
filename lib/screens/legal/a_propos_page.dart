import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AProposPage extends StatelessWidget {
  const AProposPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('À propos'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.3,
                      color: AppTheme.textPrimary,
                    ),
                    children: const [
                      TextSpan(text: 'PRO'),
                      TextSpan(
                        text: 'COLIS',
                        style: TextStyle(color: AppTheme.amber400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _sectionTitle('Qui sommes-nous ?'),
          const SizedBox(height: 12),
          _bodyText(
            'ProColis est une plateforme de mise en relation entre expéditeurs '
            'et chauffeurs professionnels pour le transport de colis au Sénégal, '
            'en Afrique et à l\'international.',
          ),
          _bodyText(
            'Fondée par Serigne Fallou, notre plateforme répond au besoin de '
            'transport rapide et fiable de colis entre les villes sénégalaises, '
            'africaines et au-delà des frontières.',
          ),
          _bodyText(
            'Basée à Dakar, notre équipe travaille chaque jour pour simplifier '
            'l\'envoi de colis et offrir de nouvelles opportunités aux chauffeurs '
            'professionnels.',
          ),
          const SizedBox(height: 24),
          _sectionTitle('Notre mission'),
          const SizedBox(height: 12),
          _bodyText(
            'Rendre le transport de colis, au niveau national comme international, '
            'aussi simple que l\'envoi d\'un message.',
          ),
          _bodyText(
            'Nous connectons les personnes qui ont besoin d\'envoyer un colis '
            'avec des chauffeurs vérifiés qui se déplacent déjà sur le trajet, '
            'créant ainsi une solution économique, écologique et efficace.',
          ),
          const SizedBox(height: 24),
          _sectionTitle('Comment ça marche ?'),
          const SizedBox(height: 12),
          _step(
            '01',
            Icons.add_box,
            'Déclarez votre colis',
            'Indiquez le départ, la destination, le poids et votre prix. '
            'Publiez votre annonce en quelques secondes.',
          ),
          const SizedBox(height: 16),
          _step(
            '02',
            Icons.sell,
            'Recevez des offres',
            'Les chauffeurs disponibles sur votre trajet vous font des offres. '
            'Comparez et choisissez la meilleure.',
          ),
          const SizedBox(height: 16),
          _step(
            '03',
            Icons.local_shipping,
            'Suivez la livraison',
            'Suivez votre colis en temps réel jusqu\'à la remise au '
            'destinataire avec code PIN sécurisé.',
          ),
          const SizedBox(height: 24),
          _sectionTitle('Nos valeurs'),
          const SizedBox(height: 12),
          _value('Confiance', 'Chauffeurs vérifiés, système de notation, code PIN de livraison.'),
          _value('Transparence', 'Suivi en temps réel, prix libres, pas de frais cachés.'),
          _value('Proximité', 'Support client réactif 7j/7, équipe basée à Dakar.'),
          _value('Innovation', 'Plateforme digitale moderne, amélioration continue.'),
          const SizedBox(height: 24),
          _sectionTitle('Nous contacter'),
          const SizedBox(height: 12),
          _bodyText('Email : support-commercial@sendprocolis.com'),
          _bodyText('Téléphone : +221 76 516 27 96'),
          _bodyText('Adresse : Sacré-Cœur 3, Dakar, Sénégal'),
          _bodyText('Horaires : Lundi - Samedi, 8h - 20h'),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© ${DateTime.now().year} PRO COLIS — Tous droits réservés.',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppTheme.slate400,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _step(String number, IconData icon, String title, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _value(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
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
