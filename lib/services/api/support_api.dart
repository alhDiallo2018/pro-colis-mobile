import 'client.dart';

class SupportApi {
  final ApiClient client;
  SupportApi(this.client);

  /// Envoie un message au support (formulaire contact / réclamation).
  /// Aligné sur la webapp : POST /support/messages { subject, message, name?, email? }.
  Future<Map<String, dynamic>> sendSupportMessage({
    required String subject,
    required String message,
    String? name,
    String? email,
  }) async {
    try {
      final res = await client.dio.post('/support/messages', data: {
        'subject': subject,
        'message': message,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final data = client.handle(res);
      if (res.statusCode != null && res.statusCode! >= 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de l\'envoi du message',
        };
      }
      return {'success': data['success'] ?? true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
