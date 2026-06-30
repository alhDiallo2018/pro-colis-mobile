// lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_logo.dart';
import 'register_client_screen.dart';
import 'register_driver_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryBlue.withAlpha(10),
                  shape: BoxShape.circle,
                ),
                child: const AppLogo(size: 60, isWhite: false),
              ),
              const SizedBox(height: 24),
              
              // Titre
              const Text(
                'Choisissez votre type de compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez le profil qui vous correspond',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              
              // Carte Client - BLEUE
              _buildRegisterCard(
                context: context,
                title: 'Client',
                subtitle: 'Envoyez et recevez vos colis',
                icon: Icons.person_outline,
                color: primaryBlue,
                gradientColors: [primaryBlue, secondaryBlue],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterClientScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Carte Chauffeur - BLEUE
              _buildRegisterCard(
                context: context,
                title: 'Chauffeur',
                subtitle: 'Devenez livreur partenaire',
                icon: Icons.local_taxi,
                color: primaryBlue,
                gradientColors: [primaryBlue, secondaryBlue],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterDriverScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Carte Admin Garage - BLEUE
              _buildRegisterCard(
                context: context,
                title: 'Admin Garage',
                subtitle: 'Gérez votre point de service',
                icon: Icons.business,
                color: primaryBlue,
                gradientColors: [primaryBlue, secondaryBlue],
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contactez l\'administrateur pour créer un compte admin'),
                      backgroundColor: Color(0xFF2563EB),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
              
              // Lien connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ? ',
                    style: TextStyle(color: textSecondary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryBlue,
                    ),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône avec dégradé
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}