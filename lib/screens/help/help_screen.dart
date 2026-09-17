import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/public_config.dart';
import '../../providers/public_config_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

/// Contenu d'aide affiché en secours lorsque la configuration publique
/// (`/public/config`) n'est pas encore disponible ou ne renvoie pas de
/// catégories/questions : l'écran ne doit jamais apparaître vide.
const _defaultTopics = <HelpTopic>[
  HelpTopic(icon: 'inventory', title: 'Créer et envoyer un colis'),
  HelpTopic(icon: 'sell', title: 'Libre service et offres'),
  HelpTopic(icon: 'qr_code', title: 'Suivi et livraison'),
  HelpTopic(icon: 'wallet', title: 'Points et paiements'),
  HelpTopic(icon: 'shield', title: 'Sécurité et litiges'),
  HelpTopic(icon: 'person', title: 'Mon compte'),
];

const _defaultFaqs = <HelpFaq>[
  HelpFaq(
    question: 'Comment fonctionne le libre service ?',
    answer:
        'Vous publiez votre colis, des chauffeurs vérifiés font des offres, vous acceptez celle qui vous convient.',
  ),
  HelpFaq(
    question: 'Que se passe-t-il à la livraison ?',
    answer:
        'Le destinataire communique un code PIN au chauffeur pour confirmer la remise du colis.',
  ),
  HelpFaq(
    question: 'Comment sont calculés les points ?',
    answer:
        'Chaque colis livré crédite des points utilisables en réductions sur vos prochains envois.',
  ),
  HelpFaq(
    question: 'Comment payer mes envois ?',
    answer:
        'Vous pouvez payer par carte, Orange Money, Wave, Free Money ou en espèces. Le paiement est débité une fois le colis livré.',
  ),
  HelpFaq(
    question: 'Comment suivre mon colis ?',
    answer:
        'Connectez-vous à votre compte et allez dans « Suivi ». Entrez votre numéro de suivi pour voir les statuts en temps réel.',
  ),
  HelpFaq(
    question: 'Puis-je annuler un colis ?',
    answer:
        'Oui, vous pouvez annuler un colis tant qu\'il n\'a pas encore été confirmé par un chauffeur. Au-delà, contactez notre support.',
  ),
  HelpFaq(
    question: 'Comment devenir chauffeur ?',
    answer:
        'Créez un compte en sélectionnant le rôle « Conduire », remplissez votre profil, ajoutez vos documents et votre véhicule. Notre équipe vérifiera vos informations.',
  ),
  HelpFaq(
    question: 'Comment sont protégés mes paiements ?',
    answer:
        'Tous les paiements sont sécurisés via PayDunya. Les fonds sont conservés sur un compte séquestre jusqu\'à la confirmation de livraison.',
  ),
  HelpFaq(
    question: 'Que faire en cas de colis endommagé ?',
    answer:
        'Contactez notre support dans les 48 heures avec des photos du colis et votre numéro de suivi. Nous traiterons votre réclamation rapidement.',
  ),
];

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Les catégories et questions proviennent de la configuration publique
  /// (administration API). Si celle-ci est indisponible ou vide, un contenu de
  /// secours est affiché afin que l'écran ne reste jamais vide.
  List<HelpTopic> get _topics {
    final topics = ref.watch(publicConfigProvider)?.helpTopics;
    return (topics == null || topics.isEmpty) ? _defaultTopics : topics;
  }

  List<HelpFaq> get _faqs {
    final faqs = ref.watch(publicConfigProvider)?.helpFaqs;
    return (faqs == null || faqs.isEmpty) ? _defaultFaqs : faqs;
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
        shape: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            style: AppFonts.manrope(
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
                      style: AppFonts.manrope(
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
                  child: Icon(
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
                        style: AppFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _availabilityLabel,
                        style: AppFonts.manrope(
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
    final config = ref.read(publicConfigProvider);
    final phone = config?.displayTechnicalPhone ?? '';
    final email = config?.displayTechnicalEmail ?? '';
    final responseTime = config?.displaySupportResponseTime ?? '';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/support');
                  },
                  child: PcListRow(
                    icon: Icons.chat_bubble_rounded,
                    iconTone: PcTone.primary,
                    title: 'Chat support',
                    subtitle: responseTime.isNotEmpty
                        ? 'Réponse moyenne : $responseTime'
                        : null,
                    chevron: true,
                  ),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.call_rounded,
                  iconTone: PcTone.green,
                  title: 'Appeler le support',
                  subtitle: phone.isEmpty ? 'Numéro indisponible' : phone,
                  chevron: true,
                  onTap: phone.isEmpty ? null : () => _launchPhone(phone),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.mail_rounded,
                  iconTone: PcTone.amber,
                  title: 'Envoyer un e-mail',
                  subtitle: email.isEmpty ? 'E-mail indisponible' : email,
                  chevron: true,
                  onTap: email.isEmpty ? null : () => _launchEmail(email),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _availabilityLabel {
    final availability = ref.watch(publicConfigProvider)?.displaySupportAvailability;
    if (availability == null || availability.isEmpty) {
      return 'Notre équipe est disponible pour vous assister';
    }
    return 'Notre équipe répond $availability';
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showSnack('Appel impossible depuis cet appareil');
      }
    } catch (_) {
      if (mounted) _showSnack('Appel impossible');
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showSnack('Messagerie indisponible sur cet appareil');
      }
    } catch (_) {
      if (mounted) _showSnack('Impossible d\'ouvrir la messagerie');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

IconData _helpIcon(String key) {
  switch (key.trim().toLowerCase()) {
    case 'inventory':
      return Icons.inventory_2_rounded;
    case 'sell':
      return Icons.sell_rounded;
    case 'qr_code':
    case 'tracking':
      return Icons.qr_code_2_rounded;
    case 'wallet':
    case 'payment':
      return Icons.account_balance_wallet_rounded;
    case 'shield':
    case 'security':
      return Icons.shield_rounded;
    case 'person':
    case 'account':
      return Icons.person_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

class _HelpTopicCard extends StatelessWidget {
  final HelpTopic topic;

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
            child: Icon(_helpIcon(topic.icon), color: AppTheme.primary, size: 22),
          ),
          const Spacer(),
          Text(
            topic.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.plusJakartaSans(
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

class _FaqTile extends StatefulWidget {
  final HelpFaq item;

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
                    style: AppFonts.plusJakartaSans(
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
                  child: Icon(
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
                style: AppFonts.manrope(
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
