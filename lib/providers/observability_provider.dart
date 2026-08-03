// lib/providers/observability_provider.dart
//
// État des écrans « Journaux techniques » et « Journal d'audit ».
//
// La liste des journaux est paginée par curseur : elle ne peut donc pas être un
// simple `FutureProvider`, sinon chaque page suivante rejouerait la requête
// initiale et perdrait les entrées déjà chargées. Le résumé et l'état des
// services, eux, sont de simples lectures rejouables.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/observability.dart';
import '../services/api/client.dart';
import '../services/api/observability_api.dart';

final observabilityApiProvider =
    Provider<ObservabilityApi>((ref) => ObservabilityApi(ApiClient()));

/// Fenêtre par défaut : la dernière heure, comme le défaut serveur.
LogFilters defaultLogFilters() {
  final now = DateTime.now();
  return LogFilters(from: now.subtract(const Duration(hours: 1)), to: now);
}

/// Filtres courants de l'écran des journaux. Séparés de l'état de la liste :
/// changer un filtre relance le chargement, mais l'écran doit pouvoir afficher
/// le formulaire de filtres même quand la requête échoue.
final logFiltersProvider =
    StateProvider.autoDispose<LogFilters>((ref) => defaultLogFilters());

/// Résumé de la période filtrée. Le bandeau des services en est tiré : le
/// serveur le renvoie déjà dans le résumé, un appel séparé à `/services` serait
/// redondant à l'ouverture de l'écran.
final observabilitySummaryProvider =
    FutureProvider.autoDispose<ObservabilitySummary>((ref) {
  final filters = ref.watch(logFiltersProvider);
  return ref.watch(observabilityApiProvider).summary(filters);
});

/// État des services seuls — utilisé par le rafraîchissement du bandeau, sans
/// recharger tous les compteurs.
final serviceHealthProvider =
    FutureProvider.autoDispose<List<ServiceHealth>>((ref) {
  return ref.watch(observabilityApiProvider).services();
});

/// État de la liste paginée des journaux.
class LogListState {
  final List<LogEntry> entries;
  final String? nextCursor;
  final bool hasMore;

  /// Chargement de la première page : l'écran affiche un indicateur plein.
  final bool isLoading;

  /// Chargement d'une page suivante : l'écran garde la liste et affiche un
  /// indicateur en pied.
  final bool isLoadingMore;
  final ObservabilityApiException? error;

  /// Vrai quand le serveur a restreint les entrées (support technique).
  final bool isRedacted;

  const LogListState({
    this.entries = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.isRedacted = false,
  });

  /// [clearCursor] est explicite : un `copyWith` qui perdrait le curseur en
  /// silence casserait la pagination au premier appel qui l'omet.
  LogListState copyWith({
    List<LogEntry>? entries,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    ObservabilityApiException? error,
    bool clearError = false,
    bool? isRedacted,
  }) =>
      LogListState(
        entries: entries ?? this.entries,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        isRedacted: isRedacted ?? this.isRedacted,
      );

  bool get isEmpty => entries.isEmpty && !isLoading && error == null;
}

class LogListNotifier extends StateNotifier<LogListState> {
  final ObservabilityApi _api;
  LogFilters _filters;

  LogListNotifier(this._api, this._filters) : super(const LogListState()) {
    refresh();
  }

  /// Appelé quand les filtres changent : la liste repart de zéro, le curseur
  /// courant ne vaut plus rien pour une autre requête.
  void applyFilters(LogFilters filters) {
    _filters = filters;
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _api.logs(_filters);
      if (!mounted) return;
      state = LogListState(
        entries: result.logs,
        nextCursor: result.page.nextCursor,
        hasMore: result.page.hasMore,
        isRedacted: result.isRedacted,
      );
    } on ObservabilityApiException catch (e) {
      if (!mounted) return;
      state = LogListState(error: e);
    } catch (e) {
      if (!mounted) return;
      state = LogListState(
        error: ObservabilityApiException(e.toString()),
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (!state.hasMore ||
        cursor == null ||
        state.isLoadingMore ||
        state.isLoading) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _api.logs(_filters, cursor: cursor);
      if (!mounted) return;
      state = LogListState(
        entries: [...state.entries, ...result.logs],
        nextCursor: result.page.nextCursor,
        hasMore: result.page.hasMore,
        isRedacted: state.isRedacted || result.isRedacted,
      );
    } on ObservabilityApiException catch (e) {
      if (!mounted) return;
      // La page suivante a échoué : on garde les entrées déjà lues et le
      // curseur, pour que l'utilisateur puisse réessayer sans tout recharger.
      state = state.copyWith(isLoadingMore: false, error: e);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: ObservabilityApiException(e.toString()),
      );
    }
  }
}

