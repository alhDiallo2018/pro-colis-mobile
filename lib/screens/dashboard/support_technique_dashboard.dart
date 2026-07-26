// lib/screens/dashboard/support_technique_dashboard.dart
//
// Espace du support technique : file de tickets, incidents plateforme et
// indicateurs de SLA.
//
// Données réelles issues de `/support-technique/*` via support_provider.dart.

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

class SupportTechniqueDashboard extends ConsumerStatefulWidget {
  /// Onglet ouvert au premier affichage (utilisé par les routes profondes).
  final int initialTab;

  const SupportTechniqueDashboard({super.key, this.initialTab = 0});

  @override
  ConsumerState<SupportTechniqueDashboard> createState() =>
      _SupportTechniqueDashboardState();
}

class _SupportTechniqueDashboardState
    extends ConsumerState<SupportTechniqueDashboard> {
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
    final statsAsync = ref.watch(supportTechniqueStatsProvider);

    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (mounted && next != _selectedIndex && next >= 0 && next < _tabCount) {
        setState(() => _selectedIndex = next);
      }
    });

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Les badges d'onglets viennent des KPI : tant qu'ils chargent, pas de
    // badge plutôt qu'un zéro qui se lirait comme « rien à traiter ».
    final stats = statsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Conserver les quatre onglets montés empêche les listes de perdre leur
      // position et évite un frame vide pendant leur reconstruction.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _SupportTechniqueHome(
            user: user,
            onNotificationsTap: _openNotifications,
            onSeeTickets: () => _goToTab(1),
            onSeeIncidents: () => _goToTab(2),
          ),
          const _TicketsTab(),
          const _IncidentsTab(),
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
            icon: Icons.confirmation_number_rounded,
            label: 'Tickets',
            badge: stats?.openTickets,
          ),
          ProcolisTabItem(
            icon: Icons.bug_report_rounded,
            label: 'Incidents',
            badge: stats?.openIncidents,
          ),
          const ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }
}

// ============================================================
// Onglet « Tableau »
// ============================================================

class _SupportTechniqueHome extends ConsumerWidget {
  final User user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSeeTickets;
  final VoidCallback onSeeIncidents;

