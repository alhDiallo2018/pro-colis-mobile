import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api/client.dart';
import '../services/api/referral_api.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

/// Carte « Invitez vos proches » à insérer dans l'écran profil. Masquée
/// silencieusement si le backend n'a pas pu fournir un code.
class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  String? _code;
  bool _loading = true;
  late final ReferralApi _api;

  @override
  void initState() {
    super.initState();
    _api = ReferralApi(ApiClient());
    _load();
  }

  Future<void> _load() async {
    final code = await _api.fetchMyReferralCode();
    if (!mounted) return;
    setState(() {
      _code = code;
      _loading = false;
    });
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
    await Share.share(
      "Rejoignez-moi sur SendProColis avec mon code $code "
      "— vous bénéficierez d'un bonus à votre première livraison.",
    );
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
