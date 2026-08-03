// lib/screens/dashboard/support_commercial_dashboard.dart
//
// Espace du support commercial : pipeline de prospects, objectifs du mois et
// couverture du réseau.
//
// Données réelles issues de `/support-commercial/*` via support_provider.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/role_profile.dart';
import '../../models/support.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/support_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../theme/role_identity.dart';
import '../../utils/format.dart';
import '../../widgets/broadcast_banner.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../profile/profile_screen.dart';
import 'notifications/notifications_screen.dart';
import 'role_dashboard_widgets.dart';

class SupportCommercialDashboard extends ConsumerStatefulWidget {
  /// Onglet ouvert au premier affichage (utilisé par les routes profondes).
  final int initialTab;

  const SupportCommercialDashboard({super.key, this.initialTab = 0});

  @override
  ConsumerState<SupportCommercialDashboard> createState() =>
      _SupportCommercialDashboardState();
}

class _SupportCommercialDashboardState
    extends ConsumerState<SupportCommercialDashboard> {
  static const int _tabCount = 4;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.clamp(0, _tabCount - 1);
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _goToTab(int index) {
    if (index < 0 || index >= _tabCount || index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    ref.read(dashboardTabProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(supportCommercialStatsProvider).valueOrNull;

    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (mounted && next != _selectedIndex && next >= 0 && next < _tabCount) {
        setState(() => _selectedIndex = next);
      }
    });

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _SupportCommercialHome(
            user: user,
            onNotificationsTap: _openNotifications,
            onSeeLeads: () => _goToTab(1),
            onSeeCoverage: () => _goToTab(2),
            onSeeProfile: () => _goToTab(3),
          ),
          const _LeadsTab(),
          const _CoverageTab(),
          const ProfileScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: _goToTab,
        items: [
          const ProcolisTabItem(
              icon: Icons.dashboard_rounded, label: 'Tableau'),
          ProcolisTabItem(
            icon: Icons.handshake,
            label: 'Prospects',
            // Pas de badge tant que les KPI chargent : un zéro se lirait comme
            // « aucune relance en retard ».
            badge: stats?.overdueFollowUps,
          ),
          const ProcolisTabItem(icon: Icons.map_rounded, label: 'Couverture'),
          const ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }
}

// ============================================================
// Onglet « Tableau »
// ============================================================

class _SupportCommercialHome extends ConsumerWidget {
  final User user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSeeLeads;
  final VoidCallback onSeeCoverage;
  final VoidCallback onSeeProfile;

  const _SupportCommercialHome({
    required this.user,
    required this.onNotificationsTap,
    required this.onSeeLeads,
    required this.onSeeCoverage,
    required this.onSeeProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(supportCommercialStatsProvider);
    final leadsAsync = ref.watch(commercialLeadsProvider);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        invalidateSupportCommercial(ref);
        await ref.read(supportCommercialStatsProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('support-commercial-home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          RoleDashboardHero(
            user: user,
            onNotificationsTap: onNotificationsTap,
            onProfileTap: onSeeProfile,
            unreadCount: statsAsync.valueOrNull?.overdueFollowUps ?? 0,
            footer: _heroFooter(statsAsync.valueOrNull),
          ),
          // Les annonces super-admin s'affichent sous le hero du rôle.
          const BroadcastBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            child: statsAsync.when(
              loading: () => const RoleLoadingBlock(height: 220),
              error: (error, _) => RoleErrorCard(
                error: error,
                onRetry: () => ref.invalidate(supportCommercialStatsProvider),
              ),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.hasObjective)
                    RoleObjectiveCard(
                      title: 'Objectif du mois',
                      currentLabel: formatFcfa(stats.monthlyRevenue),
                      targetLabel: formatFcfa(stats.monthlyObjective),
                      progress: stats.objectiveProgress,
                      percent: stats.objectivePercent,
                      accent: user.identity.accent,
                    )
                  else
                    // Aucun objectif défini pour le mois : une jauge à 0 %
                    // laisserait croire à un mauvais résultat.
                    PcCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              color: AppTheme.slate400, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Aucun objectif défini pour ce mois · ${formatFcfa(stats.monthlyRevenue)} réalisés',
                              style: AppFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.slate600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 22),
                  RoleKpiGrid(
                    stats: [
                      RoleStat(
                        icon: Icons.handshake,
                        value: '${stats.activeLeads}',
                        label: 'Prospects actifs',
                        tone: PcTone.primary,
                      ),
                      RoleStat(
                        icon: Icons.emoji_events_rounded,
                        value: '${stats.signedThisMonth}',
                        label: 'Signés ce mois',
                        tone: PcTone.green,
                      ),
                      RoleStat(
                        icon: Icons.percent_rounded,
                        value: stats.conversionLabel,
                        label: 'Taux de conversion',
                        tone: PcTone.amber,
                      ),
                      RoleStat(
                        icon: Icons.garage_rounded,
                        value: '${stats.newZonesSigned}',
                        label: 'Nouvelles zones',
                        tone: PcTone.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  RoleSeriesCard(
                    series: stats.monthlySeries,
                    subtitle: '${stats.managedAccounts} comptes suivis',
                  ),
                  const SizedBox(height: 22),
                  RoleBreakdownCard(
                    title: 'Répartition du portefeuille',
                    items: stats.sources,
                  ),
                  const SizedBox(height: 22),
                  _FollowUpList(
                    leadsAsync: leadsAsync,
                    onSeeAll: onSeeLeads,
                    onRetry: () => ref.invalidate(commercialLeadsProvider),
                  ),
                  const SizedBox(height: 12),
                  _CommercialQuickActions(onSeeCoverage: onSeeCoverage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _heroFooter(SupportCommercialSummary? stats) {
    if (stats == null) return null;
    final chips = <Widget>[
      if (stats.territory != null && stats.territory!.isNotEmpty)
        HeroChip(icon: Icons.map_rounded, label: stats.territory!),
      HeroChip(
        icon: Icons.business_center_rounded,
        label: '${stats.managedAccounts} comptes',
      ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

/// Aperçu des prospects à relancer.
class _FollowUpList extends StatelessWidget {
  final AsyncValue<List<CommercialLead>> leadsAsync;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  const _FollowUpList({
    required this.leadsAsync,
    required this.onSeeAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return leadsAsync.when(
      loading: () => const RoleLoadingBlock(height: 140),
      error: (error, _) => RoleErrorCard(error: error, onRetry: onRetry),
      data: (all) {
        final followUps =
            all.where((l) => l.stage != LeadStage.signed).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoleListHeader(
              title: 'Relances à faire',
              count: followUps.length,
              actionLabel: 'Tout voir',
              onAction: onSeeAll,
            ),
            if (followUps.isEmpty)
              const PcCard(
                child: PcEmptyState(
                  icon: Icons.check_circle_rounded,
                  title: 'Portefeuille à jour',
                  message: 'Aucune relance en attente.',
                  tone: PcTone.green,
                ),
              )
            else
              for (final lead in followUps.take(4)) ...[
                _LeadCard(lead: lead),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _CommercialQuickActions extends StatelessWidget {
  final VoidCallback onSeeCoverage;

  const _CommercialQuickActions({required this.onSeeCoverage});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          PcListRow(
            icon: Icons.map_rounded,
            iconTone: PcTone.amber,
            title: 'Couverture du réseau',
            subtitle: 'Zones à ouvrir ou à densifier',
            chevron: true,
            onTap: onSeeCoverage,
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.contact_support_rounded,
            iconTone: PcTone.primary,
            title: 'Mes assistances',
            subtitle: 'Codifier une assistance rendue',
            chevron: true,
            onTap: () => context.push('/support-com/assistances'),
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.campaign_rounded,
            iconTone: PcTone.green,
            title: 'Annonces publicitaires',
            subtitle: 'Offres mises en avant aux clients',
            chevron: true,
            onTap: () => context.push('/advertisements'),
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.support_agent,
            iconTone: PcTone.primary,
            title: 'Contacter le support technique',
            subtitle: 'Escalader un problème client',
            chevron: true,
            onTap: () => context.push('/support'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Onglet « Prospects »
// ============================================================

class _LeadsTab extends ConsumerWidget {
  const _LeadsTab();

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    CommercialLead lead,
  ) async {
    // Étape suivante dans le pipeline ; `signed` est terminal.
    final next = LeadStage.values.firstWhere(
      (s) => s.step == lead.stage.step + 1,
      orElse: () => LeadStage.signed,
    );
    try {
      await ref.read(supportRolesApiProvider).updateLead(lead.id, stage: next);
      invalidateSupportCommercial(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lead.name} → ${next.label}')),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SupportCommercialDashboard] Échec de mise à jour du prospect '
        '${lead.id}: $error',
      );
      debugPrintStack(
        label: 'SupportCommercialDashboard._advance',
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec : $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(leadFilterProvider);
    final leadsAsync = ref.watch(commercialLeadsProvider);

    return Column(
      children: [
        Container(
          color: AppTheme.cardColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pipeline commercial',
                    style: AppFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pipelineSubtitle(leadsAsync),
                    style: AppFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StageChip(
                          label: 'Tous',
                          selected: filter == null,
                          onTap: () => ref
                              .read(leadFilterProvider.notifier)
                              .state = null,
                        ),
                        for (final stage in LeadStage.values) ...[
                          const SizedBox(width: 8),
                          _StageChip(
                            label: stage.label,
                            selected: filter == stage,
                            onTap: () => ref
                                .read(leadFilterProvider.notifier)
                                .state = stage,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: leadsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: RoleErrorCard(
                error: error,
                onRetry: () => ref.invalidate(commercialLeadsProvider),
              ),
            ),
            data: (leads) => leads.isEmpty
                ? const PcEmptyState(
                    icon: Icons.handshake,
                    title: 'Aucun prospect',
                    message: 'Aucun prospect ne correspond à ce filtre.',
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      invalidateSupportCommercial(ref);
                      await ref.read(commercialLeadsProvider.future);
                    },
                    child: ListView(
                      key: const PageStorageKey('support-commercial-leads'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        for (final lead in leads) ...[
                          _LeadCard(
                            lead: lead,
                            onAdvance: lead.stage == LeadStage.signed
                                ? null
                                : () => _advance(context, ref, lead),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _pipelineSubtitle(AsyncValue<List<CommercialLead>> state) {
    final leads = state.valueOrNull;
    if (leads == null) return 'Chargement…';
    final value = leads
        .where((l) => l.stage != LeadStage.signed)
        .fold<double>(0, (sum, l) => sum + l.monthlyValue);
    return '${formatFcfa(value)} de valeur mensuelle en jeu';
  }
}

class _StageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.teal50 : AppTheme.slate50,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.teal500 : AppTheme.slate200,
            ),
          ),
          child: Text(
            label,
            style: AppFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppTheme.teal600 : AppTheme.slate600,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final CommercialLead lead;
  final VoidCallback? onAdvance;

  const _LeadCard({required this.lead, this.onAdvance});

  String get _followUpLabel {
    final days = lead.daysToFollowUp;
    if (days == null) return 'pas de relance planifiée';
    if (days < 0) return 'retard ${-days} j';
    if (days == 0) return 'à relancer aujourd\'hui';
    return 'relance dans $days j';
  }

  @override
  Widget build(BuildContext context) {
    final overdue = lead.isOverdue;

    return PcCard(
      accent: overdue ? AppTheme.red400 : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.infoSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(lead.kind.icon, size: 19, color: AppTheme.deep500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [lead.kind.label, if (lead.city != null) lead.city!]
                          .join(' · '),
                      style: AppFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          PcBadge(lead.stage.label, tone: lead.stage.tone),
          const SizedBox(height: 12),
          // Progression dans le pipeline : 4 segments, un par étape franchie.
          Row(
            children: [
              for (int step = 1; step <= LeadStage.totalSteps; step++) ...[
                if (step > 1) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: step <= lead.stage.step
                          ? AppTheme.teal500
                          : AppTheme.slate200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const PcDivider(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (lead.contactName != null)
                PcMeta(Icons.person_rounded, lead.contactName!),
              PcMeta(
                Icons.payments_rounded,
                '${formatFcfa(lead.monthlyValue)}/mois',
              ),
              Text(
                _followUpLabel,
                style: AppFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: overdue ? AppTheme.red500 : AppTheme.slate600,
                ),
              ),
            ],
          ),
          if (onAdvance != null) ...[
            const SizedBox(height: 14),
            PcButton(
              'Faire avancer',
              icon: Icons.arrow_forward_rounded,
              size: PcButtonSize.sm,
              variant: PcButtonVariant.secondary,
              block: true,
              onPressed: onAdvance,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Onglet « Couverture »
// ============================================================

class _CoverageTab extends ConsumerWidget {
  const _CoverageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverageAsync = ref.watch(networkCoverageProvider);
    final territory =
        ref.watch(supportCommercialStatsProvider).valueOrNull?.territory;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(networkCoverageProvider);
        await ref.read(networkCoverageProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('support-commercial-coverage'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Couverture du réseau',
                    style: AppFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    territory == null || territory.isEmpty
                        ? 'Zones actives et territoires à densifier'
                        : 'Secteur $territory',
                    style: AppFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          coverageAsync.when(
            loading: () => const RoleLoadingBlock(height: 200),
            error: (error, _) => RoleErrorCard(
              error: error,
              onRetry: () => ref.invalidate(networkCoverageProvider),
            ),
            data: (coverage) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoleKpiGrid(
                  stats: [
                    RoleStat(
                      icon: Icons.garage_rounded,
                      value: '${coverage.totalZones}',
                      label: 'Zones du réseau',
                      tone: PcTone.primary,
                    ),
                    RoleStat(
                      icon: Icons.location_off_rounded,
                      value: '${coverage.gaps.length}',
                      label: 'Zones à densifier',
                      tone: coverage.gaps.isEmpty ? PcTone.green : PcTone.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                PcSectionHeader(
                  'Moins de ${coverage.thinThreshold} chauffeurs actifs',
                ),
                if (coverage.gaps.isEmpty)
                  const PcEmptyState(
                    icon: Icons.public_rounded,
                    title: 'Réseau couvert',
                    message: 'Toutes les zones ont assez de chauffeurs actifs.',
                    tone: PcTone.green,
                  )
                else
                  PcCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (int i = 0; i < coverage.gaps.length; i++) ...[
                          if (i > 0) const PcDivider(),
                          PcListRow(
                            icon: Icons.location_off_rounded,
                            iconTone: coverage.gaps[i].activeDrivers == 0
                                ? PcTone.red
                                : PcTone.amber,
                            title: coverage.gaps[i].name,
                            subtitle: [
                              if (coverage.gaps[i].city != null)
                                coverage.gaps[i].city!,
                              coverage.gaps[i].reason,
                            ].join(' · '),
                          ),
                        ],
                      ],
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
