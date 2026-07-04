import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _topics = [
    _HelpTopic(Icons.inventory_2_rounded, 'Créer et envoyer un colis'),
    _HelpTopic(Icons.sell_rounded, 'Libre service et offres'),
    _HelpTopic(Icons.qr_code_2_rounded, 'Suivi et livraison'),
    _HelpTopic(Icons.account_balance_wallet_rounded, 'Points et paiements'),
    _HelpTopic(Icons.shield_rounded, 'Sécurité et litiges'),
    _HelpTopic(Icons.person_rounded, 'Mon compte'),
  ];

  static const _faqs = [
    _FaqItem(
      'Comment fonctionne le libre service ?',
      'Vous publiez votre colis, des chauffeurs vérifiés font des offres, vous acceptez celle qui vous convient.',
    ),
    _FaqItem(
      'Que se passe-t-il à la livraison ?',
      'Le destinataire communique un code PIN au chauffeur pour confirmer la remise du colis.',
    ),
    _FaqItem(
      'Comment sont calculés les points ?',
      'Chaque colis livré crédite des points utilisables en réductions sur vos prochains envois.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTopics = _topics.where((topic) {
      return topic.title.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    final visibleFaqs = _faqs.where((faq) {
      final q = _query.toLowerCase();
      return faq.question.toLowerCase().contains(q) ||
          faq.answer.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Aide & support'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(
              hintText: 'Rechercher une question...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          const ProcolisSectionHeader(title: 'Catégories'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleTopics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) {
              return _HelpTopicCard(topic: visibleTopics[index]);
            },
          ),
          const SizedBox(height: 18),
          const ProcolisSectionHeader(title: 'Questions fréquentes'),
          ProcolisCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (visibleFaqs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Aucun résultat pour cette recherche.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < visibleFaqs.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: AppTheme.slate200),
                    _FaqTile(item: visibleFaqs[i]),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          ProcolisCard(
            color: AppTheme.primaryLight,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity( 0.78),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppTheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Besoin d’aide ?',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Notre équipe répond 7j/7',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showContactSheet(context),
                  icon: const Icon(Icons.chat_rounded, size: 17),
                  label: const Text('Contacter'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const _SupportRow(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Chat support',
                  subtitle: 'Réponse moyenne : 5 min',
                ),
                const Divider(height: 1, color: AppTheme.slate200),
                const _SupportRow(
                  icon: Icons.call_rounded,
                  title: 'Appeler le support',
                  subtitle: '+225 07 11 45 90',
                ),
                const Divider(height: 1, color: AppTheme.slate200),
                const _SupportRow(
                  icon: Icons.mail_rounded,
                  title: 'Envoyer un e-mail',
                  subtitle: 'support@procolis.ci',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HelpTopic {
  final IconData icon;
  final String title;

  const _HelpTopic(this.icon, this.title);
}

class _HelpTopicCard extends StatelessWidget {
  final _HelpTopic topic;

  const _HelpTopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(topic.icon, color: AppTheme.primary, size: 22),
          ),
          const Spacer(),
          Text(
            topic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}

class _FaqTile extends StatefulWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              widget.item.answer,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
        ),
      ],
    );
  }
}

class _SupportRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SupportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
