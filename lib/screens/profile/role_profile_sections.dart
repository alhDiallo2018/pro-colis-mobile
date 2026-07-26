// lib/screens/profile/role_profile_sections.dart
//
// Sections du profil propres à chaque rôle.
//
// Extraites de ProfileScreen pour deux raisons : l'écran partagé affichait les
// mêmes statistiques chauffeur à tout le monde (un client lisait « Livraisons
// totales : 0 »), et ajouter un rôle ne doit pas obliger à rouvrir un fichier
// de 900 lignes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/role_profile.dart';
import '../../models/stats.dart';
import '../../models/support.dart';
import '../../models/user.dart';
import '../../providers/stats_provider.dart';
import '../../providers/support_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../theme/role_identity.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

// ============================================================
// Rangée de statistiques propre au rôle
// ============================================================

/// Trois tuiles de statistiques choisies selon le rôle et alimentées par l'API.
class RoleStatsRow extends ConsumerWidget {
  final User user;

  const RoleStatsRow({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (user.role) {
      case UserRole.client:
        return _fromAsync(
          ref.watch(clientProfileStatsProvider),
          _clientStats,
        );
      case UserRole.driver:
        return _fromAsync(ref.watch(driverStatsProvider), _driverStats);
      case UserRole.admin:
        return _fromAsync(ref.watch(garageStatsProvider), _garageStats);
      case UserRole.supportTechnique:
        return _fromAsync(
          ref.watch(supportTechniqueStatsProvider),
          _techniqueStats,
        );
      case UserRole.supportCommercial:
        return _fromAsync(
          ref.watch(supportCommercialStatsProvider),
          _commercialStats,
        );
      case UserRole.support:
      case UserRole.superAdmin:
        return _fromAsync(ref.watch(globalStatsProvider), _globalStats);
    }
  }

  List<RoleStat> _clientStats(ClientProfileStats s) => [
        RoleStat(
          icon: Icons.inventory_2_rounded,
          value: '${s.user.totalParcels}',
          label: 'Mes colis',
          tone: PcTone.primary,
        ),
        RoleStat(
          icon: Icons.local_shipping_rounded,
          value: '${s.user.activeParcels}',
          label: 'En cours',
          tone: PcTone.amber,
        ),
        RoleStat(
          icon: Icons.local_offer_rounded,
          value: '${s.bids.pending}',
          label: 'Offres à traiter',
          tone: PcTone.green,
        ),
      ];

  List<RoleStat> _driverStats(DriverStats s) => [
        RoleStat(
          icon: Icons.task_alt_rounded,
          value: '${s.completedDeliveries}',
          label: 'Livraisons',
          tone: PcTone.green,
        ),
        RoleStat(
          icon: Icons.local_shipping_rounded,
          value: '${s.activeParcels}',
          label: 'Missions actives',
          tone: PcTone.primary,
        ),
        RoleStat(
          icon: Icons.star_rounded,
          value: s.rating > 0 ? s.rating.toStringAsFixed(1) : '—',
          label: 'Note',
          tone: PcTone.amber,
        ),
      ];

  List<RoleStat> _garageStats(GarageStats s) => [
        RoleStat(
          icon: Icons.inventory_2_rounded,
          value: '${s.activeParcels}',
          label: 'Colis actifs',
          tone: PcTone.amber,
        ),
        RoleStat(
          icon: Icons.people_rounded,
          value: '${s.activeDrivers}',
          label: 'Chauffeurs actifs',
          tone: PcTone.primary,
        ),
        RoleStat(
          icon: Icons.task_alt_rounded,
          value: '${s.deliveredToday}',
          label: 'Livrés aujourd’hui',
          tone: PcTone.green,
        ),
      ];

  List<RoleStat> _globalStats(GlobalStats s) => [
        RoleStat(
          icon: Icons.group_rounded,
          value: formatAmount(s.totalUsers),
          label: 'Utilisateurs',
          tone: PcTone.primary,
        ),
        RoleStat(
          icon: Icons.garage_rounded,
          value: '${s.totalGarages}',
          label: 'Garages',
          tone: PcTone.green,
        ),
        RoleStat(
          icon: Icons.inventory_2_rounded,
          value: formatAmount(s.totalParcels),
          label: 'Colis',
          tone: PcTone.amber,
        ),
      ];

  Widget _fromAsync<T>(AsyncValue<T> state, List<RoleStat> Function(T) build) {
    return state.when(
      loading: () => const SizedBox(
        height: 118,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
      // Sur le profil, une erreur de chargement des KPI ne doit pas masquer le
      // formulaire en dessous : on la réduit à une ligne discrète.
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 16, color: AppTheme.slate400),
            const SizedBox(width: 6),
            Text(
              'Statistiques indisponibles',
              style: AppFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.slate400,
              ),
            ),
          ],
        ),
      ),
      data: (value) => _row(build(value)),
    );
  }

  Widget _row(List<RoleStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: stats[i].icon,
                value: stats[i].value,
                label: stats[i].label,
                tone: stats[i].tone,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<RoleStat> _techniqueStats(SupportTechniqueSummary s) => [
        RoleStat(
          icon: Icons.confirmation_number_rounded,
          value: '${s.openTickets}',
          label: 'Tickets ouverts',
          tone: PcTone.amber,
        ),
        RoleStat(
          icon: Icons.done_all_rounded,
          value: '${s.resolvedThisMonth}',
          label: 'Résolus ce mois',
          tone: PcTone.green,
        ),
        RoleStat(
          icon: Icons.timer_rounded,
          value: s.firstResponseLabel,
          label: '1re réponse',
          tone: PcTone.primary,
        ),
      ];

  List<RoleStat> _commercialStats(SupportCommercialSummary s) => [
        RoleStat(
          icon: Icons.handshake,
          value: '${s.activeLeads}',
          label: 'Prospects actifs',
          tone: PcTone.primary,
        ),
        RoleStat(
          icon: Icons.emoji_events_rounded,
          value: '${s.signedThisMonth}',
          label: 'Signés ce mois',
          tone: PcTone.green,
        ),
        RoleStat(
          icon: Icons.trending_up_rounded,
          value: s.hasObjective ? '${s.objectivePercent}%' : '—',
          label: 'Objectif atteint',
          tone: s.hasObjective && s.objectivePercent >= 100
              ? PcTone.green
              : PcTone.amber,
        ),
      ];
}

