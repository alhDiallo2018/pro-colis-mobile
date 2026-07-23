import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'client.dart';

class UploadsApi {
  final ApiClient client;
  UploadsApi(this.client);

  Future<String?> uploadFile({
    required XFile file,
    required String mediaType,
    String? parcelId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'mediaType': mediaType,
        if (parcelId != null) 'parcelId': parcelId,
      });
      final res = await client.dio.post('/upload', data: formData);
      final data = client.handle(res);
      return data['url']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadChatAudio(XFile file) async =>
      uploadFile(file: file, mediaType: 'audio');

  Future<String?> uploadChatPhoto(XFile file) async =>
      uploadFile(file: file, mediaType: 'photo');

  Future<String?> uploadChatVideo(XFile file) async =>
      uploadFile(file: file, mediaType: 'video');

  Future<Map<String, dynamic>> uploadIdentityDocument({
    required String documentType,
    required String side,
    required String url,
    String? identityId,
  }) async {
    try {
      final res = await client.dio.post('/identity/upload', data: {
        'documentType': documentType,
        'side': side,
        'url': url,
        if (identityId != null) 'identityId': identityId,
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> getIdentityStatus() async {
    try {
      final res = await client.dio.get('/identity/status');
      return client.handle(res);
    } catch (e) {
      return null;
    }
  }
}
