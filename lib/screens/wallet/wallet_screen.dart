import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const int points = 2450;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Points & paiements'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.amberGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.amber500.withOpacity( 0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SOLDE DE POINTS',
                        style: TextStyle(
                          color: Color(0xFF3A2600),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF3A2600),
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: _formatPoints(points),
                    children: const [
                      TextSpan(
                        text: ' pts',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  style: AppTheme.mono(
                    color: const Color(0xFF3A2600),
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '≈ 24 500 FCFA de réductions disponibles',
                  style: TextStyle(
                    color: Color(0xCC3A2600),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TopUpScreen()),
                  ),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Recharger'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showComingSoon(context, 'Utilisation des points'),
                  icon: const Icon(Icons.redeem_rounded),
                  label: const Text('Utiliser'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const ProcolisSectionHeader(title: 'Historique'),
          ProcolisCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const [
                _WalletTxnRow(
                  icon: Icons.task_alt_rounded,
                  iconColor: AppTheme.green700,
                  iconBg: AppTheme.green50,
                  title: 'Livraison validée',
                  subtitle: 'Aujourd’hui · PC-7F3K-2291',
                  amount: '+150 pts',
                  positive: true,
                ),
                _WalletDivider(),
                _WalletTxnRow(
                  icon: Icons.add_card_rounded,
                  iconColor: AppTheme.primary,
                  iconBg: AppTheme.teal50,
                  title: 'Recharge de points',
                  subtitle: 'Hier · Orange Money',
                  amount: '+1 000',
                  positive: true,
                ),
                _WalletDivider(),
                _WalletTxnRow(
                  icon: Icons.redeem_rounded,
                  iconColor: AppTheme.amber700,
                  iconBg: AppTheme.amber50,
                  title: 'Réduction appliquée',
                  subtitle: '24/06 · Livraison Abidjan',
                  amount: '-300',
                  positive: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPoints(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }

  static void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label bientôt disponible'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  String _amount = '1000';
  String _method = 'om';

  static const _presets = ['500', '1000', '2500', '5000'];
  static const _methods = [
    _PaymentMethod(
        'om', Icons.smartphone_rounded, 'Orange Money', '+225 07 11 45 90'),
    _PaymentMethod('momo', Icons.smartphone_rounded, 'MTN MoMo', 'Compte lié'),
    _PaymentMethod('card', Icons.credit_card_rounded, 'Carte bancaire',
        'Visa · Mastercard'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Recharger'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
        children: [
          const _WalletLabel('Montant'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final preset in _presets)
                _AmountButton(
                  amount: preset,
                  selected: _amount == preset,
                  onTap: () => setState(() => _amount = preset),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const _WalletLabel('Moyen de paiement'),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final method in _methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaymentMethodTile(
                    method: method,
                    selected: _method == method.key,
                    onTap: () => setState(() => _method = method.key),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ProcolisCard(
            color: AppTheme.slate100,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total à payer',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${WalletScreen._formatPoints(int.parse(_amount))} FCFA',
                  style: AppTheme.mono(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Payer maintenant'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
          ),
        ],
      ),
    );
  }
}

class _WalletTxnRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String amount;
  final bool positive;

  const _WalletTxnRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTheme.mono(
              color: positive ? AppTheme.successColor : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletDivider extends StatelessWidget {
  const _WalletDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 66, color: AppTheme.slate200);
  }
}

class _WalletLabel extends StatelessWidget {
  final String text;

  const _WalletLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  const _AmountButton({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          amount,
          style: AppTheme.mono(
            color: selected ? AppTheme.teal700 : AppTheme.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PaymentMethod {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;

  const _PaymentMethod(this.key, this.icon, this.title, this.subtitle);
}

class _PaymentMethodTile extends StatelessWidget {
  final _PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(method.icon, color: AppTheme.primary, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.slate300,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