// ============================================================
// Carte « informations métier »
// ============================================================

/// Bloc métier du profil : véhicule pour un chauffeur, périmètre d'assistance
/// pour le support technique, portefeuille pour le commercial, etc.
class RoleProfileSectionCard extends ConsumerWidget {
  final User user;

  const RoleProfileSectionCard({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (user.role) {
      case UserRole.client:
        final stats = ref.watch(clientProfileStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_clientSection(stats));
      case UserRole.driver:
        final stats = ref.watch(driverStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_driverSection(stats));
      case UserRole.admin:
        final stats = ref.watch(garageStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_garageSection(stats));
      case UserRole.supportTechnique:
        final stats = ref.watch(supportTechniqueStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_techniqueSection(stats));
      case UserRole.supportCommercial:
        final stats = ref.watch(supportCommercialStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_commercialSection(stats));
      case UserRole.support:
      case UserRole.superAdmin:
        final stats = ref.watch(globalStatsProvider).valueOrNull;
        return stats == null
            ? const SizedBox.shrink()
            : _card(_globalSection(stats));
    }
  }

  RoleProfileSection _clientSection(ClientProfileStats s) => RoleProfileSection(
        title: 'Mon activité d’expédition',
        rows: [
          RoleInfoRow(
            icon: Icons.inventory_2_rounded,
            title: 'Colis',
            subtitle:
                '${s.user.totalParcels} au total · ${s.user.deliveredParcels} livrés · ${s.user.activeParcels} en cours',
            tone: PcTone.primary,
          ),
          RoleInfoRow(
            icon: Icons.local_offer_rounded,
            title: 'Offres reçues',
            subtitle:
                '${s.bids.received} reçues · ${s.bids.pending} en attente · ${s.bids.accepted} acceptées',
            tone: PcTone.amber,
          ),
          RoleInfoRow(
            icon: Icons.stars_rounded,
            title: 'Solde de points',
            subtitle: '${s.user.scoreBalance} points',
            tone: PcTone.green,
          ),
        ],
      );

  RoleProfileSection _driverSection(DriverStats s) => RoleProfileSection(
        title: 'Mon véhicule et mes courses',
        rows: [
          RoleInfoRow(
            icon: Icons.directions_bus_rounded,
            title: 'Véhicule',
            subtitle: user.hasVehicleInfo ? user.vehicleInfo : 'Non renseigné',
            tone: PcTone.primary,
          ),
          RoleInfoRow(
            icon: Icons.garage_rounded,
            title: 'Zone de rattachement',
            subtitle: user.garageName ?? 'Aucune zone assignée',
          ),
          RoleInfoRow(
            icon: Icons.task_alt_rounded,
            title: 'Activité',
            subtitle:
                '${s.completedDeliveries} livraisons terminées · ${s.activeParcels} missions actives',
            tone: PcTone.green,
          ),
          RoleInfoRow(
            icon: Icons.stars_rounded,
            title: 'Points et offres',
            subtitle:
                '${s.scoreBalance} points · ${s.pendingBids} offres en attente',
            tone: PcTone.amber,
          ),
        ],
      );

  RoleProfileSection _garageSection(GarageStats s) => RoleProfileSection(
        title: 'Ma zone',
        rows: [
          RoleInfoRow(
            icon: Icons.garage_rounded,
            title: 'Zone administrée',
            subtitle: user.garageName ?? 'Aucune zone assignée',
            tone: PcTone.amber,
          ),
          RoleInfoRow(
            icon: Icons.inventory_2_rounded,
            title: 'Activité colis',
            subtitle:
                '${s.totalParcels} au total · ${s.activeParcels} actifs · ${s.deliveredToday} livrés aujourd’hui',
            tone: PcTone.primary,
          ),
          RoleInfoRow(
            icon: Icons.people_rounded,
            title: 'Chauffeurs en service',
            subtitle: '${s.activeDrivers}',
            tone: PcTone.green,
          ),
          RoleInfoRow(
            icon: Icons.payments_rounded,
            title: 'Revenus',
            subtitle: formatFcfa(s.revenue),
            tone: PcTone.green,
          ),
        ],
      );

  RoleProfileSection _globalSection(GlobalStats s) => RoleProfileSection(
        title: user.isSupportShared
            ? 'Vue d’assistance de la plateforme'
            : 'Gouvernance de la plateforme',
        rows: [
          RoleInfoRow(
            icon: Icons.groups_rounded,
            title: 'Utilisateurs',
            subtitle:
                '${formatAmount(s.totalUsers)} comptes · ${formatAmount(s.totalClients)} clients · ${formatAmount(s.totalDrivers)} chauffeurs',
            tone: PcTone.primary,
          ),
          RoleInfoRow(
            icon: Icons.inventory_2_rounded,
            title: 'Colis',
            subtitle:
                '${formatAmount(s.totalParcels)} au total · ${formatAmount(s.parcelsInTransit)} en transit · ${formatAmount(s.parcelsPending)} en attente',
            tone: PcTone.amber,
          ),
          RoleInfoRow(
            icon: Icons.garage_rounded,
            title: 'Réseau',
            subtitle:
                '${s.totalGarages} garages · ${s.totalVehicles} véhicules',
            tone: PcTone.green,
          ),
          RoleInfoRow(
            icon: Icons.payments_rounded,
            title: 'Revenus cumulés',
            subtitle: formatFcfa(s.totalRevenue),
            tone: PcTone.green,
          ),
        ],
      );

  RoleProfileSection _techniqueSection(SupportTechniqueSummary s) {
    return RoleProfileSection(
      title: 'Mon périmètre d\'assistance',
      rows: [
        RoleInfoRow(
          icon: Icons.confirmation_number_rounded,
          title: 'Charge en cours',
          subtitle:
              '${s.openTickets} ticket${s.openTickets > 1 ? 's' : ''} ouvert${s.openTickets > 1 ? 's' : ''} · ${s.resolvedToday} résolu${s.resolvedToday > 1 ? 's' : ''} aujourd\'hui',
          tone: PcTone.primary,
        ),
        RoleInfoRow(
          icon: Icons.speed_rounded,
          title: 'Délais moyens',
          subtitle:
              '1re réponse ${s.firstResponseLabel} · résolution ${s.resolutionLabel}',
          tone: PcTone.neutral,
        ),
        RoleInfoRow(
          icon: Icons.sentiment_satisfied_alt_rounded,
          title: 'Satisfaction des demandeurs',
          subtitle: s.satisfactionPercent == null
              ? 'Pas encore d\'avis sur la période'
              : '${s.satisfactionLabel} sur ${s.resolvedThisMonth} tickets résolus',
          tone: PcTone.green,
        ),
        RoleInfoRow(
          icon: Icons.warning_amber_rounded,
          title: 'SLA en risque',
          subtitle: s.slaAtRisk == 0
              ? 'Aucun ticket en dépassement'
              : '${s.slaAtRisk} ticket${s.slaAtRisk > 1 ? 's' : ''} à traiter en priorité',
          tone: s.slaAtRisk > 0 ? PcTone.red : PcTone.neutral,
        ),
        RoleInfoRow(
          icon: Icons.bug_report_rounded,
          title: 'Incidents plateforme',
          subtitle: s.openIncidents == 0
              ? 'Aucun incident ouvert'
              : '${s.openIncidents} incident${s.openIncidents > 1 ? 's' : ''} en cours',
          tone: s.openIncidents > 0 ? PcTone.amber : PcTone.neutral,
        ),
      ],
    );
  }

  RoleProfileSection _commercialSection(SupportCommercialSummary s) {
    return RoleProfileSection(
      title: 'Mon portefeuille commercial',
      rows: [
        RoleInfoRow(
          icon: Icons.map_rounded,
          title: 'Secteur',
          subtitle: s.territory?.isNotEmpty == true
              ? s.territory!
              : 'Non défini · à renseigner avec l\'objectif du mois',
          tone: PcTone.primary,
        ),
        RoleInfoRow(
          icon: Icons.business_center_rounded,
          title: 'Comptes gérés',
          subtitle:
              '${s.managedAccounts} comptes · ${s.activeLeads} en cours de négociation',
          tone: PcTone.neutral,
        ),
        RoleInfoRow(
          icon: Icons.payments_rounded,
          title: 'CA généré ce mois',
          subtitle: s.hasObjective
              ? '${formatFcfa(s.monthlyRevenue)} sur ${formatFcfa(s.monthlyObjective)} d\'objectif'
              : '${formatFcfa(s.monthlyRevenue)} · aucun objectif défini',
          tone: PcTone.green,
        ),
        RoleInfoRow(
          icon: Icons.notification_important_rounded,
          title: 'Relances en retard',
          subtitle: s.overdueFollowUps == 0
              ? 'Portefeuille à jour'
              : '${s.overdueFollowUps} prospect${s.overdueFollowUps > 1 ? 's' : ''} à rappeler',
          tone: s.overdueFollowUps > 0 ? PcTone.red : PcTone.neutral,
        ),
        RoleInfoRow(
          icon: Icons.percent_rounded,
          title: 'Taux de conversion',
          subtitle: s.conversionPercent == null
              ? 'Portefeuille vide'
              : '${s.conversionLabel} des comptes signent',
          tone: PcTone.amber,
        ),
      ],
    );
  }

  Widget _card(RoleProfileSection section) {
    final identity = user.identity;

    return PcCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: identity.accentSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(identity.icon, size: 18, color: identity.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < section.rows.length; i++) ...[
            if (i > 0) const PcDivider(),
            _RoleInfoTile(row: section.rows[i]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RoleInfoTile extends StatelessWidget {
  final RoleInfoRow row;

  const _RoleInfoTile({required this.row});

  @override
  Widget build(BuildContext context) {
    // PcListRow tronque son sous-titre à une ligne ; ces valeurs métier sont
    // souvent plus longues, d'où une mise en page dédiée.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToneIcon(icon: row.icon, tone: row.tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.subtitle,
                  style: AppFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneIcon extends StatelessWidget {
  final IconData icon;
  final PcTone tone;

  const _ToneIcon({required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color fg}) c = switch (tone) {
      PcTone.primary => (bg: AppTheme.teal50, fg: AppTheme.teal500),
      PcTone.green => (bg: AppTheme.green50, fg: AppTheme.green700),
      PcTone.amber => (bg: AppTheme.amber50, fg: AppTheme.amber600),
      PcTone.red => (bg: AppTheme.red50, fg: AppTheme.red500),
      PcTone.neutral => (bg: AppTheme.slate100, fg: AppTheme.slate500),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: 19, color: c.fg),
    );
  }
}

// ============================================================
// Raccourcis métier
// ============================================================

class RoleQuickLink {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final PcTone tone;

  const RoleQuickLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.tone = PcTone.neutral,
  });
}

/// Raccourcis vers les écrans que ce rôle utilise réellement.
///
/// Les routes respectent les gardes de rôle du routeur : un raccourci n'est
/// proposé qu'aux rôles autorisés à l'ouvrir.
List<RoleQuickLink> quickLinksFor(UserRole role) {
  switch (role) {
    case UserRole.client:
      return const [
        RoleQuickLink(
          icon: Icons.add_box_rounded,
          title: 'Nouvel envoi',
          subtitle: 'Créer un colis en quelques étapes',
          route: '/parcel/new',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.local_offer_rounded,
          title: 'Offres reçues',
          subtitle: 'Comparer les propositions des chauffeurs',
          route: '/client/offres',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Mon portefeuille',
          subtitle: 'Solde et historique de paiements',
          route: '/wallet',
          tone: PcTone.green,
        ),
      ];

    case UserRole.driver:
      return const [
        RoleQuickLink(
          icon: Icons.description_rounded,
          title: 'Documents du véhicule',
          subtitle: 'Carte grise, assurance, visite technique',
          route: '/driver/documents',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.payments_rounded,
          title: 'Mes revenus',
          subtitle: 'Courses encaissées et commissions',
          route: '/driver/revenue',
          tone: PcTone.green,
        ),
        RoleQuickLink(
          icon: Icons.workspace_premium_rounded,
          title: 'Mes points',
          subtitle: 'Fidélité et classement',
          route: '/driver/points',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.tune_rounded,
          title: 'Véhicule et disponibilité',
          subtitle: 'Modifier mon véhicule et mon statut',
          route: '/driver/settings',
          tone: PcTone.neutral,
        ),
      ];

    case UserRole.admin:
      return const [
        RoleQuickLink(
          icon: Icons.people_rounded,
          title: 'Chauffeurs de ma zone',
          subtitle: 'Disponibilités et affectations',
          route: '/garage/drivers',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Assignations',
          subtitle: 'Attribuer les colis en attente',
          route: '/garage/assignments',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.bar_chart_rounded,
          title: 'Rapports de zone',
          subtitle: 'Volumes et performances',
          route: '/garage/rapports',
          tone: PcTone.green,
        ),
      ];

    case UserRole.supportTechnique:
      return const [
        RoleQuickLink(
          icon: Icons.forum_rounded,
          title: 'File de tickets',
          subtitle: 'Répondre aux conversations en attente',
          route: '/support-tech/tickets',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.bug_report_rounded,
          title: 'Incidents plateforme',
          subtitle: 'Suivre les pannes en cours',
          route: '/support-tech/incidents',
          tone: PcTone.red,
        ),
        RoleQuickLink(
          icon: Icons.menu_book_rounded,
          title: 'Base de connaissances',
          subtitle: 'Procédures et réponses types',
          route: '/help',
          tone: PcTone.neutral,
        ),
      ];

    case UserRole.supportCommercial:
      return const [
        RoleQuickLink(
          icon: Icons.handshake,
          title: 'Mes prospects',
          subtitle: 'Pipeline et relances à faire',
          route: '/support-com/leads',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.map_rounded,
          title: 'Couverture du réseau',
          subtitle: 'Zones à ouvrir ou à densifier',
          route: '/support-com/coverage',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.campaign_rounded,
          title: 'Annonces publicitaires',
          subtitle: 'Offres mises en avant aux clients',
          route: '/advertisements',
          tone: PcTone.green,
        ),
      ];

    // Rôle `support` transverse : tout passe par `/support-admin`, seul
    // préfixe que sa garde de rôle laisse ouvrir (voir app_router.dart).
    case UserRole.support:
      return const [
        RoleQuickLink(
          icon: Icons.forum_rounded,
          title: 'Conversations',
          subtitle: 'Répondre aux demandes en attente',
          route: '/support-admin/conversations',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.contact_support_rounded,
          title: 'Assistances',
          subtitle: 'Journal des interactions rendues',
          route: '/support-admin/assistances',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.inventory_2_rounded,
          title: 'Colis',
          subtitle: 'Retrouver un envoi pour instruire un litige',
          route: '/support-admin/colis',
          tone: PcTone.neutral,
        ),
      ];

    case UserRole.superAdmin:
      return const [
        RoleQuickLink(
          icon: Icons.group_rounded,
          title: 'Utilisateurs',
          subtitle: 'Comptes, rôles et statuts',
          route: '/admin/users',
          tone: PcTone.primary,
        ),
        RoleQuickLink(
          icon: Icons.account_balance_rounded,
          title: 'Finance',
          subtitle: 'Commissions, retraits, paiements',
          route: '/admin/finance',
          tone: PcTone.green,
        ),
        RoleQuickLink(
          icon: Icons.verified_user_rounded,
          title: 'Vérifications d\'identité',
          subtitle: 'Dossiers KYC à valider',
          route: '/admin/verifications',
          tone: PcTone.amber,
        ),
        RoleQuickLink(
          icon: Icons.settings_suggest_rounded,
          title: 'Paramètres plateforme',
          subtitle: 'Commissions, zones, notifications',
          route: '/admin/parametres',
          tone: PcTone.neutral,
        ),
      ];
  }
}

/// Carte listant les raccourcis métier du rôle.
class RoleQuickLinksCard extends StatelessWidget {
  final UserRole role;

  const RoleQuickLinksCard({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final links = quickLinksFor(role);
    if (links.isEmpty) return const SizedBox.shrink();

    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (int i = 0; i < links.length; i++) ...[
            if (i > 0) const PcDivider(),
            PcListRow(
              icon: links[i].icon,
              iconTone: links[i].tone,
              title: links[i].title,
              subtitle: links[i].subtitle,
              chevron: true,
              onTap: () => context.push(links[i].route),
            ),
          ],
        ],
      ),
    );
  }
}
