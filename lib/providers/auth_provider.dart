// mobile/lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import '../services/api_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    _loadUser();
  }

  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ==================== GESTION DE L'IDENTIFIANT STOCKÉ ====================
  
  /// Sauvegarder l'identifiant (email/phone) après la première connexion
  Future<void> _saveIdentifier(String identifier) async {
    await _storage.write(key: 'saved_identifier', value: identifier);
    debugPrint('✅ [AUTH] Identifiant sauvegardé: $identifier');
  }
  
  /// Charger l'identifiant sauvegardé
  Future<String?> _getSavedIdentifier() async {
    final identifier = await _storage.read(key: 'saved_identifier');
    debugPrint('📱 [AUTH] Identifiant chargé: $identifier');
    return identifier;
  }
  
  /// Vérifier si un identifiant est sauvegardé
  Future<bool> hasSavedIdentifier() async {
    final identifier = await _storage.read(key: 'saved_identifier');
    return identifier != null && identifier.isNotEmpty;
  }
  
  /// Récupérer l'identifiant sauvegardé (public)
  Future<String?> getSavedIdentifier() async {
    return await _storage.read(key: 'saved_identifier');
  }

  Future<void> clearSavedIdentifier() async {
    await _storage.delete(key: 'saved_identifier');
    debugPrint('🗑️ [AUTH] Identifiant sauvegardé effacé');
  }
  
  // ==================== CHARGEMENT INITIAL ====================
  
  Future<void> _loadUser() async {
    debugPrint('🔄 [AUTH] _loadUser - Chargement initial');
    
    try {
      final token = await _apiService.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [AUTH] Aucun token trouvé');
        state = AuthState.unauthenticated();
        return;
      }
      
      final user = await _apiService.getCurrentUser();
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ [AUTH] Utilisateur chargé avec succès:');
      debugPrint('   ├─ id: ${user.id}');
      debugPrint('   ├─ fullName: ${user.fullName}');
      debugPrint('   ├─ email: ${user.email}');
      debugPrint('   ├─ phone: ${user.phone}');
      debugPrint('   ├─ role: ${user.role.label}');
      debugPrint('   └─ a un PIN: ${user.pin != null ? "Oui" : "Non"}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      state = AuthState.authenticated(user);
    } catch (e) {
      debugPrint('❌ [AUTH] Erreur lors du chargement: $e');
      await _apiService.clearToken();
      state = AuthState.unauthenticated();
    }
  }

  // ==================== AUTHENTIFICATION ====================

  Future<Map<String, dynamic>> sendOtp({required String identifier}) async {
    state = AuthState.loading();
    try {
      final result = await _apiService.sendOtp(identifier);
      if (result['success'] == true) {
        state = AuthState.otpSent(result['userId']);
      } else {
        state = AuthState.error(result['message'] ?? 'Erreur');
      }
      return result;
    } catch (e) {
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String code,
    required String type,
    required String identifier,
  }) async {
    try {
      final result = await _apiService.verifyOtp(userId, code, type);
      debugPrint('🔐 Résultat verifyOtp: $result');
      
      if (result['success'] == true) {
        debugPrint('✅ OTP vérifié avec succès');
        debugPrint('📦 AccessToken reçu: ${result['accessToken']}');
        
        // Sauvegarder l'identifiant pour les futures connexions PIN
        await _saveIdentifier(identifier);
        
        final userData = result['user'];
        if (userData != null) {
          final user = User.fromJson(userData);
          state = AuthState.authenticated(user);
          debugPrint('👤 Utilisateur authentifié: ${user.fullName}');
          debugPrint('📱 Identifiant sauvegardé pour connexion rapide');
        } else {
          state = AuthState.authenticated(null);
        }
      } else {
        debugPrint('❌ Échec vérification OTP: ${result['message']}');
        state = AuthState.error(result['message'] ?? 'Code invalide');
      }
      return result;
    } catch (e) {
      debugPrint('❌ Exception verifyOtp: $e');
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String phone,
    required String fullName,
    required String password,
    String role = 'client',
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
    String? garageId,
  }) async {
    state = AuthState.loading();
    try {
      final result = await _apiService.register(
        email: email,
        phone: phone,
        fullName: fullName,
        password: password,
        role: role,
        address: address,
        city: city,
        region: region,
        vehiclePlate: vehiclePlate,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehicleYear: vehicleYear,
        garageId: garageId,
      );
      if (result['success'] == true) {
        // Sauvegarder l'identifiant (email) après inscription
        await _saveIdentifier(email);
        state = AuthState.otpSent(result['userId']);
      } else {
        state = AuthState.error(result['message'] ?? 'Erreur');
      }
      return result;
    } catch (e) {
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ Connexion avec PIN (utilise l'identifiant passé en paramètre)
  Future<Map<String, dynamic>> loginWithPin(String pin, String identifier) async {
    state = AuthState.loading();
    try {
      debugPrint('🔐 [PIN_LOGIN] Tentative pour: $identifier');
      
      // Sauvegarder l'identifiant pour les prochaines connexions
      await _saveIdentifier(identifier);
      
      final result = await _apiService.loginWithPin(pin, identifier);
      
      if (result['success'] == true) {
        final user = User.fromJson(result['user']);
        state = AuthState.authenticated(user);
        debugPrint('✅ [PIN_LOGIN] Connexion réussie pour: ${user.fullName}');
      } else {
        debugPrint('❌ [PIN_LOGIN] Échec: ${result['message']}');
        state = AuthState.error(result['message'] ?? 'PIN incorrect');
      }
      return result;
    } catch (e) {
      debugPrint('❌ [PIN_LOGIN] Erreur: $e');
      state = AuthState.error(e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  // ✅ Connexion avec PIN uniquement (utilise l'identifiant sauvegardé)
  Future<Map<String, dynamic>> loginWithSavedPin(String pin) async {
    final savedIdentifier = await _getSavedIdentifier();
    
    if (savedIdentifier == null || savedIdentifier.isEmpty) {
      debugPrint('❌ [PIN_LOGIN] Aucun identifiant sauvegardé');
      state = AuthState.error('Session expirée. Veuillez vous reconnecter.');
      return {
        'success': false,
        'message': 'Session expirée. Veuillez vous reconnecter.'
      };
    }
    
    return loginWithPin(pin, savedIdentifier);
  }

  // ✅ CORRECTION ICI : Ne pas effacer l'identifiant lors de la déconnexion
  Future<void> logout() async {
    await _apiService.logout();
    // ❌ SUPPRIMÉ : await _clearSavedIdentifier();
    // L'identifiant reste sauvegardé pour les prochaines connexions PIN
    state = AuthState.unauthenticated();
    debugPrint('👋 Utilisateur déconnecté (identifiant conservé pour PIN)');
  }

  // ==================== GESTION DU PROFIL ====================

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String email,
    required String phone,
    String? address,
    String? city,
    String? region,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
  }) async {
    try {
      final result = await _apiService.updateProfile(
        fullName: fullName,
        email: email,
        phone: phone,
        address: address,
        city: city,
        region: region,
        vehiclePlate: vehiclePlate,
        vehicleModel: vehicleModel,
        vehicleColor: vehicleColor,
        vehicleYear: vehicleYear,
      );
      
      if (result['success'] == true) {
        // Mettre à jour l'identifiant sauvegardé si l'email a changé
        await _saveIdentifier(email);
        await refreshUser();
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updatePin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final result = await _apiService.updatePin(currentPin, newPin);
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> refreshUser() async {
    try {
      debugPrint('🔄 [AUTH] refreshUser - Rafraîchissement');
      final user = await _apiService.getCurrentUser();
      debugPrint('✅ [AUTH] Utilisateur rafraîchi: ${user.fullName}');
      state = AuthState.authenticated(user);
    } catch (e) {
      debugPrint('❌ Erreur refresh user: $e');
    }
  }
}

// ==================== AUTH STATE ====================

class AuthState {
  final bool isLoading;
  final User? user;
  final String? userId;
  final String? error;
  final bool isAuthenticated;
  final bool isOtpSent;

  AuthState({
    required this.isLoading,
    this.user,
    this.userId,
    this.error,
    this.isAuthenticated = false,
    this.isOtpSent = false,
  });

  factory AuthState.initial() => AuthState(isLoading: false);
  
  factory AuthState.loading() => AuthState(isLoading: true);
  
  factory AuthState.authenticated(User? user) => AuthState(
    isLoading: false,
    user: user,
    isAuthenticated: true,
  );
  
  factory AuthState.unauthenticated() => AuthState(
    isLoading: false,
    isAuthenticated: false,
  );
  
  factory AuthState.otpSent(String userId) => AuthState(
    isLoading: false,
    userId: userId,
    isOtpSent: true,
  );
  
  factory AuthState.error(String error) => AuthState(
    isLoading: false,
    error: error,
  );
  
  // ✅ Getter pour vérifier si l'utilisateur est un client
  bool get isClient => user?.role == UserRole.client;
  
  // ✅ Getter pour vérifier si l'utilisateur est un chauffeur
  bool get isDriver => user?.role == UserRole.driver;
  
  // ✅ Getter pour vérifier si l'utilisateur est un admin
  bool get isAdmin => user?.role == UserRole.admin;
  
  // ✅ Getter pour vérifier si l'utilisateur est super admin
  bool get isSuperAdmin => user?.role == UserRole.superAdmin;
  
  // ✅ Getter pour le nom d'affichage
  String get displayName => user?.fullName.split(' ').first ?? 'Utilisateur';
  
  // ✅ Copie avec nouvelles valeurs
  AuthState copyWith({
    bool? isLoading,
    User? user,
    String? userId,
    String? error,
    bool? isAuthenticated,
    bool? isOtpSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      userId: userId ?? this.userId,
      error: error ?? this.error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOtpSent: isOtpSent ?? this.isOtpSent,
    );
  }
}