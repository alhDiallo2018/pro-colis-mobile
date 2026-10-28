// mobile/lib/providers/auth_provider.dart
// Aligné sur l'API Web ProColis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_session.dart';
import '../services/offline_access.dart';
import 'package:dio/dio.dart';
import '../services/biometric_service.dart';
import '../services/form_draft_store.dart';
import '../services/push_notification_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({ApiService? apiService})
      : _apiService = apiService ?? ApiService(),
        super(AuthState.initial()) {
    // Un 401 définitif (jeton expiré, rafraîchissement refusé) doit ramener à
    // l'écran de connexion : sinon l'application reste sur un écran authentifié
    // dont chaque requête échoue, qui tourne sans jamais rien afficher.
    ApiService.onSessionExpired = _handleSessionExpired;
    _sessionRestoration = _loadUser();
  }

  void _handleSessionExpired() {
    if (!mounted) return;
    OfflineAccess.instance.useSession(null);
    state = AuthState.unauthenticated();
  }

  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Future<void> _sessionRestoration;

  Future<void> _saveIdentifier(String identifier) async {
    await _storage.write(key: 'saved_identifier', value: identifier);
  }

  Future<String?> getSavedIdentifier() async {
    return await _storage.read(key: 'saved_identifier');
  }

  /// Sauvegarde le profil dès la connexion, sans attendre un prochain /me.
  /// Aucun PIN n'est retenu par le cache (filtrage dans AuthSessionManager).
  Future<void> _rememberProfile(User user) async {
    try {
      final session = await AuthSessionManager.instance.read();
      if (session == null || user.isStaff || !user.isActive) return;
      OfflineAccess.instance.useSession(session.generation);
      await AuthSessionManager.instance.saveCachedResponse(
        session.generation,
        OfflineAccessInterceptor.profileKey,
        {'user': user.toJson()},
      );
    } catch (error, stack) {
      debugPrint(
          '[AuthNotifier] Profil local indisponible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<bool> reconnect() async {
    try {
      final before = await AuthSessionManager.instance.read();
      final user = await _apiService.reconnectUser();
      final after = await AuthSessionManager.instance.read();
      if (!mounted || before == null || before.generation != after?.generation)
        return false;
      state = AuthState.authenticated(user);
      return true;
    } catch (error, stack) {
      debugPrint(
          '[AuthNotifier] Reconnexion indisponible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }

  Future<void> _loadUser({bool forceNetwork = false}) async {
    String? generation;
    try {
      final session = await AuthSessionManager.instance.read();
      if (!mounted) return;
      if (session == null) {
        state = AuthState.unauthenticated();
        return;
      }
      generation = session.generation;
      final user = forceNetwork
          ? await _apiService.reconnectUser()
          : await _apiService.getCurrentUser();
      final current = await AuthSessionManager.instance.read();
      if (!mounted || current?.generation != generation) return;
      state = AuthState.authenticated(user);
      if (!OfflineAccess.instance.value.disconnected) _registerPushToken();
    } catch (error, stackTrace) {
      // Ne pas journaliser les headers Dio, susceptibles de contenir le Bearer.
      debugPrint(
          '[AuthNotifier] Restauration indisponible (${error.runtimeType})');
      debugPrintStack(
          label: '[AuthNotifier] Restauration', stackTrace: stackTrace);
      if (!mounted) return;
      // Une restauration ancienne ne doit pas modifier une connexion recente.
      if (generation != null) {
        try {
          final current = await AuthSessionManager.instance.read();
          if (!mounted || (current != null && current.generation != generation))
            return;
        } catch (_) {
          if (!mounted || state.isAuthenticated) return;
        }
      }
      final cause = error is DioException ? error.error : error;
      if (cause is SessionChangedException) return;
      if (cause is SessionExpiredException) {
        state = AuthState.unauthenticated();
        return;
      }
      // Hors ligne/5xx : garder les jetons et proposer une restauration, sans
      // presenter un ancien profil comme une authentification serveur valide.
      state = AuthState.pendingSession(
          'Connexion indisponible. Votre session est conservée.');
    }
  }

  Future<void> retrySessionRestoration() async {
    if (!state.hasPendingSession) return;
    state = AuthState.loading();
    _sessionRestoration = _loadUser(forceNetwork: true);
    await _sessionRestoration;
  }

  /// Enregistre le token FCM côté backend (fire-and-forget, jamais bloquant).
  void _registerPushToken() {
    unawaited(PushNotificationService.registerTokenWithBackend());
  }

  // ==================== AUTH ====================

  /// Connexion par identifiant (email/téléphone) + code PIN à 6 chiffres
  Future<Map<String, dynamic>> loginWithPin(
      String pin, String identifier) async {
    await _sessionRestoration;
    final biometricEnabled = await BiometricService.isEnabled();
    final previousOwner = await BiometricService.currentOwner();
    state = AuthState.loading();
    try {
      final result = await _apiService.loginWithPin(pin, identifier);

      if (result['success'] == true || result['accessToken'] != null) {
        // L'identifiant biométrique ne doit changer qu'après une connexion
        // valide : une faute de frappe ne doit pas casser le prochain accès.
        await _saveIdentifier(identifier);
        final userData = result['user'];
        final User user = userData != null
            ? User.fromJson(userData)
            : await _apiService.getCurrentUser();
        debugPrint(
          '[AuthNotifier] Connexion réussie, rôle résolu : ${user.role.value}',
        );
        await _rememberProfile(user);
        if (biometricEnabled) {
          if (previousOwner == user.id)
            await BiometricService.enableForSession(user.id);
          else
            await BiometricService.disable();
        }
        state = AuthState.authenticated(user);
        _registerPushToken();
        return {'success': true};
      } else {
        state =
            AuthState.error(result['message']?.toString() ?? 'PIN incorrect');
        return {'success': false, 'message': result['message']};
      }
    } catch (error, stackTrace) {
      debugPrint('[AuthNotifier] Échec de la connexion PIN : $error');
      debugPrintStack(
        label: '[AuthNotifier] Trace de connexion PIN',
        stackTrace: stackTrace,
      );
      state = AuthState.error(error.toString());
      return {'success': false, 'message': error.toString()};
    }
  }

  /// Le SDK Google n'ouvre pas la session de l'app : seuls les jetons émis
  /// par notre API après association/inscription peuvent être mémorisés.
  Future<void> completeGoogleLogin(Map<String, dynamic> result) async {
    await _sessionRestoration;
    if (!mounted) return;
    if (result['status'] != 'authenticated' ||
        result['user'] is! Map ||
        result['accessToken'] is! String ||
        result['refreshToken'] is! String) {
      throw const FormatException('Réponse de connexion Google invalide');
    }
    final user = User.fromJson(Map<String, dynamic>.from(result['user']));
    final identifier = user.phone;
    final previousIdentifier = await getSavedIdentifier();
    // Sans PIN saisi, on ne peut pas remplacer le secret biométrique. Le
    // supprimer sur changement de compte évite de reconnecter l'ancien user.
    if (previousIdentifier != identifier) await BiometricService.disable();
    await _saveIdentifier(identifier);
    await AuthSessionManager.instance.establish(result);
    if (!mounted) return;
    state = AuthState.authenticated(user);
    await _rememberProfile(user);
    _registerPushToken();
  }

  /// Connexion avec le PIN uniquement (utilise l'identifiant sauvegardé)
  Future<Map<String, dynamic>> loginWithSavedPin(String pin) async {
    final savedIdentifier = await getSavedIdentifier();
    if (savedIdentifier == null || savedIdentifier.isEmpty) {
      state = AuthState.error('Session expirée. Veuillez vous reconnecter.');
      return {
        'success': false,
        'message': 'Session expirée. Veuillez vous reconnecter.'
      };
    }
    return loginWithPin(pin, savedIdentifier);
  }

  /// Inscription simplifiée (PIN direct, comme le Web)
  Future<Map<String, dynamic>> register({
    required String phone,
    required String fullName,
    String? email,
    required String pin,
    String role = 'client',
    String? address,
    String? city,
    String? region,
    String? zoneId,
  }) async {
    state = AuthState.loading();
    try {
      final payload = <String, dynamic>{
        'phone': phone,
        'fullName': fullName,
        'pin': pin,
        'role': role,
      };
      if (email != null && email.isNotEmpty) payload['email'] = email;
      if (address != null && address.isNotEmpty) payload['address'] = address;
      if (city != null && city.isNotEmpty) payload['city'] = city;
      if (region != null && region.isNotEmpty) payload['region'] = region;
      if (zoneId != null && zoneId.isNotEmpty) payload['zoneId'] = zoneId;

      final result = await _apiService.register(payload);

      if (result['accessToken'] != null) {
        await _saveIdentifier(phone);
        final userData = result['user'];
        final User user = userData != null
            ? User.fromJson(userData)
            : await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
        await _rememberProfile(user);
        _registerPushToken();
        return {'success': true};
      } else if (result['success'] == true) {
        // Cas où le token est déjà stocké via l'intercepteur
        await _saveIdentifier(phone);
        final user = await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
        await _rememberProfile(user);
        _registerPushToken();
        return {'success': true};
      } else {
        state = AuthState.error(
            result['message']?.toString() ?? 'Erreur inscription');
        return {'success': false, 'message': result['message']};
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Déverrouille une session endormie à partir de l'empreinte.
  ///
  /// Le verrou local ne revoque pas la session serveur. Une session restauree
  /// se déverrouille sans nouvelle connexion. Un refus serveur définitif
  /// impose une nouvelle authentification en ligne.
  Future<bool> unlockWithBiometrics() async {
    try {
      if (!await BiometricService.isEnabled()) return false;

      final approved = await BiometricService.authenticate(
        'Déverrouillez votre session SENDPROCOLIS',
      );
      if (!approved) return false;

      // Au démarrage à froid, la restauration du jeton et la demande système
      // peuvent progresser en parallèle. On attend la première pour éviter que
      // deux connexions concurrentes écrasent l'état utilisateur ou les jetons.
      await _sessionRestoration;
      if (state.isAuthenticated) return true;
      if (state.hasPendingSession) return _restoreLocalProfile();

      return false;
    } catch (error, stackTrace) {
      debugPrint(
          '[AuthNotifier] Déverrouillage biométrique impossible : $error');
      debugPrintStack(
        label: '[AuthNotifier] Trace de déverrouillage biométrique',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Rouvre seulement une copie liée à la session actuelle, après le contrôle
  /// biométrique. Une révocation explicite a déjà supprimé cette session.
  Future<bool> _restoreLocalProfile() async {
    final session = await AuthSessionManager.instance.read();
    if (session == null) return false;
    final entry = await AuthSessionManager.instance.readCachedResponse(
        session.generation, OfflineAccessInterceptor.profileKey);
    final data = entry?['data']?['user'];
    if (data is! Map) return false;
    final user = User.fromJson(Map<String, dynamic>.from(data));
    if (user.isStaff || !user.isActive) return false;
    if (!mounted ||
        (await AuthSessionManager.instance.read())?.generation !=
            session.generation) return false;
    OfflineAccess.instance.useSession(session.generation);
    OfflineAccess.instance.cached(
        OfflineAccessInterceptor.profileKey, DateTime.parse(entry!['savedAt']));
    state = AuthState.authenticated(user);
    return true;
  }

  /// [forgetBiometrics] distingue les deux sorties possibles.
  ///
  /// Une déconnexion explicite retire le réglage biométrique. La récupération
  /// du PIN peut le conserver, mais supprime toujours la session et son cache.
  /// Le déverrouillage par code de l'appareil ne passe jamais par logout.
  Future<void> logout({bool forgetBiometrics = true}) async {
    try {
      // Important au démarrage à froid : une restauration encore en cours ne
      // doit pas réauthentifier l'utilisateur juste après sa déconnexion.
      await _sessionRestoration;
      if (forgetBiometrics) await BiometricService.disable();
      await _apiService.logout();
    } catch (error, stackTrace) {
      debugPrint('[AuthNotifier] Déconnexion incomplète : $error');
      debugPrintStack(
        label: '[AuthNotifier] Trace de déconnexion',
        stackTrace: stackTrace,
      );
      // Même si la révocation distante ou le Keystore échoue, les jetons
      // locaux doivent disparaître pour fermer immédiatement l'application.
      try {
        await _apiService.clearToken();
      } catch (clearError, clearStackTrace) {
        debugPrint(
          '[AuthNotifier] Suppression locale des jetons impossible : '
          '$clearError',
        );
        debugPrintStack(
          label: '[AuthNotifier] Trace de suppression des jetons',
          stackTrace: clearStackTrace,
        );
      }
    } finally {
      // Les brouillons contiennent des coordonnées et des pièces jointes : ils
      // ne doivent jamais passer au compte suivant, même après une panne réseau.
      try {
        await FormDraftStore.clearAll();
      } catch (error, stackTrace) {
        debugPrint(
            '[AuthNotifier] Nettoyage des brouillons impossible : $error');
        debugPrintStack(
          label: '[AuthNotifier] Trace de nettoyage des brouillons',
          stackTrace: stackTrace,
        );
      }
      if (mounted) state = AuthState.unauthenticated();
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      state = AuthState.authenticated(user);
    } catch (error, stackTrace) {
      debugPrint(
        '[AuthNotifier] Impossible d’actualiser l’utilisateur : $error',
      );
      debugPrintStack(
        label: '[AuthNotifier] Trace d’actualisation utilisateur',
        stackTrace: stackTrace,
      );
    }
  }

  // ==================== PROFILE ====================

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String email,
    required String phone,
    String? address,
    String? city,
    String? region,
  }) async {
    try {
      final currentUser = state.user;
      if (currentUser == null) {
        return {'success': false, 'message': 'Non connecté'};
      }
      final result = await _apiService.updateProfile(currentUser.role, {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (region != null) 'region': region,
      });
      if (result['success'] == true) {
        await refreshUser();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePin(
      String currentPin, String newPin) async {
    try {
      final result = await _apiService.changePin(currentPin, newPin);

      // Le PIN sécurisé alimente la reconnexion biométrique. Il doit suivre le
      // changement serveur, sinon l'empreinte serait acceptée mais la connexion
      // échouerait avec l'ancien secret au prochain lancement.
      if (result['success'] == true && await BiometricService.isEnabled()) {
        try {
          await BiometricService.enable(newPin);
        } catch (error, stackTrace) {
          // Le changement serveur a déjà réussi : on le retourne comme tel et
          // journalise uniquement la désynchronisation locale.
          debugPrint(
            '[AuthNotifier] Mise à jour du PIN biométrique impossible : $error',
          );
          debugPrintStack(
            label: '[AuthNotifier] Trace de mise à jour du PIN biométrique',
            stackTrace: stackTrace,
          );
        }
      }
      return result;
    } catch (error, stackTrace) {
      debugPrint('[AuthNotifier] Changement de PIN impossible : $error');
      debugPrintStack(
        label: '[AuthNotifier] Trace de changement de PIN',
        stackTrace: stackTrace,
      );
      return {'success': false, 'message': error.toString()};
    }
  }

  Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      final result = await _apiService.updateDriverStatus(status);
      if (result['success'] == true) {
        await refreshUser();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

// ==================== AUTH STATE ====================

class AuthState {
  final bool isLoading;
  final User? user;
  final String? error;
  final bool isAuthenticated;
  final bool hasPendingSession;

  AuthState({
    required this.isLoading,
    this.user,
    this.error,
    this.isAuthenticated = false,
    this.hasPendingSession = false,
  });

  /// État de démarrage : `isLoading` est vrai pour que l'écran de splash (et le
  /// redirect GoRouter) attendent la fin de la restauration de session
  /// (`_loadUser`). Sans cela, le splash redirige vers `/landing` avant que la
  /// session ne soit résolue, ce qui fait rebondir l'utilisateur connecté.
  factory AuthState.initial() => AuthState(isLoading: true);
  factory AuthState.loading() => AuthState(isLoading: true);
  factory AuthState.authenticated(User? user) =>
      AuthState(isLoading: false, user: user, isAuthenticated: true);
  factory AuthState.unauthenticated() =>
      AuthState(isLoading: false, isAuthenticated: false);
  factory AuthState.pendingSession(String error) =>
      AuthState(isLoading: false, error: error, hasPendingSession: true);
  factory AuthState.error(String error) =>
      AuthState(isLoading: false, error: error);

  bool get isClient => user?.role == UserRole.client;
  bool get isDriver => user?.role == UserRole.driver;
  bool get isAdmin => user?.role == UserRole.admin;
  bool get isSupportTechnique => user?.role == UserRole.supportTechnique;
  bool get isSupportCommercial => user?.role == UserRole.supportCommercial;

  /// Rôle `support` générique de l'enum Prisma, distinct des deux rôles
  /// spécialisés. Il atterrit sur `/support-admin`, comme côté web.
  bool get isSupportShared => user?.role == UserRole.support;

  /// Équivalent de `SUPPORT_ROLES` du web : les trois rôles support réunis.
  /// Ne comprend pas `super_admin`, qui a son propre espace.
  bool get isSupport =>
      isSupportShared || isSupportTechnique || isSupportCommercial;
  bool get isSuperAdmin => user?.role == UserRole.superAdmin;
  String get displayName => user?.fullName.split(' ').first ?? 'Utilisateur';

  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? error,
    bool? isAuthenticated,
    bool? hasPendingSession,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasPendingSession: hasPendingSession ?? this.hasPendingSession,
    );
  }
}
