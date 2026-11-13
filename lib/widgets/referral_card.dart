import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api/client.dart';
import '../services/api/referral_api.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';
import 'referral_invite_card.dart';

/// Carte « Invitez vos proches » à insérer dans l'écran profil. Masquée
/// silencieusement si le backend n'a pas pu fournir un code.
class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  String? _code;
  ReferralRewards? _rewards;
  bool _loading = true;
  late final ReferralApi _api;

  @override
  void initState() {
    super.initState();
    _api = ReferralApi(ApiClient());
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.fetchMyReferralCode(),
      _api.fetchRewards(),
    ]);
    if (!mounted) return;
    setState(() {
      _code = results[0] as String?;
      _rewards = results[1] as ReferralRewards?;
      _loading = false;
    });
  }

  String _formatAmount(double amount, String? currency) {
    final formatted = NumberFormat.decimalPattern('fr').format(amount.round());
    final unit = currency == null || currency.isEmpty ? 'FCFA' : currency;
    return '$formatted $unit';
  }

  Future<void> _copy() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code $code copié'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _share() async {
    final code = _code;
    if (code == null) return;
    await shareReferralCode(context, code);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final code = _code;
    if (code == null) return const SizedBox.shrink();

    final rewards = _rewards;
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Invitez vos proches',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Partagez votre code. Vous recevez un bonus à chaque première livraison de vos filleuls.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier',
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
          if (rewards != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _RewardStat(
                  label: 'Filleuls confirmés',
                  value: '${rewards.confirmedInvites}/${rewards.totalInvites}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RewardStat(
                  label: 'Bonus accumulé',
                  value:
                      _formatAmount(rewards.bonusEarned, rewards.currency),
                  tone: AppTheme.successColor,
                ),
              ),
            ]),
            if (rewards.bonusAvailable > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.amber50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.redeem_rounded,
                      size: 20, color: AppTheme.amber700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_formatAmount(rewards.bonusAvailable, rewards.currency)} disponibles pour votre prochain envoi',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.amber700),
                    ),
                  ),
                ]),
              ),
            ],
          ],
          const SizedBox(height: 12),
          PcButton(
            'Partager mon code',
            onPressed: _share,
            icon: Icons.share_rounded,
            block: true,
          ),
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? tone;
  const _RewardStat({required this.label, required this.value, this.tone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tone ?? AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
