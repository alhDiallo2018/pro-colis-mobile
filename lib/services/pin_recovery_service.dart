import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/client.dart';
import 'biometric_service.dart';

final pinRecoveryServiceProvider = Provider((ref) => PinRecoveryService());

class PinRecoveryException implements Exception {
  const PinRecoveryException(this.message);
  final String message;
}

/// Les routes historiques « password » acceptent aussi `newPin`. L'OTP doit
/// rester lié au même identifiant entre l'envoi et la réinitialisation.
class PinRecoveryService {
  PinRecoveryService(
      {ApiClient? client, Future<void> Function()? clearBiometrics})
      : _client = client ?? ApiClient(),
        _clearBiometrics = clearBiometrics ?? BiometricService.disable;

  final ApiClient _client;
  final Future<void> Function() _clearBiometrics;

  Future<void> requestCode(String identifier) async {
    await _post('/auth/forgot-password', {'identifier': identifier});
  }

  Future<void> resetPin({
    required String identifier,
    required String otpCode,
    required String newPin,
  }) async {
    await _post('/auth/reset-password', {
      'identifier': identifier,
      'otpCode': otpCode,
      'newPin': newPin,
    });
    // Ne jamais mémoriser le nouveau PIN avant une vraie reconnexion. Le
    // précédent secret biométrique est obsolète après validation par l'API.
    try {
      await _clearBiometrics();
    } catch (error, stackTrace) {
      // La réinitialisation serveur a réussi : une erreur du stockage local
      // ne doit pas inviter à réutiliser un OTP déjà consommé.
      debugPrint('[PinRecovery] Nettoyage biométrique : ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _post(String path, Map<String, String> data) async {
    try {
      final response = await _client.dio.post<dynamic>(path, data: data);
      final body = _client.handle(response);
      if ((response.statusCode ?? 500) >= 400 || body['success'] != true) {
        throw PinRecoveryException(_message(body, response.statusCode));
      }
      // Certaines API locales renvoient un code de test. Il n'est ni affiché,
      // ni mémorisé, ni journalisé par le client mobile.
    } on PinRecoveryException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      debugPrint('[PinRecovery] Requête impossible : ${error.type.name}');
      debugPrintStack(stackTrace: stackTrace);
      if (error.response != null) {
        throw PinRecoveryException(
          _message(error.response?.data, error.response?.statusCode),
        );
      }
      throw const PinRecoveryException(
        'Serveur injoignable. Vérifiez votre connexion et réessayez.',
      );
    } catch (error, stackTrace) {
      // Éviter error.toString() : une exception réseau peut contenir le PIN.
      debugPrint('[PinRecovery] Réponse invalide : ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
      throw const PinRecoveryException(
        'Impossible de traiter la demande. Réessayez dans un instant.',
      );
    }
  }

  String _message(dynamic body, int? status) {
    if (status == 429) {
      return 'Trop de tentatives. Patientez quelques minutes avant de réessayer.';
    }
    if (status == null || status >= 500) {
      return 'Service temporairement indisponible. Réessayez dans un instant.';
    }
    if (body is Map) {
      final error = body['error'];
      final details = error is Map ? error['details'] : body['details'];
      if (details is List) {
        for (final detail in details) {
          if (detail is Map && detail['path'] == 'body.otpCode') {
            return 'Code de vérification invalide ou expiré. Vérifiez le code ou demandez-en un nouveau.';
          }
        }
      }
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return 'Impossible de traiter la demande. Vérifiez les informations saisies.';
  }
}
