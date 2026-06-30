// lib/widgets/score_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/score_provider.dart';

class ScoreDisplayWidget extends ConsumerWidget {
  const ScoreDisplayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final scoreState = ref.watch(scoreProvider);
    final user = authState.user;

    // Charger le score si l'utilisateur est connecté et que le score n'est pas chargé
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null && scoreState.score == null && !scoreState.isLoading) {
        ref.read(scoreProvider.notifier).loadScore(user.id);
      }
    });

    if (scoreState.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B6E3A)),
          ),
        ),
      );
    }

    final points = scoreState.score?.points ?? 0;

    return GestureDetector(
      onTap: () {
        _showPointsModal(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B6E3A), Color(0xFF0D8C46)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B6E3A).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars_rounded,
              color: Colors.amber,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '$points pts',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showPointsModal(BuildContext context, WidgetRef ref) {
    final scoreState = ref.watch(scoreProvider);
    final score = scoreState.score;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mes Points',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2B3C),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Solde
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B6E3A), Color(0xFF0D8C46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Solde actuel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${score?.points ?? 0} points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bouton Acheter des points
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPurchasePointsDialog(context, ref);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B6E3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Acheter des points',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Historique avec scroll
                  if (score?.transactions.isNotEmpty ?? false) ...[
                    const Text(
                      'Historique',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: score!.transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final transaction = score.transactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(transaction.timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${transaction.amount >= 0 ? '+' : ''}${transaction.amount}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: transaction.amount >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Aucune transaction pour le moment',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPurchasePointsDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController amountController = TextEditingController();
    // Prix par point (exemple: 100 FCFA par point)
    const pricePerPoint = 100;

    showDialog(
      context: context,
      builder: (context) {
        // ✅ État local pour le montant et le prix total
        int amount = 0;
        int totalPrice = 0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Acheter des points'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '1 point = $pricePerPoint FCFA',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nombre de points',
                      hintText: 'Ex: 10',
                      prefixIcon: const Icon(Icons.stars),
                      suffixText: 'pts',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0B6E3A), width: 1.5),
                      ),
                    ),
                    // ✅ Mise à jour automatique du prix total à chaque saisie
                    onChanged: (value) {
                      final parsedAmount = int.tryParse(value) ?? 0;
                      final calculatedTotal = parsedAmount * pricePerPoint;
                      setState(() {
                        amount = parsedAmount;
                        totalPrice = calculatedTotal;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // ✅ Affichage du prix total avec animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: amount > 0 ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: amount > 0 ? Colors.green.shade300 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total :',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '${totalPrice.toStringAsFixed(0)}',
                                key: ValueKey(totalPrice),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: amount > 0
                                      ? const Color(0xFF0B6E3A)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FCFA',
                              style: TextStyle(
                                fontSize: 14,
                                color: amount > 0 ? Colors.grey.shade700 : Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ✅ Indicateur de points bonus (si achat > 50 points)
                  if (amount >= 50)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '🎁 Bonus: +${(amount * 0.1).round()} points offerts !',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    return ElevatedButton(
                      onPressed: amount > 0
                          ? () {
                              Navigator.pop(context);
                              final bonusPoints = amount >= 50 ? (amount * 0.1).round() : 0;
                              final totalPoints = amount + bonusPoints;
                              _purchasePoints(context, ref, amount, totalPoints, totalPrice);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B6E3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: const Text('Acheter'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _purchasePoints(
    BuildContext context,
    WidgetRef ref,
    int amount,
    int totalPoints,
    int totalPrice,
  ) async {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user == null) return;

    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Traitement en cours...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Simuler un délai de paiement (à remplacer par un vrai appel API)
      await Future.delayed(const Duration(seconds: 1));

      // Créditer les points
      final success = await ref.read(scoreProvider.notifier).creditPoints(
            user.id,
            totalPoints,
            'Achat de $amount points (${amount >= 50 ? "+${totalPoints - amount} bonus" : ""}) - $totalPrice FCFA',
          );

      // Fermer l'indicateur de chargement
      if (context.mounted) Navigator.pop(context);

      if (success && context.mounted) {
        // Recharger le score pour mettre à jour l'affichage
        await ref.read(scoreProvider.notifier).loadScore(user.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ $totalPoints points ajoutés avec succès !'),
                if (totalPoints > amount)
                  Text(
                    '🎁 Bonus de ${totalPoints - amount} points offerts !',
                    style: const TextStyle(fontSize: 12),
                  ),
                Text(
                  '💰 Total: $totalPrice FCFA',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'achat de points.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}