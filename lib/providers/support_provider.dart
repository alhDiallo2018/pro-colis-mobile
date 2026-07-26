// lib/providers/support_provider.dart
//
// Providers des espaces support. Les données viennent de l'API
// (`/support-technique/*`, `/support-commercial/*`) — plus de mock.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/support.dart';
import '../services/api/client.dart';
import '../services/api/support_roles_api.dart';

final supportRolesApiProvider = Provider<SupportRolesApi>((ref) {
  return SupportRolesApi(ApiClient());
});

// ---------------- Support technique ----------------

final supportTechniqueStatsProvider =
    FutureProvider<SupportTechniqueSummary>((ref) async {
  return ref.watch(supportRolesApiProvider).techniqueStats();
});

/// Filtre courant de la file de tickets. `null` = tous les statuts.
final ticketFilterProvider = StateProvider<TicketStatus?>((ref) => null);

/// File de tickets, filtrée côté serveur pour ne pas rapatrier toute la table.
final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final filter = ref.watch(ticketFilterProvider);
  return ref.watch(supportRolesApiProvider).tickets(status: filter?.value);
});

final platformIncidentsProvider =
    FutureProvider<List<PlatformIncident>>((ref) async {
  return ref.watch(supportRolesApiProvider).incidents();
});

// ---------------- Support commercial ----------------

final supportCommercialStatsProvider =
    FutureProvider<SupportCommercialSummary>((ref) async {
  return ref.watch(supportRolesApiProvider).commercialStats();
});

/// Filtre courant du pipeline. `null` = toutes les étapes.
final leadFilterProvider = StateProvider<LeadStage?>((ref) => null);

final commercialLeadsProvider = FutureProvider<List<CommercialLead>>((ref) async {
  final filter = ref.watch(leadFilterProvider);
  return ref.watch(supportRolesApiProvider).leads(stage: filter?.value);
});

final networkCoverageProvider = FutureProvider<NetworkCoverage>((ref) async {
  return ref.watch(supportRolesApiProvider).coverage();
});

/// Recharge tout l'espace support technique après une action (prise en charge
/// d'un ticket, déclaration d'incident…) : les KPI dépendent des tickets, les
/// laisser en cache afficherait un compteur en contradiction avec la liste.
///
/// Prend un [WidgetRef] : ces helpers sont appelés depuis les écrans, et
/// `Ref` (côté provider) est un type distinct.
void invalidateSupportTechnique(WidgetRef ref) {
  ref.invalidate(supportTechniqueStatsProvider);
  ref.invalidate(supportTicketsProvider);
  ref.invalidate(platformIncidentsProvider);
}

void invalidateSupportCommercial(WidgetRef ref) {
  ref.invalidate(supportCommercialStatsProvider);
  ref.invalidate(commercialLeadsProvider);
  ref.invalidate(networkCoverageProvider);
}
