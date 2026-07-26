// lib/screens/dashboard/role_dashboard_widgets.dart
//
// Briques communes aux dashboards de rôle : bandeau d'en-tête, grille de KPI,
// carte de série, répartition et jauge d'objectif.
//
// Les dashboards client / chauffeur / admin zone / super admin sont antérieurs
// et gardent leur mise en page propre. Ces briques servent aux espaces support
// et sont conçues pour être réutilisables si les autres sont harmonisés.

import 'package:flutter/material.dart';

import '../../models/role_profile.dart';
import '../../models/support.dart';
import '../../models/user.dart';
import '../../services/api/support_roles_api.dart' show SupportApiException;
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../theme/role_identity.dart';
import '../../widgets/bar_chart.dart';
import '../../widgets/pc_components.dart';

// ============================================================
// Bandeau d'en-tête
// ============================================================

/// Bandeau haut du dashboard, aux couleurs du rôle.
class RoleDashboardHero extends StatelessWidget {
  final User? user;

  /// Ligne d'accroche ; par défaut celle de l'identité du rôle.
  final String? intro;

  final VoidCallback? onNotificationsTap;
  final int unreadCount;

  /// Contenu additionnel sous l'accroche (chips de contexte, jauge…).
  final Widget? footer;

  const RoleDashboardHero({
    super.key,
    required this.user,
    this.intro,
    this.onNotificationsTap,
    this.unreadCount = 0,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final role = user?.role ?? UserRole.client;
    final identity = role.identity;
    final photo = user?.profilePhoto;
    final photoUrl = (photo != null && photo.isNotEmpty)
        ? ApiService.resolveMediaUrl(photo)
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: identity.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white.withAlpha(48),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl != null
                        ? null
                        : Text(
                            user?.initials ?? '?',
                            style: AppFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
                            Icon(identity.icon,
                                size: 15, color: Colors.white.withAlpha(220)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                identity.spaceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.manrope(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          user?.fullName ?? 'Utilisateur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onNotificationsTap != null)
                    IconButton(
                      onPressed: onNotificationsTap,
                      color: Colors.white,
                      tooltip: 'Notifications',
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_rounded, size: 27),
                          if (unreadCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.amber400,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: identity.accent, width: 2),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: AppTheme.amberOnFg,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                intro ?? identity.dashboardIntro,
                style: AppFonts.manrope(
                  color: Colors.white.withAlpha(220),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 14),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille de contexte posée sur le bandeau (secteur, astreinte, niveau…).
class HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const HeroChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Grille de KPI
// ============================================================

/// Grille de tuiles KPI, adaptative pour préserver la lisibilité sur mobile.
class RoleKpiGrid extends StatelessWidget {
  final List<RoleStat> stats;

  const RoleKpiGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sous 400 px, une seule tuile par ligne évite que les valeurs et les
        // libellés support soient comprimés ou superposés.
        if (constraints.maxWidth < 400) {
          return Column(
            children: [
              for (var index = 0; index < stats.length; index++) ...[
                _statBox(stats[index]),
                if (index < stats.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < stats.length; i += 2) {
          final left = stats[i];
          final right = i + 1 < stats.length ? stats[i + 1] : null;
          if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _statBox(left)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: right == null
                        ? const SizedBox.shrink()
                        : _statBox(right),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _statBox(RoleStat stat) => PcStatBox(
        icon: stat.icon,
        value: stat.value,
        label: stat.label,
        tone: stat.tone,
      );
}

// ============================================================
// Carte de série (graphique)
// ============================================================

class RoleSeriesCard extends StatelessWidget {
  final RoleSeries series;
  final String? subtitle;

  const RoleSeriesCard({super.key, required this.series, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  series.title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                '${series.total} ${series.unit}',
                style: AppTheme.mono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.slate500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // PcBarChart appelle `reduce` sur ses barres : une série vide (API
          // sans données sur la période) le ferait planter.
          if (series.isEmpty)
            Text(
              'Aucune donnée sur la période',
              style: AppFonts.manrope(fontSize: 13, color: AppTheme.slate500),
            )
          else
            PcBarChart(
              bars: series.values.map((v) => v.toDouble()).toList(),
              labels: series.labels,
              highlightLast: true,
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Répartition
// ============================================================

/// Barre de répartition empilée + légende chiffrée.
///
/// Les couleurs sont attribuées ici et non portées par [RoleBreakdown] : les
/// catégories viennent de l'API (libellés libres), il n'y a pas de palette
/// stable à leur associer côté serveur.
class RoleBreakdownCard extends StatelessWidget {
  final String title;
  final List<RoleBreakdown> items;

  /// Palette par défaut, parcourue dans l'ordre des catégories reçues.
  static const List<Color> defaultPalette = [
    AppTheme.teal500,
    AppTheme.amber400,
    Color(0xFF7C3AED),
    AppTheme.green500,
    AppTheme.red400,
    AppTheme.deep500,
  ];

  const RoleBreakdownCard({
    super.key,
    required this.title,
    required this.items,
  });

  Color _colorFor(int index) => defaultPalette[index % defaultPalette.length];

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (a, b) => a + b.count);

    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (total == 0)
            Text(
              'Aucune donnée sur la période',
              style: AppFonts.manrope(
                fontSize: 13,
                color: AppTheme.slate500,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (int i = 0; i < items.length; i++)
                      if (items[i].count > 0)
                        Expanded(
                          flex: items[i].count,
                          child: ColoredBox(color: _colorFor(i)),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colorFor(i),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        items[i].label,
                        style: AppFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate700,
                        ),
                      ),
                    ),
                    Text(
                      '${items[i].count}',
                      style: AppTheme.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${((items[i].count / total) * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: AppFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Jauge d'objectif
// ============================================================

class RoleObjectiveCard extends StatelessWidget {
  final String title;
  final String currentLabel;
  final String targetLabel;
  final double progress;
  final int percent;
  final Color accent;

  const RoleObjectiveCard({
    super.key,
    required this.title,
    required this.currentLabel,
    required this.targetLabel,
    required this.progress,
    required this.percent,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final reached = percent >= 100;

    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              PcBadge(
                reached ? 'Objectif atteint' : '$percent %',
                tone: reached ? PcTone.green : PcTone.amber,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            currentLabel,
            style: AppFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'sur $targetLabel visés ce mois',
            style: AppFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppTheme.slate100,
              valueColor: AlwaysStoppedAnimation<Color>(
                reached ? AppTheme.green500 : accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// En-tête de section avec compteur
// ============================================================

class RoleListHeader extends StatelessWidget {
  final String title;
  final int count;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RoleListHeader({
    super.key,
    required this.title,
    required this.count,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Text(
            title,
            style: AppFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          PcBadge('$count', tone: PcTone.neutral),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.teal600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// États asynchrones
// ============================================================

/// Bloc d'erreur avec réessai, pour un espace alimenté par l'API.
///
/// Distingue le refus de rôle du reste : « Erreur serveur » sur un 403
/// enverrait l'agent chercher une panne qui n'existe pas.
class RoleErrorCard extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const RoleErrorCard({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is SupportApiException
        ? (error as SupportApiException).message
        : 'Impossible de joindre le serveur.';
    final isForbidden = error is SupportApiException &&
        (error as SupportApiException).isForbidden;

    return PcCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isForbidden ? AppTheme.amber50 : AppTheme.red50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  isForbidden ? Icons.lock_rounded : Icons.cloud_off_rounded,
                  size: 22,
                  color: isForbidden ? AppTheme.amber600 : AppTheme.red500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isForbidden ? 'Accès refusé' : 'Chargement impossible',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: AppFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
              height: 1.45,
            ),
          ),
          if (!isForbidden) ...[
            const SizedBox(height: 14),
            PcButton(
              'Réessayer',
              icon: Icons.refresh_rounded,
              variant: PcButtonVariant.secondary,
              size: PcButtonSize.sm,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder de chargement à la hauteur du bloc qu'il remplace, pour éviter
/// que la page ne saute quand les données arrivent.
class RoleLoadingBlock extends StatelessWidget {
  final double height;

  const RoleLoadingBlock({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Formate une durée en libellé court (« 2 j », « 5 h », « 40 min »).
String formatShortDuration(Duration d) {
  final abs = d.abs();
  if (abs.inDays >= 1) return '${abs.inDays} j';
  if (abs.inHours >= 1) return '${abs.inHours} h';
  return '${abs.inMinutes} min';
}
