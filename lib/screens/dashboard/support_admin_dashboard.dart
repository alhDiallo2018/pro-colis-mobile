// lib/screens/dashboard/support_admin_dashboard.dart
//
// Espace du rôle `support` générique — équivalent mobile de `/support-admin`
// côté web (`ProColis-Web/src/routes/index.tsx`, SUPPORT_NAV).
//
// Contrairement aux supports technique et commercial, qui ont leurs propres
// endpoints (`/support-technique/*`, `/support-commercial/*`), le rôle
// `support` travaille sur les ressources du super admin en lecture assistée :
// conversations, assistances, colis, chauffeurs, utilisateurs. L'API autorise
// `support` sur ces routes au même titre que `super_admin`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/role_profile.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/broadcast_banner.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../profile/profile_screen.dart';
import '../shared/admin_support_screen.dart';
import '../super-admin/assistances_screen.dart';
import '../super-admin/chauffeurs_management_screen.dart';
import '../super-admin/colis_management_screen.dart';
import '../super-admin/users_management_screen.dart';
import 'notifications/notifications_screen.dart';
import 'role_dashboard_widgets.dart';

/// Conversations de support ouvertes, rafraîchies au pull-to-refresh.
final supportAdminConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ApiService().adminSupportConversations(),
);

/// Journal des assistances + son résumé (`{assistances, summary}`).
final supportAdminAssistancesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ApiService().getAssistances(),
);

void invalidateSupportAdmin(WidgetRef ref) {
  ref.invalidate(supportAdminConversationsProvider);
  ref.invalidate(supportAdminAssistancesProvider);
}

class SupportAdminDashboard extends ConsumerStatefulWidget {
  /// Onglet ouvert au premier affichage (utilisé par les routes profondes).
  final int initialTab;

  const SupportAdminDashboard({super.key, this.initialTab = 0});

  @override
  ConsumerState<SupportAdminDashboard> createState() =>
      _SupportAdminDashboardState();
}

class _SupportAdminDashboardState extends ConsumerState<SupportAdminDashboard> {
  late int _selectedIndex = widget.initialTab;

  /// Doit rester égal au nombre d'onglets de la barre ci-dessous et à celui
  /// déclaré pour ce rôle dans `AppBottomNav`.
  static const int _tabCount = 5;

  void _goToTab(int index) {
    setState(() => _selectedIndex = index);
    ref.read(dashboardTabProvider.notifier).state = index;
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openChauffeurs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChauffeursManagementScreen()),
    );
  }

  void _openUtilisateurs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UsersManagementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (next != _selectedIndex && next >= 0 && next < _tabCount) {
        setState(() => _selectedIndex = next);
      }
    });

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Le badge « non lues » vient des conversations : tant qu'elles chargent,
    // pas de badge plutôt qu'un zéro qui se lirait « rien à traiter ».
    final conversations =
        ref.watch(supportAdminConversationsProvider).valueOrNull;
    final unread = conversations == null
        ? null
        : conversations.where((c) => c['isRead'] != true).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _screenFor(_selectedIndex, user),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: _goToTab,
        items: [
          const ProcolisTabItem(
              icon: Icons.dashboard_rounded, label: 'Tableau'),
          ProcolisTabItem(
            icon: Icons.forum_rounded,
            label: 'Support',
            badge: unread,
          ),
          const ProcolisTabItem(
              icon: Icons.contact_support_rounded, label: 'Assistances'),
          const ProcolisTabItem(
              icon: Icons.inventory_2_rounded, label: 'Colis'),
          const ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }

  Widget _screenFor(int index, User user) {
    switch (index) {
      case 1:
        return const AdminSupportScreen();
      case 2:
        return const AssistancesScreen();
      case 3:
        return const ColisManagementScreen(embedded: true);
      case 4:
        return const ProfileScreen(embedded: true);
      default:
        return _SupportAdminHome(
          user: user,
          onNotificationsTap: _openNotifications,
          onSeeConversations: () => _goToTab(1),
          onSeeAssistances: () => _goToTab(2),
          onSeeChauffeurs: _openChauffeurs,
          onSeeUtilisateurs: _openUtilisateurs,
          onSeeProfile: () => _goToTab(4),
        );
    }
  }
}

// ============================================================
// Onglet « Tableau »
// ============================================================

class _SupportAdminHome extends ConsumerWidget {
  final User user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSeeConversations;
  final VoidCallback onSeeAssistances;
  final VoidCallback onSeeChauffeurs;
  final VoidCallback onSeeUtilisateurs;
  final VoidCallback onSeeProfile;

