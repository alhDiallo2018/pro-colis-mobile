import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/theme/fonts.dart';

import '../../theme/app_theme.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cardColor,
      body: CustomScrollView(
        slivers: [
          _TopNav(),
          _HeroSection(),
          _StatsBand(),
          _HowItWorks(),
          _ExpressCallout(),
          _Footer(),
        ],
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      titleSpacing: 0,
      title: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Flexible(
              child: GestureDetector(
              onTap: () => context.go('/landing'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: AppFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2, color: AppTheme.slate900),
                        children: const [
                          TextSpan(text: 'PRO'),
                          TextSpan(text: 'COLIS', style: TextStyle(color: AppTheme.amber400)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
            const Spacer(),
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: Size.zero),
                child: const Text('Connexion', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: () => context.go('/register'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14), minimumSize: Size.zero),
                child: const Text('Inscription', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        padding: const EdgeInsets.only(top: 40, bottom: 48),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '» Livraison interurbaine & internationale',
                      style: AppFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Vos colis,\nde ville en ville,\npartout en Afrique.',
                    style: AppFonts.plusJakartaSans(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Déclarez un colis, fixez votre trajet et votre prix, publiez-le en annonce et laissez nos chauffeurs vérifiés vous faire leurs meilleures offres. Livraison au Sénégal et à l\'international, avec suivi en temps réel.',
                    style: AppFonts.manrope(
                      fontSize: 16,
                      height: 1.55,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/register'),
                        icon: const Icon(Icons.add_box, size: 20),
                        label: const Text('Envoyer un colis'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.amber400,
                          foregroundColor: AppTheme.amberOnFg,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          textStyle: AppFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/register'),
                        icon: const Icon(Icons.local_shipping, size: 20),
                        label: const Text('Devenir chauffeur'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          textStyle: AppFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _TrackingCard(),
          ],
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: const [
            BoxShadow(color: Color(0x38000000), blurRadius: 40, offset: Offset(0, 16)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suivez votre colis', style: AppFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Entrez votre numéro de suivi.', style: AppFonts.manrope(fontSize: 13.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.slate300),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2, size: 20, color: AppTheme.slate400),
                  const SizedBox(width: 8),
                  Text('PC-7F3K-2291', style: AppTheme.mono(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/track'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Suivre'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.slate200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.green50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.local_shipping, color: AppTheme.green700, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dakar → Thiès', style: AppFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        Text('En transit · arrive dans ~4 h', style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppTheme.teal50, borderRadius: BorderRadius.circular(99)),
                    child: Text('En transit', style: AppFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.teal600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBand extends StatelessWidget {
  static const stats = [
    {'value': '14 régions', 'label': "au Sénégal et à l'international", 'accent': false},
    {'value': '1 200+', 'label': 'chauffeurs vérifiés', 'accent': false},
    {'value': '45 min', 'label': "délai moyen avant 1ʳᵉ offre", 'accent': true},
    {'value': '98,4 %', 'label': 'colis livrés à temps', 'accent': false},
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: AppTheme.slate900,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio: 1.6,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) {
            final s = stats[i];
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  right: i % 2 == 0 ? const BorderSide(color: Color(0x14FFFFFF)) : BorderSide.none,
                  bottom: i < 2 ? const BorderSide(color: Color(0x14FFFFFF)) : BorderSide.none,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['value'] as String,
                    style: AppFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: (s['accent'] as bool) ? AppTheme.amber400 : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s['label'] as String,
                    style: AppFonts.manrope(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  static const steps = [
    {'n': '01', 'icon': Icons.add_box, 'title': 'Déclarez le colis', 'text': 'Trajet, destinataire, poids et prix souhaité. Ajoutez l\'option express ou l\'assurance.'},
    {'n': '02', 'icon': Icons.sell, 'title': 'Recevez des offres', 'text': 'Les chauffeurs disponibles sur votre trajet enchérissent — prix, note vocale, message. Vous acceptez la meilleure.'},
    {'n': '03', 'icon': Icons.local_shipping, 'title': 'Suivez la livraison', 'text': 'Statuts en temps réel, contact direct du chauffeur et preuve de livraison à l\'arrivée.'},
  ];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
        child: Column(
          children: [
            Column(
              children: [
                Text('COMMENT ÇA MARCHE', style: AppFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppTheme.primary)),
                const SizedBox(height: 10),
                Text("Trois étapes, d'un quai à l'autre", style: AppFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Text("Pas d'intermédiaire opaque : vous gardez la main sur le prix et le chauffeur.", style: AppFonts.manrope(fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ),
            const SizedBox(height: 40),
            ...steps.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    border: Border.all(color: AppTheme.slate200),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppTheme.teal50,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        alignment: Alignment.center,
                        child: Icon(s['icon'] as IconData, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ÉTAPE ${s['n']}', style: AppTheme.mono(fontSize: 12, color: AppTheme.slate400, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(s['title'] as String, style: AppFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            const SizedBox(height: 6),
                            Text(s['text'] as String, style: AppFonts.manrope(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ExpressCallout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 56),
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppTheme.slate900,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('»» Option express', style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppTheme.red400)),
              const SizedBox(height: 14),
              Text('Un colis urgent ? Priorité haute, départ immédiat.', style: AppFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15, color: Colors.white)),
              const SizedBox(height: 12),
              Text("Votre annonce passe en tête et n'est proposée qu'aux chauffeurs déjà sur la route. Le supplément s'ajuste selon votre trajet.", style: AppFonts.manrope(fontSize: 15, height: 1.55, color: Colors.white.withOpacity(0.7))),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/register'),
                icon: const Icon(Icons.bolt, size: 20),
                label: const Text('Envoyer en express'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.amber400,
                  foregroundColor: AppTheme.amberOnFg,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  textStyle: AppFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppTheme.teal800,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.amber400,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: AppFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                    children: const [
                      TextSpan(text: 'PRO'),
                      TextSpan(text: 'COLIS', style: TextStyle(color: AppTheme.amber400)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "La plateforme qui connecte expéditeurs et chauffeurs pour le transport de colis au Sénégal, partout en Afrique et à l'international.",
              style: AppFonts.manrope(fontSize: 13.5, height: 1.6, color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 40,
              runSpacing: 24,
              children: [
                _FooterLinks(
                  title: 'À propos',
                  items: [
                    _FooterLink('Qui sommes-nous ?', '/a-propos'),
                    _FooterLink('Contact', '/contact'),
                  ],
                ),
                _FooterLinks(
                  title: 'Légal',
                  items: [
                    _FooterLink('Mentions légales', '/mentions-legales'),
                    _FooterLink('Confidentialité', '/confidentialite'),
                    _FooterLink('CGU', '/cgu'),
                    _FooterLink('Conditions de transport', '/conditions-transport'),
                    _FooterLink('Paiement', '/paiement'),
                    _FooterLink('Remboursement', '/remboursement'),
                  ],
                ),
                _FooterLinks(
                  title: 'Support',
                  items: [
                    _FooterLink('Aide & support', '/help'),
                    _FooterLink('Réclamations', '/reclamations'),
                    _FooterLink('Colis interdits', '/colis-interdits'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('© ${DateTime.now().year} SENDPROCOLIS', style: AppFonts.manrope(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}

class _FooterLink {
  final String label;
  final String path;

  const _FooterLink(this.label, this.path);
}

class _FooterLinks extends StatelessWidget {
  final String title;
  final List<_FooterLink> items;

  const _FooterLinks({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: GestureDetector(
            onTap: () => context.go(item.path),
            child: Text(
              item.label,
              style: AppFonts.manrope(fontSize: 13.5, color: Colors.white.withOpacity(0.7)),
            ),
          ),
        )),
      ],
    );
  }
}
