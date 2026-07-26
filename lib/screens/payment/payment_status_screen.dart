import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

enum PaymentReturnStatus {
  success,
  pending,
  cancelled,
  unknown;

  static PaymentReturnStatus fromQuery(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'success' => PaymentReturnStatus.success,
      'pending' => PaymentReturnStatus.pending,
      'cancelled' || 'canceled' => PaymentReturnStatus.cancelled,
      _ => PaymentReturnStatus.unknown,
    };
  }
}

class PaymentStatusScreen extends StatelessWidget {
  final PaymentReturnStatus status;

  const PaymentStatusScreen({super.key, required this.status});

  ({IconData icon, Color color, String title, String message}) get _content =>
      switch (status) {
        PaymentReturnStatus.success => (
            icon: Icons.check_circle_rounded,
            color: AppTheme.green600,
            title: 'Paiement confirmé',
            message:
                'Votre paiement a été reçu. Le statut du colis va se mettre à jour.',
          ),
        PaymentReturnStatus.pending => (
            icon: Icons.schedule_rounded,
            color: AppTheme.amber600,
            title: 'Paiement en cours',
            message:
                'La confirmation est encore en attente. Vous pouvez revenir au colis et actualiser dans quelques instants.',
          ),
        PaymentReturnStatus.cancelled => (
            icon: Icons.cancel_rounded,
            color: AppTheme.red500,
            title: 'Paiement annulé',
            message:
                'Aucun débit n’a été confirmé. Vous pourrez relancer le paiement depuis le détail du colis.',
          ),
        PaymentReturnStatus.unknown => (
            icon: Icons.help_rounded,
            color: AppTheme.slate500,
            title: 'Statut indisponible',
            message:
                'Le retour du prestataire ne contient pas de statut reconnu.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final content = _content;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Retour de paiement')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PcCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(content.icon, size: 68, color: content.color),
                const SizedBox(height: 18),
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  content.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.slate500,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                PcButton(
                  'Retour au tableau de bord',
                  icon: Icons.dashboard_rounded,
                  block: true,
                  onPressed: () => context.go('/dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
