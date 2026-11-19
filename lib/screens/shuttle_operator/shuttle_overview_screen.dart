// lib/screens/shuttle_operator/shuttle_overview_screen.dart
//
// SCP-007 — Vue d'ensemble de l'espace opérateur : compteurs lignes, flotte,
// horaires actifs. Consomme `GET /shuttle-operator/overview` via le provider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/shuttle_operator_provider.dart';

class ShuttleOverviewScreen extends ConsumerWidget {
  const ShuttleOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shuttleOverviewProvider);
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opérateur navette'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(shuttleOverviewProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shuttleOverviewProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorState(message: err.toString(), onRetry: () => ref.invalidate(shuttleOverviewProvider)),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(child: Text(user.initials)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                              Text('Opérateur · ${user.phone}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  _StatTile(label: 'Lignes', value: data.lineCount, icon: Icons.route, color: Colors.indigo),
                  _StatTile(label: 'Véhicules', value: data.vehicleCount, icon: Icons.directions_bus, color: Colors.teal),
                  _StatTile(label: 'Dispo', value: data.availableVehicleCount, icon: Icons.check_circle, color: Colors.green),
                  _StatTile(label: 'Horaires', value: data.scheduleCount, icon: Icons.schedule, color: Colors.deepPurple),
                  _StatTile(label: 'Actifs', value: data.activeScheduleCount, icon: Icons.event_available, color: Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withValues(alpha: 0.2))),
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('Chargement impossible', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
