// mobile/lib/providers/auth_provider.dart
// Aligné sur l'API Web ProColis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:async';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/form_draft_store.dart';
import '../services/push_notification_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    // Un 401 définitif (jeton expiré, rafraîchissement refusé) doit ramener à
    // l'écran de connexion : sinon l'application reste sur un écran authentifié
    // dont chaque requête échoue, qui tourne sans jamais rien afficher.
    ApiService.onSessionExpired = _handleSessionExpired;
    _loadUser();
  }

  void _handleSessionExpired() {
    if (!mounted || !state.isAuthenticated) return;
    state = AuthState.unauthenticated();
  }

  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> _saveIdentifier(String identifier) async {
    await _storage.write(key: 'saved_identifier', value: identifier);
  }

  Future<String?> getSavedIdentifier() async {
    return await _storage.read(key: 'saved_identifier');
  }

  Future<void> _loadUser() async {
    try {
      final token = await _apiService.getToken();
      if (token == null || token.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }
      final user = await _apiService.getCurrentUser();
      state = AuthState.authenticated(user);
      _registerPushToken();
    } catch (error, stackTrace) {
      debugPrint(
        '[AuthNotifier] Impossible de restaurer la session : $error',
      );
      debugPrintStack(
        label: '[AuthNotifier] Trace de restauration de session',
        stackTrace: stackTrace,
      );
      await _apiService.clearToken();
      state = AuthState.unauthenticated();
    }
  }

  /// Enregistre le token FCM côté backend (fire-and-forget, jamais bloquant).
  void _registerPushToken() {
    unawaited(PushNotificationService.registerTokenWithBackend());
  }

  // ==================== AUTH ====================

  /// Connexion par identifiant (email/téléphone) + code PIN à 6 chiffres
  Future<Map<String, dynamic>> loginWithPin(
      String pin, String identifier) async {
    state = AuthState.loading();
    try {
      await _saveIdentifier(identifier);
      final result = await _apiService.loginWithPin(pin, identifier);

      if (result['success'] == true || result['accessToken'] != null) {
        final userData = result['user'];
        final User user = userData != null
            ? User.fromJson(userData)
            : await _apiService.getCurrentUser();
        debugPrint(
          '[AuthNotifier] Connexion réussie, rôle résolu : ${user.role.value}',
        );
        // Le déverrouillage biométrique rejoue une connexion PIN : si
        // l'utilisateur a changé de code, le secret mémorisé doit suivre, sinon
        // l'empreinte se met à échouer sans explication.
        if (await BiometricService.isEnabled()) {
          await BiometricService.enable(pin);
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
      await _saveIdentifier(phone);

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
      if (zoneId != null && zoneId.isNotEmpty)
        payload['zoneId'] = zoneId;

      final result = await _apiService.register(payload);

      if (result['accessToken'] != null) {
        final userData = result['user'];
        final User user = userData != null
            ? User.fromJson(userData)
            : await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
        _registerPushToken();
        return {'success': true};
      } else if (result['success'] == true) {
        // Cas où le token est déjà stocké via l'intercepteur
        final user = await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
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
  /// L'API ayant fermé la session pour inactivité, il ne s'agit pas de rouvrir
  /// un écran mais de refaire une vraie connexion : l'empreinte ne fait
  /// qu'autoriser la lecture du PIN mémorisé.
  Future<bool> unlockWithBiometrics() async {
    if (!await BiometricService.isEnabled()) return false;

    final approved = await BiometricService.authenticate(
      'Déverrouillez votre session SENDPROCOLIS',
    );
    if (!approved) return false;

    final pin = await BiometricService.readPin();
    if (pin == null || pin.isEmpty) return false;

    final result = await loginWithSavedPin(pin);
    return result['success'] == true;
  }

  /// [forgetBiometrics] distingue les deux sorties possibles.
  ///
  /// Une déconnexion explicite retire le secret : garder le PIN d'un compte que
  /// l'utilisateur vient de quitter n'apporterait aucun confort. Mais le repli
  /// « utiliser mon code PIN » de l'écran de verrouillage passe aussi par ici,
  /// et un doigt mouillé ne doit pas désactiver le réglage.
  Future<void> logout({bool forgetBiometrics = true}) async {
    if (forgetBiometrics) await BiometricService.disable();
    await _apiService.logout();
    // Les brouillons de formulaires contiennent des coordonnées de
    // destinataires et des pièces jointes : ils ne doivent rien laisser sur
    // l'appareil pour le compte suivant.
    await FormDraftStore.clearAll();
    state = AuthState.unauthenticated();
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
      return await _apiService.changePin(currentPin, newPin);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
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

  AuthState({
    required this.isLoading,
    this.user,
    this.error,
    this.isAuthenticated = false,
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
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
