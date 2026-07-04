// mobile/lib/providers/auth_provider.dart
// Aligné sur l'API Web ProColis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_notifier.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    _loadUser();
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
    } catch (e) {
      await _apiService.clearToken();
      state = AuthState.unauthenticated();
    }
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
        state = AuthState.authenticated(user);
        return {'success': true};
      } else {
        state = AuthState.error(
            result['message']?.toString() ?? 'PIN incorrect');
        return {'success': false, 'message': result['message']};
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
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
    String? garageId,
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
      if (garageId != null && garageId.isNotEmpty)
        payload['garageId'] = garageId;

      final result = await _apiService.register(payload);

      if (result['accessToken'] != null) {
        final userData = result['user'];
        final User user = userData != null
            ? User.fromJson(userData)
            : await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
        return {'success': true};
      } else if (result['success'] == true) {
        // Cas où le token est déjà stocké via l'intercepteur
        final user = await _apiService.getCurrentUser();
        state = AuthState.authenticated(user);
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

  Future<void> logout() async {
    await _apiService.logout();
    state = AuthState.unauthenticated();
  }

  Future<void> refreshUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      state = AuthState.authenticated(user);
    } catch (e) {
      // ignore silently
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

  factory AuthState.initial() => AuthState(isLoading: false);
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
