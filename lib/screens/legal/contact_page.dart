import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Contact'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Nous contacter'),
          const SizedBox(height: 8),
          _bodyText(
            'Notre équipe est disponible pour répondre à toutes vos questions.',
          ),
          const SizedBox(height: 20),
          _contactCard(
            Icons.mail_rounded,
            AppTheme.teal50,
            AppTheme.primary,
            'Email',
            'contact@sendprocolis.com',
            'Réponse sous 24h ouvrées',
          ),
          const SizedBox(height: 12),
          _contactCard(
            Icons.call_rounded,
            AppTheme.green50,
            AppTheme.green600,
            'Téléphone',
            '+221 XX XXX XX XX',
            'Lun - Sam, 8h - 20h',
          ),
          const SizedBox(height: 12),
          _contactCard(
            Icons.location_on_rounded,
            AppTheme.amber50,
            AppTheme.amber500,
            'Adresse',
            'Sacré-Cœur 3, Dakar, Sénégal',
            'Sur rendez-vous',
          ),
          const SizedBox(height: 28),
          _sectionTitle('Formulaire de contact'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border.all(color: AppTheme.slate200),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Votre nom'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.slate200),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    color: AppTheme.backgroundColor,
                  ),
                  child: Text(
                    'Votre nom complet',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _fieldLabel('Votre email'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.slate200),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    color: AppTheme.backgroundColor,
                  ),
                  child: Text(
                    'votre@email.com',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _fieldLabel('Sujet'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.slate200),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    color: AppTheme.backgroundColor,
                  ),
                  child: Text(
                    'Sujet de votre message',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _fieldLabel('Message'),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.slate200),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    color: AppTheme.backgroundColor,
                  ),
                  child: Text(
                    'Décrivez votre demande...',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.slate400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: null,
                    child: const Text('Envoyer le message'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('Horaires'),
          const SizedBox(height: 12),
          _bodyText('Lundi — Vendredi : 8h00 - 20h00'),
          _bodyText('Samedi : 9h00 - 18h00'),
          _bodyText('Dimanche : Support d\'urgence uniquement (chat).'),
          const SizedBox(height: 8),
          _bodyText(
            'Les demandes reçues en dehors des horaires sont traitées le jour '
            'ouvré suivant.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _contactCard(
    IconData icon,
    Color bgColor,
    Color iconColor,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
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
