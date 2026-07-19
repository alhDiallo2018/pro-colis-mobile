import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

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
      bottomNavigationBar: const AppBottomNav(),
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
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Rechercher une question...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 20),
          const PcSectionHeader('Catégories'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleTopics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              return _HelpTopicCard(topic: visibleTopics[index]);
            },
          ),
          const SizedBox(height: 20),
          const PcSectionHeader('Questions fréquentes'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (visibleFaqs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'Aucun résultat pour cette recherche.',
                      style: GoogleFonts.manrope(
                        color: AppTheme.slate500,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < visibleFaqs.length; i++) ...[
                    if (i > 0) const PcDivider(),
                    _FaqTile(item: visibleFaqs[i]),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          PcCard(
            color: AppTheme.teal50,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Besoin d’aide ?',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Notre équipe répond 7j/7',
                        style: GoogleFonts.manrope(
                          color: AppTheme.slate600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PcButton(
                  'Contacter',
                  icon: Icons.chat_rounded,
                  size: PcButtonSize.sm,
                  onPressed: () => _showContactSheet(context),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
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
                const SizedBox(height: 12),
                const PcListRow(
                  icon: Icons.chat_bubble_rounded,
                  iconTone: PcTone.primary,
                  title: 'Chat support',
                  subtitle: 'Réponse moyenne : 5 min',
                  chevron: true,
                ),
                const PcDivider(),
                const PcListRow(
                  icon: Icons.call_rounded,
                  iconTone: PcTone.green,
                  title: 'Appeler le support',
                  subtitle: '+225 07 11 45 90',
                  chevron: true,
                ),
                const PcDivider(),
                const PcListRow(
                  icon: Icons.mail_rounded,
                  iconTone: PcTone.amber,
                  title: 'Envoyer un e-mail',
                  subtitle: 'support-technic@sendprocolis.com',
                  chevron: true,
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
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(topic.icon, color: AppTheme.primary, size: 22),
          ),
          const Spacer(),
          Text(
            topic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 13.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
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
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                widget.item.answer,
                style: GoogleFonts.manrope(
                  color: AppTheme.slate600,
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
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
