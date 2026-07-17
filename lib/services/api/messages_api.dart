import 'client.dart';

class MessagesApi {
  final ApiClient client;
  MessagesApi(this.client);

  Future<List<Map<String, dynamic>>> getMessagesThread(String peerId,
      {String? parcelId}) async {
    try {
      final res = await client.dio.get('/messages/thread', queryParameters: {
        'peerId': peerId,
        if (parcelId != null) 'parcelId': parcelId,
      });
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['messages'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/messages', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final res = await client.dio.get('/messages/conversations');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(
          data['conversations'] ?? data['messages'] ?? []);
    } catch (e) {
      return [];
    }
  }
}
