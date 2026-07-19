import '../../models/parcel.dart';
import 'client.dart';

class ParcelsApi {
  final ApiClient client;
  ParcelsApi(this.client);

  Future<List<Parcel>> getMyParcels({String? status}) async {
    try {
      final res = await client.dio.get('/client/parcels/my-parcels',
          queryParameters: status != null && status.isNotEmpty ? {'status': status} : null);
      final data = client.handle(res);
      final sent = (data['sent'] as List?) ?? [];
      final received = (data['received'] as List?) ?? [];
      final all = [...sent, ...received];
      return all.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Parcel>> getSentParcels({String? status}) async {
    try {
      final params = <String, dynamic>{'filter': 'sent'};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final res = await client.dio.get('/client/parcels/my-parcels', queryParameters: params);
      final data = client.handle(res);
      final list = (data['parcels'] as List?) ?? [];
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Parcel>> getReceivedParcels({String? status}) async {
    try {
      final params = <String, dynamic>{'filter': 'received'};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final res = await client.dio.get('/client/parcels/my-parcels', queryParameters: params);
      final data = client.handle(res);
      final list = (data['parcels'] as List?) ?? [];
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Parcel> createParcel(Map<String, dynamic> d) async {
    final res = await client.dio.post('/client/parcels/create', data: d);
    final data = client.handle(res);
    final parcel = data['parcel'];
    if (parcel != null) return Parcel.fromJson(Map<String, dynamic>.from(parcel));
    throw Exception('Colis non créé');
  }

  Future<Map<String, dynamic>> cancelParcel(String id, {String? reason}) async {
    try {
      final res = await client.dio.post('/client/parcels/$id/cancel',
          data: reason != null ? {'reason': reason} : null);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Parcel>> getFreeParcels() async {
    try {
      final res = await client.dio.get('/public/parcels/free');
      final data = client.handle(res);
      final list = (data['parcels'] ?? data['data'] ?? []) as List;
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Parcel> trackParcel(String trackingNumber) async {
    final res = await client.dio.get('/public/parcels/track/$trackingNumber');
    final data = client.handle(res);
    final parcel = data['data'] ?? data['parcel'];
    if (parcel != null) return Parcel.fromJson(Map<String, dynamic>.from(parcel));
    throw Exception(data['message'] ?? 'Colis non trouvé');
  }

  Future<Parcel> getClientParcel(String parcelId) async {
    final res = await client.dio.get('/client/parcels/$parcelId');
    final data = client.handle(res);
    final parcel = data['parcel'];
    if (parcel != null) return Parcel.fromJson(Map<String, dynamic>.from(parcel));
    throw Exception('Colis non trouvé');
  }

  Future<String> getDeliveryCode(String parcelId) async {
    final res = await client.dio.get('/client/parcels/$parcelId/delivery-code');
    final data = client.handle(res);
    return data['code']?.toString() ?? '';
  }

  Future<List<ParcelEvent>> getParcelTimeline(String parcelId) async {
    try {
      final res = await client.dio.get('/parcels/$parcelId/timeline');
      final data = client.handle(res);
      final list = (data['events'] ?? data['timeline'] ?? []) as List;
      return list.map((e) {
        final j = Map<String, dynamic>.from(e);
        return ParcelEvent(
          id: j['id']?.toString() ?? '',
          parcelId: j['parcelId']?.toString() ?? '',
          status: ParcelStatus.fromString(j['status']?.toString() ?? 'pending'),
          description: j['description']?.toString() ?? '',
          location: j['location']?.toString(),
          userId: j['userId']?.toString(),
          userName: j['userName']?.toString(),
          userRole: j['userRole']?.toString(),
          photoUrl: j['photoUrl']?.toString(),
          metadata: j['metadata'] is Map ? Map<String, dynamic>.from(j['metadata']) : {},
          timestamp: j['timestamp'] != null ? DateTime.tryParse(j['timestamp'].toString()) ?? DateTime.now() : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> confirmCash(String parcelId) async {
    try {
      final res = await client.dio.post('/parcels/$parcelId/confirm-cash');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
