import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'client.dart';

class ExperienceApi {
  ExperienceApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? data}) async {
    final response = method == 'POST'
        ? await _client.dio.post('/experience$path', data: data)
        : method == 'DELETE'
            ? await _client.dio.delete('/experience$path')
            : await _client.dio.get('/experience$path');
    final result = _client.handle(response);
    if (response.statusCode != 200 || result['success'] != true) {
      throw Exception(
          result['message'] ?? 'Service temporairement indisponible');
    }
    return result;
  }

  Future<Map<String, dynamic>> importFile(
      Uint8List bytes, String filename) async {
    final response = await _client.dio.post('/experience/imports/preview',
        data: FormData.fromMap(
            {'file': MultipartFile.fromBytes(bytes, filename: filename)}));
    final result = _client.handle(response);
    if (response.statusCode != 200 || result['success'] != true)
      throw FormatException(result['message'] ?? 'Import impossible');
    return result;
  }

  Future<Map<String, dynamic>> parcel(String id) async =>
      Map<String, dynamic>.from((await request('/parcels/$id'))['experience']);
  Future<Map<String, dynamic>> prefill(
          {String? source, String? draft, String? recipient}) async =>
      Map<String, dynamic>.from((await request(source != null
          ? '/parcels/$source/repeat'
          : recipient != null
              ? '/recipients/$recipient'
              : '/drafts/$draft'))['draft']);
}

String experienceMoney(dynamic value) => value == null
    ? 'À confirmer'
    : '${num.tryParse(value.toString())?.toStringAsFixed(0) ?? value} FCFA';
String complaintStatus(String status) =>
    const {
      'open': 'Reçue',
      'pending': 'En attente',
      'in_progress': 'En cours',
      'resolved': 'Résolue',
    }[status] ??
    status;
String receiptText(Map<String, dynamic> receipt, String tracking) =>
    'SendProColis — Justificatif de paiement\nColis : $tracking\n'
    'Référence : ${receipt['reference'] ?? receipt['id']}\n'
    'Montant confirmé : ${experienceMoney(receipt['amount'])}\n'
    'Moyen : ${receipt['method']}\nDate : ${receipt['createdAt']}';