  const _SupportAdminHome({
    required this.user,
    required this.onNotificationsTap,
    required this.onSeeConversations,
    required this.onSeeAssistances,
    required this.onSeeChauffeurs,
    required this.onSeeUtilisateurs,
    required this.onSeeProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(supportAdminConversationsProvider);
    final assistancesAsync = ref.watch(supportAdminAssistancesProvider);

    final conversations = conversationsAsync.valueOrNull ?? const [];
    final unread = conversations.where((c) => c['isRead'] != true).length;
    final handledByMe = conversations.where((c) {
      final agents = c['agents'];
      if (agents is List && agents.any((a) => a is Map && a['id'] == user.id)) {
        return true;
      }
      final lastAgent = c['lastAgent'];
      return lastAgent is Map && lastAgent['id'] == user.id;
    }).length;

    final summary = assistancesAsync.valueOrNull?['summary'];
    final summaryMap = summary is Map ? summary : const <String, dynamic>{};

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        invalidateSupportAdmin(ref);
        await ref.read(supportAdminConversationsProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          RoleDashboardHero(
            user: user,
            intro: unread > 0
                ? '$unread conversation${unread > 1 ? 's' : ''} à traiter'
                : 'Aucune conversation en attente',
            onNotificationsTap: onNotificationsTap,
            unreadCount: unread,
            onProfileTap: onSeeProfile,
          ),
          // Les annonces super-admin s'affichent sous le hero du rôle.
          const BroadcastBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (conversationsAsync.isLoading &&
                    conversationsAsync.valueOrNull == null)
                  const RoleLoadingBlock(height: 200)
                else ...[
                  RoleKpiGrid(
                    stats: [
                      RoleStat(
                        icon: Icons.forum_rounded,
                        value: '${conversations.length}',
                        label: 'Conversations',
                        tone: PcTone.primary,
                      ),
                      RoleStat(
                        icon: Icons.mark_email_unread_rounded,
                        value: '$unread',
                        label: 'Non lues',
                        tone: PcTone.amber,
                      ),
                      RoleStat(
                        icon: Icons.how_to_reg_rounded,
                        value: '$handledByMe',
                        label: 'Traitées par moi',
                        tone: PcTone.green,
                      ),
                      RoleStat(
                        icon: Icons.contact_support_rounded,
                        value: _count(summaryMap['open']),
                        label: 'Assistances ouvertes',
                        tone: PcTone.neutral,
                      ),
                      RoleStat(
                        icon: Icons.pending_actions_rounded,
                        value: _count(summaryMap['inProgress']),
                        label: 'En cours',
                        tone: PcTone.amber,
                      ),
                      RoleStat(
                        icon: Icons.task_alt_rounded,
                        value: _count(summaryMap['resolved']),
                        label: 'Résolues',
                        tone: PcTone.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  RoleListHeader(
                    title: 'Dernières conversations',
                    count: conversations.length,
                    actionLabel: 'Tout voir',
                    onAction: onSeeConversations,
                  ),
                  if (conversations.isEmpty)
                    const _EmptyLine('Aucune conversation pour le moment.')
                  else
                    ...conversations.take(6).map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ConversationLine(
                              conversation: c,
                              onTap: onSeeConversations,
                            ),
                          ),
                        ),
                  const SizedBox(height: 22),
                  RoleListHeader(
                    title: 'Assistances récentes',
                    count: _assistances(assistancesAsync.valueOrNull).length,
                    actionLabel: 'Tout voir',
                    onAction: onSeeAssistances,
                  ),
                  if (_assistances(assistancesAsync.valueOrNull).isEmpty)
                    const _EmptyLine('Aucune assistance enregistrée.')
                  else
                    ..._assistances(assistancesAsync.valueOrNull).take(5).map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AssistanceLine(assistance: a),
                          ),
                        ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PcButton(
                          'Chauffeurs',
                          icon: Icons.local_shipping_rounded,
                          variant: PcButtonVariant.secondary,
                          size: PcButtonSize.sm,
                          onPressed: onSeeChauffeurs,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PcButton(
                          'Utilisateurs',
                          icon: Icons.group_rounded,
                          variant: PcButtonVariant.secondary,
                          size: PcButtonSize.sm,
                          onPressed: onSeeUtilisateurs,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `—` plutôt que `0` quand le résumé n'est pas encore arrivé : un zéro se
  /// lirait comme « rien à traiter ».
  static String _count(dynamic value) =>
      value == null ? '—' : '${value is num ? value.toInt() : value}';

  static List<Map<String, dynamic>> _assistances(Map<String, dynamic>? data) {
    final list = data?['assistances'];
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }
}

class _ConversationLine extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const _ConversationLine({required this.conversation, required this.onTap});

  static const _roleLabels = {
    'client': 'Client',
    'driver': 'Chauffeur',
    'admin': 'Admin zone',
    'super_admin': 'Super admin',
    'support': 'Support',
    'support_technique': 'Support technique',
    'support_commercial': 'Support commercial',
  };

  @override
  Widget build(BuildContext context) {
    final peer = conversation['user'];
    final peerMap = peer is Map ? peer : const {};
    final name = (peerMap['fullName'] ?? 'Utilisateur').toString();
    final role = (peerMap['role'] ?? '').toString();
    final body = (conversation['body'] ?? '').toString();
    final isRead = conversation['isRead'] == true;

    return PcCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.slate100,
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: AppFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.slate500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        _roleLabels[role] ?? role,
                        style: AppFonts.manrope(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate400,
                        ),
                      ),
                    ],
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isRead) ...[
            const SizedBox(width: 8),
            const PcBadge('Non lue', tone: PcTone.amber),
          ],
        ],
      ),
    );
  }
}

class _AssistanceLine extends StatelessWidget {
  final Map<String, dynamic> assistance;

  const _AssistanceLine({required this.assistance});

  @override
  Widget build(BuildContext context) {
    final status = (assistance['status'] ?? 'open').toString();
    final user = assistance['user'];
    final who = (user is Map ? user['fullName'] : null) ??
        assistance['contactName'] ??
        '—';

    final (label, tone) = switch (status) {
      'resolved' => ('Résolue', PcTone.green),
      'in_progress' => ('En cours', PcTone.amber),
      _ => ('Ouverte', PcTone.primary),
    };

    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (assistance['subject'] ?? 'Assistance').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${assistance['code'] ?? '—'} · $who',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PcBadge(label, tone: tone),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String message;

  const _EmptyLine(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        message,
        style: AppFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.slate500,
        ),
      ),
    );
  }
}