  const _SupportTechniqueHome({
    required this.user,
    required this.onNotificationsTap,
    required this.onSeeTickets,
    required this.onSeeIncidents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(supportTechniqueStatsProvider);
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        invalidateSupportTechnique(ref);
        await ref.read(supportTechniqueStatsProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('support-technique-home'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          RoleDashboardHero(
            user: user,
            onNotificationsTap: onNotificationsTap,
            unreadCount: statsAsync.valueOrNull?.slaAtRisk ?? 0,
          ),
          // Les annonces super-admin s'affichent sous le hero du rôle.
          const BroadcastBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            child: statsAsync.when(
              loading: () => const RoleLoadingBlock(height: 220),
              error: (error, _) => RoleErrorCard(
                error: error,
                onRetry: () => ref.invalidate(supportTechniqueStatsProvider),
              ),
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.slaAtRisk > 0) ...[
                    _SlaAlertCard(count: stats.slaAtRisk, onTap: onSeeTickets),
                    const SizedBox(height: 16),
                  ],
                  RoleKpiGrid(
                    stats: [
                      RoleStat(
                        icon: Icons.confirmation_number_rounded,
                        value: '${stats.openTickets}',
                        label: 'Tickets ouverts',
                        tone: PcTone.amber,
                      ),
                      RoleStat(
                        icon: Icons.done_all_rounded,
                        value: '${stats.resolvedToday}',
                        label: 'Résolus aujourd\'hui',
                        tone: PcTone.green,
                      ),
                      RoleStat(
                        icon: Icons.timer_rounded,
                        value: stats.firstResponseLabel,
                        label: '1re réponse (moy.)',
                        tone: PcTone.primary,
                      ),
                      RoleStat(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        value: stats.satisfactionLabel,
                        label: 'Satisfaction',
                        tone: PcTone.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  RoleSeriesCard(
                    series: stats.weeklySeries,
                    subtitle:
                        'Résolution moyenne : ${stats.resolutionLabel} · ${stats.resolvedThisMonth} tickets ce mois',
                  ),
                  const SizedBox(height: 22),
                  RoleBreakdownCard(
                    title: 'Motifs de contact',
                    items: stats.categories,
                  ),
                  const SizedBox(height: 22),
                  _PriorityQueue(
                    ticketsAsync: ticketsAsync,
                    onSeeAll: onSeeTickets,
                    onRetry: () => ref.invalidate(supportTicketsProvider),
                  ),
                  const SizedBox(height: 12),
                  _QuickActionsRow(
                    onSeeTickets: onSeeTickets,
                    onSeeIncidents: onSeeIncidents,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aperçu des 4 tickets les plus urgents encore actifs.
class _PriorityQueue extends StatelessWidget {
  final AsyncValue<List<SupportTicket>> ticketsAsync;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;

  const _PriorityQueue({
    required this.ticketsAsync,
    required this.onSeeAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ticketsAsync.when(
      loading: () => const RoleLoadingBlock(height: 140),
      error: (error, _) => RoleErrorCard(error: error, onRetry: onRetry),
      data: (all) {
        // Un ticket résolu n'appartient pas à une file de traitement. L'API
        // renvoie déjà les actifs en tête, on filtre pour l'aperçu.
        final queue = all.where((t) => t.isActive).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoleListHeader(
              title: 'File prioritaire',
              count: queue.length,
              actionLabel: 'Tout voir',
              onAction: onSeeAll,
            ),
            if (queue.isEmpty)
              const PcCard(
                child: PcEmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'File vide',
                  message: 'Aucun ticket en attente de traitement.',
                  tone: PcTone.green,
                ),
              )
            else
              for (final ticket in queue.take(4)) ...[
                _TicketCard(ticket: ticket),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _SlaAlertCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SlaAlertCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      onTap: onTap,
      color: AppTheme.red50,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.red100,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                size: 22, color: AppTheme.red500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ticket${count > 1 ? 's' : ''} en dépassement de SLA',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.red500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'À traiter avant toute nouvelle demande',
                  style: AppFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.red500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.red500),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onSeeTickets;
  final VoidCallback onSeeIncidents;

  const _QuickActionsRow({
    required this.onSeeTickets,
    required this.onSeeIncidents,
  });

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          PcListRow(
            icon: Icons.forum_rounded,
            iconTone: PcTone.primary,
            title: 'Messagerie support',
            subtitle: 'Répondre aux conversations en direct',
            chevron: true,
            // Cette vue existe déjà dans le tableau de bord : rester dans
            // l'IndexedStack évite d'empiler une seconde page identique.
            onTap: onSeeTickets,
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.contact_support_rounded,
            iconTone: PcTone.green,
            title: 'Mes assistances',
            subtitle: 'Codifier une assistance rendue',
            chevron: true,
            onTap: () => context.push('/support-tech/assistances'),
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.bug_report_rounded,
            iconTone: PcTone.red,
            title: 'Incidents plateforme',
            subtitle: 'Pannes et dégradations en cours',
            chevron: true,
            onTap: onSeeIncidents,
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.menu_book_rounded,
            iconTone: PcTone.neutral,
            title: 'Base de connaissances',
            subtitle: 'Procédures et réponses types',
            chevron: true,
            onTap: () => context.push('/help'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Onglet « Tickets »
// ============================================================

class _TicketsTab extends ConsumerWidget {
  const _TicketsTab();

  Future<void> _takeCharge(
    BuildContext context,
    WidgetRef ref,
    SupportTicket ticket,
  ) async {
    try {
      await ref
          .read(supportRolesApiProvider)
          .updateTicket(ticket.id, status: TicketStatus.inProgress);
      invalidateSupportTechnique(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ticket.reference} pris en charge')),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SupportTechniqueDashboard] Échec de prise en charge du ticket '
        '${ticket.id}: $error',
      );
      debugPrintStack(
        label: 'SupportTechniqueDashboard._takeCharge',
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

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    SupportTicket ticket,
  ) async {
    try {
      await ref
          .read(supportRolesApiProvider)
          .updateTicket(ticket.id, status: TicketStatus.resolved);
      invalidateSupportTechnique(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ticket.reference} résolu')),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SupportTechniqueDashboard] Échec de résolution du ticket '
        '${ticket.id}: $error',
      );
      debugPrintStack(
        label: 'SupportTechniqueDashboard._resolveTicket',
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
    final filter = ref.watch(ticketFilterProvider);
    final ticketsAsync = ref.watch(supportTicketsProvider);

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
                    'File de tickets',
                    style: AppFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Le filtre est appliqué côté serveur : les compteurs par
                  // statut ne sont donc pas déductibles de la page affichée.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Tous',
                          selected: filter == null,
                          onTap: () => ref
                              .read(ticketFilterProvider.notifier)
                              .state = null,
                        ),
                        for (final status in TicketStatus.values) ...[
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: status.label,
                            selected: filter == status,
                            onTap: () => ref
                                .read(ticketFilterProvider.notifier)
                                .state = status,
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
          child: ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: RoleErrorCard(
                error: error,
                onRetry: () => ref.invalidate(supportTicketsProvider),
              ),
            ),
            data: (tickets) => tickets.isEmpty
                ? const PcEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'Aucun ticket',
                    message: 'Aucun ticket ne correspond à ce filtre.',
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      invalidateSupportTechnique(ref);
                      await ref.read(supportTicketsProvider.future);
                    },
                    child: ListView(
                      key: const PageStorageKey('support-technique-tickets'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        for (final ticket in tickets) ...[
                          _TicketCard(
                            ticket: ticket,
                            onTakeCharge:
                                ticket.status == TicketStatus.resolved ||
                                        ticket.status == TicketStatus.inProgress
                                    ? null
                                    : () => _takeCharge(context, ref, ticket),
                            onResolve: ticket.status == TicketStatus.resolved
                                ? null
                                : () => _resolve(context, ref, ticket),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback? onTakeCharge;
  final VoidCallback? onResolve;

  const _TicketCard({required this.ticket, this.onTakeCharge, this.onResolve});

  String get _slaLabel {
    final sla = ticket.slaRemaining;
    if (sla == null) return 'Pas de SLA';
    return sla.isNegative
        ? 'SLA dépassé de ${formatShortDuration(sla)}'
        : 'SLA dans ${formatShortDuration(sla)}';
  }

  @override
  Widget build(BuildContext context) {
    final breached = ticket.isSlaBreached;

    return PcCard(
      accent: breached ? AppTheme.red400 : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                ticket.reference,
                style: AppTheme.mono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                ),
              ),
              PcBadge(ticket.priority.label, tone: ticket.priority.tone),
              PcBadge(ticket.status.label, tone: ticket.status.tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ticket.subject,
            style: AppFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PcAvatar(ticket.requesterName ?? '?', size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _requesterLabel(ticket),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const PcDivider(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PcMeta(ticket.channel.icon, ticket.channel.label),
              PcMeta(
                Icons.schedule_rounded,
                'ouvert depuis ${formatShortDuration(ticket.age)}',
              ),
              Text(
                _slaLabel,
                style: AppFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: breached ? AppTheme.red500 : AppTheme.green700,
                ),
              ),
            ],
          ),
          if (onTakeCharge != null || onResolve != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onTakeCharge != null)
                  Expanded(
                    child: PcButton(
                      'Prendre en charge',
                      icon: Icons.play_arrow_rounded,
                      size: PcButtonSize.sm,
                      variant: PcButtonVariant.secondary,
                      onPressed: onTakeCharge,
                    ),
                  ),
                if (onTakeCharge != null && onResolve != null)
                  const SizedBox(width: 10),
                if (onResolve != null)
                  Expanded(
                    child: PcButton(
                      'Résoudre',
                      icon: Icons.check_rounded,
                      size: PcButtonSize.sm,
                      onPressed: onResolve,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _requesterLabel(SupportTicket ticket) {
    final name = ticket.requesterName ?? 'Demandeur inconnu';
    final role = ticket.requesterRole;
    if (role == null || role.isEmpty) return name;
    return '$name · ${UserRole.fromString(role).identity.label}';
  }
}

// ============================================================
// Onglet « Incidents »
// ============================================================

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(platformIncidentsProvider);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(platformIncidentsProvider);
        await ref.read(platformIncidentsProvider.future);
      },
      child: ListView(
        key: const PageStorageKey('support-technique-incidents'),
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
                    'Incidents plateforme',
                    style: AppFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pannes et dégradations affectant plusieurs utilisateurs',
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
          incidentsAsync.when(
            loading: () => const RoleLoadingBlock(height: 180),
            error: (error, _) => RoleErrorCard(
              error: error,
              onRetry: () => ref.invalidate(platformIncidentsProvider),
            ),
            data: (incidents) => incidents.isEmpty
                ? const PcEmptyState(
                    icon: Icons.verified_rounded,
                    title: 'Aucun incident en cours',
                    message: 'Tous les services fonctionnent normalement.',
                    tone: PcTone.green,
                  )
                : Column(
                    children: [
                      for (final incident in incidents) ...[
                        _IncidentCard(
                          incident: incident,
                          onResolve: () => _resolve(context, ref, incident),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref,
    PlatformIncident incident,
  ) async {
    try {
      await ref.read(supportRolesApiProvider).resolveIncident(incident.id);
      invalidateSupportTechnique(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident clôturé')),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[SupportTechniqueDashboard] Échec de clôture de l’incident '
        '${incident.id}: $error',
      );
      debugPrintStack(
        label: 'SupportTechniqueDashboard._resolveIncident',
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
}

class _IncidentCard extends StatelessWidget {
  final PlatformIncident incident;
  final VoidCallback? onResolve;

  const _IncidentCard({required this.incident, this.onResolve});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PcBadge(
                incident.severity.label,
                tone: incident.severity.tone,
                variant: PcBadgeVariant.solid,
              ),
              PcBadge(
                incident.mitigated ? 'Contournement actif' : 'Non mitigé',
                tone: incident.mitigated ? PcTone.green : PcTone.red,
              ),
              Text(
                'depuis ${formatShortDuration(incident.since)}',
                style: AppTheme.mono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            incident.title,
            style: AppFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            incident.scope,
            style: AppFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PcMeta(Icons.group_rounded,
                  '${formatAmount(incident.impactedUsers)} utilisateurs touchés'),
              if (onResolve != null)
                PcButton(
                  'Clôturer',
                  icon: Icons.check_circle_rounded,
                  size: PcButtonSize.sm,
                  variant: PcButtonVariant.secondary,
                  onPressed: onResolve,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
