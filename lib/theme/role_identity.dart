// lib/theme/role_identity.dart
//
// Identité visuelle et éditoriale de chaque rôle.
//
// Un seul endroit décide comment un rôle se présente (libellé, accroche,
// icône, accent, dégradé du bandeau). Profils et dashboards y puisent, ce qui
// évite qu'un chauffeur et un agent support finissent par se ressembler à
// l'écran — et qu'un nouveau rôle oblige à retoucher dix fichiers.

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../widgets/pc_components.dart';
import 'app_theme.dart';

class RoleIdentity {
  /// Libellé court affiché en badge (ex. « Support technique »).
  final String label;

  /// Sur-titre du bandeau de dashboard (ex. « Espace support technique »).
  final String spaceName;

  /// Accroche : ce que le rôle vient faire dans l'application.
  final String tagline;

  /// Phrase d'accueil du dashboard.
  final String dashboardIntro;

  final IconData icon;
  final Color accent;

  /// Fond doux dérivé de l'accent, pour les pastilles d'icône.
  final Color accentSoft;

  /// Dégradé du bandeau d'en-tête.
  final LinearGradient gradient;

  /// Ton du design system utilisé pour les badges de ce rôle.
  final PcTone tone;

  const RoleIdentity({
    required this.label,
    required this.spaceName,
    required this.tagline,
    required this.dashboardIntro,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.gradient,
    required this.tone,
  });

  static RoleIdentity of(UserRole role) {
    switch (role) {
      case UserRole.client:
        return const RoleIdentity(
          label: 'Client',
          spaceName: 'Espace client',
          tagline: 'Expédiez, suivez et recevez vos colis',
          dashboardIntro: 'Envoyez un colis en quelques minutes',
          icon: Icons.inventory_2_rounded,
          accent: AppTheme.green600,
          accentSoft: AppTheme.green50,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.green500, AppTheme.teal500, AppTheme.deep500],
            stops: [0, 0.55, 1],
          ),
          tone: PcTone.green,
        );

      case UserRole.driver:
        return const RoleIdentity(
          label: 'Chauffeur',
          spaceName: 'Espace chauffeur',
          tagline: 'Vos missions, vos revenus, votre véhicule',
          dashboardIntro: 'Prenez la route et encaissez vos courses',
          icon: Icons.local_shipping_rounded,
          accent: AppTheme.teal500,
          accentSoft: AppTheme.teal50,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.teal400, AppTheme.teal500, AppTheme.teal800],
            stops: [0, 0.5, 1],
          ),
          tone: PcTone.primary,
        );

      case UserRole.admin:
        return const RoleIdentity(
          label: 'Admin zone',
          spaceName: 'Espace admin zone',
          tagline: 'Pilotez les colis et les chauffeurs de votre zone',
          dashboardIntro: 'Traitez les colis en attente de votre zone',
          icon: Icons.business_rounded,
          accent: AppTheme.amber600,
          accentSoft: AppTheme.amber50,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.amber400, AppTheme.amber500, AppTheme.amber700],
            stops: [0, 0.5, 1],
          ),
          tone: PcTone.amber,
        );

      case UserRole.supportTechnique:
        return const RoleIdentity(
          label: 'Support technique',
          spaceName: 'Espace support technique',
          tagline: 'Tickets, incidents et assistance aux utilisateurs',
          dashboardIntro: 'Vos tickets du jour et les incidents ouverts',
          icon: Icons.support_agent,
          accent: Color(0xFF7C3AED),
          accentSoft: Color(0xFFEFE7FB),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C3AED), Color(0xFF5B27B0), AppTheme.deep700],
            stops: [0, 0.55, 1],
          ),
          tone: PcTone.primary,
        );

      case UserRole.supportCommercial:
        return const RoleIdentity(
          label: 'Support commercial',
          spaceName: 'Espace support commercial',
          tagline: 'Prospects, partenaires et développement du réseau',
          dashboardIntro: 'Vos prospects à relancer et vos objectifs du mois',
          icon: Icons.handshake,
          accent: AppTheme.deep500,
          accentSoft: AppTheme.infoSoft,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.deep500, AppTheme.teal600, AppTheme.deep700],
            stops: [0, 0.55, 1],
          ),
          tone: PcTone.primary,
        );

      // Rôle `support` générique de l'enum Prisma : espace d'assistance
      // transverse, distinct des deux supports spécialisés. Ardoise neutre
      // pour ne pas le confondre avec le violet (technique) ni le bleu
      // profond (commercial).
      case UserRole.support:
        return const RoleIdentity(
          label: 'Support',
          spaceName: 'Espace support',
          tagline: 'Conversations, assistances et suivi des colis',
          dashboardIntro: 'Vos conversations et assistances à traiter',
          icon: Icons.headset_mic_rounded,
          accent: Color(0xFF475569),
          accentSoft: Color(0xFFE8ECF1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF475569), Color(0xFF334155), AppTheme.deep700],
            stops: [0, 0.55, 1],
          ),
          tone: PcTone.neutral,
        );

      case UserRole.superAdmin:
        return const RoleIdentity(
          label: 'Super Admin',
          spaceName: 'Espace super admin',
          tagline: 'Vue d\'ensemble et gouvernance de la plateforme',
          dashboardIntro: 'Gérez l\'ensemble de la plateforme',
          icon: Icons.admin_panel_settings_rounded,
          accent: AppTheme.red500,
          accentSoft: AppTheme.red50,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.green500, AppTheme.teal500, AppTheme.deep500],
            stops: [0, 0.55, 1],
          ),
          tone: PcTone.red,
        );
    }
  }
}

extension UserRoleIdentity on UserRole {
  RoleIdentity get identity => RoleIdentity.of(this);
}

extension UserIdentityExtension on User {
  RoleIdentity get identity => RoleIdentity.of(role);
}
