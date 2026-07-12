import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_provider.dart';
import 'procolis_design_system.dart';

/// Barre de navigation persistante réutilisable sur toutes les pages.
///
/// Elle reprend les onglets du dashboard du rôle courant. Au tap, elle revient
/// au dashboard racine (dépile toutes les pages poussées) et sélectionne
/// l'onglet correspondant via [dashboardTabProvider].
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role ?? UserRole.client;
    final items = _itemsFor(role);
    final current = ref.watch(dashboardTabProvider);
    final safeIndex = (current >= 0 && current < items.length) ? current : 0;

    return ProcolisTabBar(
      items: items,
      currentIndex: safeIndex,
      onTap: (index) {
        try {
          ref.read(dashboardTabProvider.notifier).state = index;
          // If this screen was pushed via Navigator.push (not GoRouter),
          // pop it first so GoRouter navigation can work properly.
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
          final router = GoRouter.maybeOf(context);
          if (router != null) {
            router.go('/dashboard');
          } else {
            debugPrint('❌ [AppBottomNav] GoRouter not found');
          }
        } catch (e) {
          debugPrint('❌ [AppBottomNav] Navigation error: $e');
        }
      },
    );
  }

  List<ProcolisTabItem> _itemsFor(UserRole role) {
    switch (role) {
      case UserRole.driver:
        return const [
          ProcolisTabItem(icon: Icons.dashboard_rounded, label: 'Tableau'),
          ProcolisTabItem(icon: Icons.sell_rounded, label: 'À prendre'),
          ProcolisTabItem(
              icon: Icons.local_shipping_rounded, label: 'Missions'),
          ProcolisTabItem(icon: Icons.campaign_rounded, label: 'Annonces'),
          ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ];
      case UserRole.admin:
        return const [
          ProcolisTabItem(
              icon: Icons.pending_actions_rounded, label: 'En attente'),
          ProcolisTabItem(icon: Icons.people_rounded, label: 'Chauffeurs'),
          ProcolisTabItem(
              icon: Icons.local_shipping_rounded, label: 'En cours'),
          ProcolisTabItem(icon: Icons.history_rounded, label: 'Historique'),
        ];
      case UserRole.superAdmin:
        return const [
          ProcolisTabItem(icon: Icons.dashboard_rounded, label: 'Tableau'),
          ProcolisTabItem(icon: Icons.group_rounded, label: 'Utilisateurs'),
          ProcolisTabItem(icon: Icons.garage_rounded, label: 'Zones'),
          ProcolisTabItem(icon: Icons.notifications_rounded, label: 'Alertes'),
          ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ];
      case UserRole.client:
      default:
        return const [
          ProcolisTabItem(icon: Icons.home_rounded, label: 'Accueil'),
          ProcolisTabItem(icon: Icons.inventory_2_rounded, label: 'Mes colis'),
          ProcolisTabItem(
              icon: Icons.qr_code_scanner_rounded, label: 'Suivi'),
          ProcolisTabItem(icon: Icons.sell_rounded, label: 'Libre service'),
          ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ];
    }
  }
}
