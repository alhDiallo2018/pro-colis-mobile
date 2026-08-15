import '../../models/stats.dart';
import 'client.dart';

class StatsApiException implements Exception {
  final String message;
  final int? statusCode;

  const StatsApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class StatsApi {
  final ApiClient client;

  StatsApi(this.client);

  Future<Map<String, dynamic>> _load(String path) async {
    final response = await client.dio.get(path);
    final body = client.handle(response);
    final status = response.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw StatsApiException(
        body['message']?.toString() ?? 'Statistiques indisponibles',
        statusCode: status,
      );
    }

    final raw = body['stats'] ??
        (body['data'] is Map ? (body['data'] as Map)['stats'] : null);
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<UserStats> userStats() async =>
      UserStats.fromJson(await _load('/users/stats'));

  Future<ClientBidStats> clientBidStats() async =>
      ClientBidStats.fromJson(await _load('/client/bids/stats'));

  Future<DriverStats> driverStats() async =>
      DriverStats.fromJson(await _load('/driver/stats'));

  Future<ZoneStats> zoneStats() async =>
      ZoneStats.fromJson(await _load('/garage-admin/stats'));

  Future<GlobalStats> globalStats() async =>
      GlobalStats.fromJson(await _load('/super-admin/stats'));

  Future<AdvertisementStats> advertisementStats() async =>
      AdvertisementStats.fromJson(await _load('/advertisements/stats'));
}
