import '../../models/address.dart';
import '../../models/garage.dart';
import 'client.dart';

class AddressesApiException implements Exception {
  final String message;
  final int? statusCode;

  const AddressesApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AddressesApi {
  final ApiClient client;

  AddressesApi(this.client);

  Map<String, dynamic> _validate(dynamic response) {
    final body = client.handle(response);
    final status = response.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw AddressesApiException(
        body['message']?.toString() ?? 'Opération impossible',
        statusCode: status,
      );
    }
    return body;
  }

  dynamic _nested(Map<String, dynamic> body, String key) {
    if (body[key] != null) return body[key];
    final data = body['data'];
    return data is Map ? data[key] : null;
  }

  Future<List<Address>> listAddresses() async {
    final response = await client.dio.get('/addresses');
    final body = _validate(response);
    final raw = _nested(body, 'addresses');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Address.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Address> createAddress(Address address) async {
    final response =
        await client.dio.post('/addresses', data: address.toPayload());
    final body = _validate(response);
    final raw = _nested(body, 'address');
    if (raw is! Map) {
      throw const AddressesApiException('Adresse créée mais réponse invalide');
    }
    return Address.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<Address> updateAddress(String addressId, Address address) async {
    final response = await client.dio.put(
      '/addresses/$addressId',
      data: address.toPayload(),
    );
    final body = _validate(response);
    final raw = _nested(body, 'address');
    if (raw is! Map) {
      throw const AddressesApiException(
        'Adresse modifiée mais réponse invalide',
      );
    }
    return Address.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> deleteAddress(String addressId) async {
    final response = await client.dio.delete('/addresses/$addressId');
    _validate(response);
  }

  Future<void> setDefaultAddress(String addressId) async {
    final response = await client.dio.patch('/addresses/$addressId/default');
    _validate(response);
  }

  Future<List<Garage>> favoriteZones() async {
    final response = await client.dio.get('/favorites/zones');
    final body = _validate(response);
    final raw = _nested(body, 'zones') ?? _nested(body, 'garages');
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Garage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> addFavoriteZone(String zoneId) async {
    final response = await client.dio.post('/favorites/zones/$zoneId');
    _validate(response);
  }

  Future<void> removeFavoriteZone(String zoneId) async {
    final response = await client.dio.delete('/favorites/zones/$zoneId');
    _validate(response);
  }
}
