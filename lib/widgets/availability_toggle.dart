import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AvailabilityToggle extends ConsumerWidget {
  const AvailabilityToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final driverStatus = authState.user?.driverStatus;
    final statusValue = driverStatus?.value ?? 'offline';
    final available = statusValue == 'available';

    Color bgColor;
    Color dotColor;
    Color textColor;
    String label;

    switch (statusValue) {
      case 'available':
        bgColor = AppTheme.green50;
        dotColor = AppTheme.green500;
        textColor = AppTheme.green700;
        label = 'Disponible';
      case 'busy':
        bgColor = AppTheme.red50;
        dotColor = AppTheme.red400;
        textColor = AppTheme.red500;
        label = 'En livraison';
      default:
        bgColor = AppTheme.slate100;
        dotColor = AppTheme.slate400;
        textColor = AppTheme.slate500;
        label = 'Hors ligne';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 24,
            child: Switch.adaptive(
              value: available,
              activeThumbColor: AppTheme.green500,
              onChanged: (value) =>
                  _updateAvailability(context, ref, value),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAvailability(
    BuildContext context,
    WidgetRef ref,
    bool available,
  ) async {
    try {
      // Le rafraîchissement attend la confirmation du serveur afin que le
      // switch reflète toujours le statut réellement enregistré.
      final api = ApiService();
      await api.updateDriverStatus(available ? 'available' : 'offline');
      await ref.read(authProvider.notifier).refreshUser();
    } catch (error, stackTrace) {
      debugPrint(
        'AvailabilityToggle: mise à jour du statut impossible '
        '($error)\n$stackTrace',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de modifier votre disponibilité.'),
        ),
      );
    }
  }
}
