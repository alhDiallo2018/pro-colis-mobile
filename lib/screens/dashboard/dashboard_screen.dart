import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/screens/dashboard/garage_admin_dashboard.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
// ignore: unused_import
import '../../providers/parcel_provider.dart';
// ignore: unused_import
// ignore: unused_import
import '../parcel/track_parcel_screen.dart';
// ignore: unused_import
import '../profile/profile_screen.dart';
import 'client_dashboard.dart';
import 'driver_dashboard.dart';
import 'super_admin_dashboard.dart';
import 'support_admin_dashboard.dart';
import 'support_commercial_dashboard.dart';
import 'support_technique_dashboard.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Utilisateur non trouvé')),
      );
    }
    
    // Rediriger vers le dashboard selon le rôle. Le `switch` est exhaustif
    // sans `default` : ajouter un rôle sans son dashboard devient une erreur de
    // compilation plutôt qu'une redirection silencieuse vers l'espace client.
    switch (user.role) {
      case UserRole.client:
        return const ClientDashboard();
      case UserRole.driver:
        return const DriverDashboard();
      case UserRole.admin:
        return const GarageAdminDashboard();
      case UserRole.supportTechnique:
        return const SupportTechniqueDashboard();
      case UserRole.supportCommercial:
        return const SupportCommercialDashboard();
      case UserRole.support:
        return const SupportAdminDashboard();
      case UserRole.superAdmin:
        return const SuperAdminDashboard();
    }
  }
}