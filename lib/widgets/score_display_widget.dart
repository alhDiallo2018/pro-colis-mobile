// lib/widgets/score_display_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../providers/public_config_provider.dart';
import '../providers/score_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Garde anti double-tap au niveau du widget (l'idempotence réelle reste
/// garantie par le backend / IPN PayDunya).
bool _purchaseInFlight = false;

class ScoreDisplayWidget extends ConsumerWidget {
  const ScoreDisplayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final scoreState = ref.watch(scoreProvider);
    final user = authState.user;

    // Le chargement automatique ne doit se faire qu'une seule fois: si l'API
    // répond en erreur, relancer ici à chaque build provoque un clignotement.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null &&
          scoreState.score == null &&
          !scoreState.isLoading &&
          !scoreState.hasAttemptedLoad) {
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

    // Un solde de points inconnu (erreur réseau / réponse invalide) n'est
    // jamais présenté comme « 0 pts » : on affiche un tiret explicite.
    final score = scoreState.score;
    final pointsText =
        score != null ? '${score.points} pts' : '— pts';

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
              pointsText,
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
      backgroundColor: AppTheme.cardColor,
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
                          score != null
                              ? '${score.points} points'
                              : 'Solde indisponible',
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
    // Contexte racine (celui de l'écran) conservé pour la suite de l'achat :
    // le contexte du dialog devient invalide dès que celui-ci est fermé.
    final rootContext = context;
    // Le prix unitaire du point provient de la configuration publique
    // (`score.cfaPerPoint`), jamais d'une valeur codée en dur.
    final cfaPerPoint = ref.read(publicConfigProvider)?.cfaPerPoint ?? 1.0;

    showDialog(
      context: context,
      builder: (context) {
        // État local pour le montant et le prix total.
        int amount = 0;
        double totalPrice = 0;

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
                          '1 point = ${cfaPerPoint.toStringAsFixed(cfaPerPoint == cfaPerPoint.roundToDouble() ? 0 : 2)} FCFA',
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
                    // Mise à jour automatique du prix total à chaque saisie.
                    onChanged: (value) {
                      final parsedAmount = int.tryParse(value) ?? 0;
                      final calculatedTotal = parsedAmount * cfaPerPoint;
                      setState(() {
                        amount = parsedAmount;
                        totalPrice = calculatedTotal;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Affichage du prix total.
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
                              _purchasePoints(rootContext, ref, amount);
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
  ) async {
    if (_purchaseInFlight) return;
    _purchaseInFlight = true;

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) {
      _purchaseInFlight = false;
      return;
    }

    final api = ApiService();
    final messenger = ScaffoldMessenger.of(context);

    BuildContext? loadingContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Création du paiement...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // 1. Création de la facture PayDunya (type "score") : le backend calcule
      //    le montant à partir de `score.cfaPerPoint`. Aucun crédit local.
      final payment = await api.createPaydunyaPayment('score', points: amount);
      if (loadingContext != null && loadingContext!.mounted) {
        Navigator.pop(loadingContext!);
      }

      final paymentUrl = payment['paymentUrl']?.toString() ?? '';
      final token = payment['token']?.toString() ?? '';
      if (paymentUrl.isEmpty || token.isEmpty) {
        throw StateError(
          payment['message']?.toString() ??
              'Impossible de créer le paiement PayDunya',
        );
      }

      // 2. Ouverture de la page de paiement.
      final launched = await launchUrl(
        Uri.parse(paymentUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Impossible d’ouvrir la page de paiement PayDunya');
      }

      // 3. Confirmation : seuls le backend / l'IPN créditent les points. Le
      //    mobile ne simule jamais une réussite et ne crédite jamais localement.
      final confirm = await api.confirmPaydunyaPayment(token);
      if (!context.mounted) return;

      if (confirm['status'] == 'completed') {
        await ref
            .read(scoreProvider.notifier)
            .loadScore(user.id);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Paiement confirmé. Vos points ont été crédités.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Paiement ouvert. Vos points seront crédités après confirmation.',
            ),
            backgroundColor: Colors.amber.shade700,
          ),
        );
      }
    } catch (error, stackTrace) {
      if (loadingContext != null && loadingContext!.mounted) {
        Navigator.pop(loadingContext!);
      }
      debugPrint(
        'ScoreDisplayWidget: achat de points impossible '
        '($error)\n$stackTrace',
      );
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l’achat de points. Veuillez réessayer.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _purchaseInFlight = false;
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