final logListProvider =
    StateNotifierProvider.autoDispose<LogListNotifier, LogListState>((ref) {
  final filters = ref.watch(logFiltersProvider);
  return LogListNotifier(ref.watch(observabilityApiProvider), filters);
});

// ============================================================
// Journal d'audit
// ============================================================

/// Filtres du journal d'audit. Pagination classique par page : contrairement
/// aux journaux techniques, l'API renvoie ici un `pagination` complet.
class AuditFilters {
  final String search;
  final String actorRole;
  final DateTime? from;
  final DateTime? to;

  const AuditFilters({
    this.search = '',
    this.actorRole = '',
    this.from,
    this.to,
  });

  AuditFilters copyWith({
    String? search,
    String? actorRole,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) =>
      AuditFilters(
        search: search ?? this.search,
        actorRole: actorRole ?? this.actorRole,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

final auditFiltersProvider =
    StateProvider.autoDispose<AuditFilters>((ref) => const AuditFilters());

class AuditLogsState {
  final List<AuditLogEntry> entries;
  final int page;
  final int totalPages;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final ObservabilityApiException? error;
  final bool isRedacted;

  const AuditLogsState({
    this.entries = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.isRedacted = false,
  });

  bool get hasMore => page < totalPages;
  bool get isEmpty => entries.isEmpty && !isLoading && error == null;
}

class AuditLogsNotifier extends StateNotifier<AuditLogsState> {
  final ObservabilityApi _api;
  AuditFilters _filters;

  static const int _pageSize = 25;

  AuditLogsNotifier(this._api, this._filters) : super(const AuditLogsState()) {
    refresh();
  }

  void applyFilters(AuditFilters filters) {
    _filters = filters;
    refresh();
  }

  Future<void> refresh() async {
    state = const AuditLogsState(isLoading: true);
    try {
      final result = await _fetch(1);
      if (!mounted) return;
      state = AuditLogsState(
        entries: result.entries,
        page: result.page,
        totalPages: result.totalPages,
        total: result.total,
        isRedacted: result.isRedacted,
      );
    } on ObservabilityApiException catch (e) {
      if (!mounted) return;
      state = AuditLogsState(error: e);
    } catch (e) {
      if (!mounted) return;
      state = AuditLogsState(error: ObservabilityApiException(e.toString()));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;

    state = AuditLogsState(
      entries: state.entries,
      page: state.page,
      totalPages: state.totalPages,
      total: state.total,
      isLoadingMore: true,
      isRedacted: state.isRedacted,
    );
    try {
      final result = await _fetch(state.page + 1);
      if (!mounted) return;
      state = AuditLogsState(
        entries: [...state.entries, ...result.entries],
        page: result.page,
        totalPages: result.totalPages,
        total: result.total,
        isRedacted: state.isRedacted || result.isRedacted,
      );
    } on ObservabilityApiException catch (e) {
      if (!mounted) return;
      // On conserve les lignes déjà lues : seule la page suivante a échoué.
      state = AuditLogsState(
        entries: state.entries,
        page: state.page,
        totalPages: state.totalPages,
        total: state.total,
        error: e,
        isRedacted: state.isRedacted,
      );
    }
  }

  Future<AuditLogPage> _fetch(int page) => _api.auditLogs(
        page: page,
        limit: _pageSize,
        search: _filters.search,
        actorRole: _filters.actorRole,
        from: _filters.from,
        to: _filters.to,
      );
}

final auditLogsProvider =
    StateNotifierProvider.autoDispose<AuditLogsNotifier, AuditLogsState>((ref) {
  final filters = ref.watch(auditFiltersProvider);
  return AuditLogsNotifier(ref.watch(observabilityApiProvider), filters);
});
