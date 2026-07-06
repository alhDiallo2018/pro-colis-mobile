import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

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
          _BalanceHero(points: points),
          const SizedBox(height: 18),
          // Le rechargement de points est réservé aux chauffeurs. Côté client,
          // les points se gagnent (livraisons) et se dépensent en réductions.
          PcButton(
            'Utiliser mes points',
            icon: Icons.redeem_rounded,
            variant: PcButtonVariant.secondary,
            size: PcButtonSize.lg,
            block: true,
            onPressed: () => _showComingSoon(context, 'Utilisation des points'),
          ),
          const SizedBox(height: 18),
          const PcSectionHeader('Historique'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const [
                _WalletTxnRow(
                  icon: Icons.task_alt_rounded,
                  iconTone: PcTone.green,
                  title: 'Livraison validée',
                  subtitle: 'Aujourd’hui · PC-7F3K-2291',
                  amount: '+150 pts',
                  positive: true,
                ),
                PcDivider(),
                _WalletTxnRow(
                  icon: Icons.add_card_rounded,
                  iconTone: PcTone.primary,
                  title: 'Recharge de points',
                  subtitle: 'Hier · Orange Money',
                  amount: '+1 000',
                  positive: true,
                ),
                PcDivider(),
                _WalletTxnRow(
                  icon: Icons.redeem_rounded,
                  iconTone: PcTone.amber,
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
      bottomNavigationBar: const AppBottomNav(),
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

class _BalanceHero extends StatelessWidget {
  final int points;

  const _BalanceHero({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.amberGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.amberShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SOLDE DE POINTS',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.amberOnFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.amberOnFg,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: WalletScreen._formatPoints(points),
              children: const [
                TextSpan(text: ' pts', style: TextStyle(fontSize: 18)),
              ],
            ),
            style: AppTheme.mono(
              color: AppTheme.amberOnFg,
              fontSize: 38,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${WalletScreen._formatPoints(points * 10)} FCFA de réductions disponibles',
            style: GoogleFonts.manrope(
              color: AppTheme.amberOnFg.withOpacity(0.8),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          PcCard(
            color: AppTheme.slate100,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total à payer',
                    style: GoogleFonts.plusJakartaSans(
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PcButton(
            'Payer maintenant',
            icon: Icons.lock_rounded,
            size: PcButtonSize.lg,
            block: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

class _WalletTxnRow extends StatelessWidget {
  final IconData icon;
  final PcTone iconTone;
  final String title;
  final String subtitle;
  final String amount;
  final bool positive;

  const _WalletTxnRow({
    required this.icon,
    required this.iconTone,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return PcListRow(
      icon: icon,
      iconTone: iconTone,
      title: title,
      subtitle: subtitle,
      trailing: Text(
        amount,
        style: AppTheme.mono(
          color: positive ? AppTheme.successColor : AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WalletLabel extends StatelessWidget {
  final String text;

  const _WalletLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w700,
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
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.subtitle,
                    style: GoogleFonts.manrope(
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
