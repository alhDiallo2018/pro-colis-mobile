// lib/services/api/transit_api.dart
//
// Catalogue public des lignes de bus DDD / AFTU, lecture seule.
// Les lignes sont alimentées par le seed côté backend (seed-transit.js).

import 'client.dart';

enum TransitOperator { ddd, aftu }

TransitOperator parseOperator(String raw) =>
    raw.toLowerCase() == 'aftu' ? TransitOperator.aftu : TransitOperator.ddd;

String operatorToString(TransitOperator op) =>
    op == TransitOperator.aftu ? 'aftu' : 'ddd';

enum TransitDirection { aller, retour }

TransitDirection parseDirection(String raw) =>
    raw.toLowerCase() == 'retour' ? TransitDirection.retour : TransitDirection.aller;

class TransitZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String status;
  const TransitZone({
    required this.id, required this.name,
    required this.latitude, required this.longitude, required this.status,
  });
  factory TransitZone.fromJson(Map<String, dynamic> j) => TransitZone(
        id: j['id'] as String,
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        status: j['status'] as String? ?? 'approved',
      );
}

class TransitStop {
  final int order;
  final String label;
  final String zoneId;
  final TransitZone? zone;
  const TransitStop({required this.order, required this.label, required this.zoneId, this.zone});
  factory TransitStop.fromJson(Map<String, dynamic> j) => TransitStop(
        order: j['order'] as int,
        label: j['label'] as String,
        zoneId: j['zoneId'] as String,
        zone: j['zone'] == null ? null : TransitZone.fromJson(j['zone'] as Map<String, dynamic>),
      );
}

class TransitLineSummary {
  final String id;
  final TransitOperator operator;
  final String number;
  final TransitDirection direction;
  final String name;
  final String origin;
  final String destination;
  const TransitLineSummary({
    required this.id, required this.operator, required this.number,
    required this.direction, required this.name, required this.origin, required this.destination,
  });
  factory TransitLineSummary.fromJson(Map<String, dynamic> j) => TransitLineSummary(
        id: j['id'] as String,
        operator: parseOperator(j['operator'] as String),
        number: j['number'] as String,
        direction: parseDirection(j['direction'] as String),
        name: j['name'] as String,
        origin: j['origin'] as String,
        destination: j['destination'] as String,
      );
}

class TransitLineDetail extends TransitLineSummary {
  final List<TransitStop> stops;
  TransitLineDetail({
    required super.id, required super.operator, required super.number,
    required super.direction, required super.name, required super.origin, required super.destination,
    required this.stops,
  });
  factory TransitLineDetail.fromJson(Map<String, dynamic> j) => TransitLineDetail(
        id: j['id'] as String,
        operator: parseOperator(j['operator'] as String),
        number: j['number'] as String,
        direction: parseDirection(j['direction'] as String),
        name: j['name'] as String,
        origin: j['origin'] as String,
        destination: j['destination'] as String,
        stops: ((j['stops'] as List?) ?? const [])
            .map((e) => TransitStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TransitLivePosition {
  final double latitude, longitude, accuracyMeters;
  final DateTime capturedAt;
  const TransitLivePosition({
    required this.latitude, required this.longitude,
    required this.accuracyMeters, required this.capturedAt,
  });
  factory TransitLivePosition.fromJson(Map<String, dynamic> j) => TransitLivePosition(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracyMeters: (j['accuracyMeters'] as num).toDouble(),
        capturedAt: DateTime.parse(j['capturedAt'] as String),
      );
}

class TransitLiveAdvertisement {
  final String id;
  final String driverId;
  final String driverName;
  final DateTime? departureAt;
  final double? availableWeight;
  final double? proposedPrice;
  final TransitLivePosition? live;
  const TransitLiveAdvertisement({
    required this.id, required this.driverId, required this.driverName,
    this.departureAt, this.availableWeight, this.proposedPrice, this.live,
  });
  factory TransitLiveAdvertisement.fromJson(Map<String, dynamic> j) => TransitLiveAdvertisement(
        id: j['id'] as String,
        driverId: j['driverId'] as String,
        driverName: j['driverName'] as String,
        departureAt: (j['departureAt'] as String?)?.let(DateTime.parse),
        availableWeight: (j['availableWeight'] as num?)?.toDouble(),
        proposedPrice: (j['proposedPrice'] as num?)?.toDouble(),
        live: j['live'] == null ? null : TransitLivePosition.fromJson(j['live'] as Map<String, dynamic>),
      );
}

class TransitLiveResponse {
  final TransitLineSummary line;
  final List<TransitLiveAdvertisement> advertisements;
  const TransitLiveResponse({required this.line, required this.advertisements});
  factory TransitLiveResponse.fromJson(Map<String, dynamic> j) => TransitLiveResponse(
        line: TransitLineSummary.fromJson(j['line'] as Map<String, dynamic>),
        advertisements: ((j['advertisements'] as List?) ?? const [])
            .map((e) => TransitLiveAdvertisement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TransitDraft {
  final String transitLineId;
  final String departureZoneId;
  final String arrivalZoneId;
  final String departureCity;
  final String arrivalCity;
  final String lineNumber;
  final List<Map<String, dynamic>> itineraryStops;
  const TransitDraft({
    required this.transitLineId,
    required this.departureZoneId, required this.arrivalZoneId,
    required this.departureCity, required this.arrivalCity,
    required this.lineNumber, required this.itineraryStops,
  });
  factory TransitDraft.fromJson(Map<String, dynamic> j) => TransitDraft(
        transitLineId: j['transitLineId'] as String,
        departureZoneId: j['departureZoneId'] as String,
        arrivalZoneId: j['arrivalZoneId'] as String,
        departureCity: j['departureCity'] as String? ?? 'Dakar',
        arrivalCity: j['arrivalCity'] as String? ?? 'Dakar',
        lineNumber: j['itinerary']?['lineNumber'] as String? ?? '',
        itineraryStops: ((j['itinerary']?['stops'] as List?) ?? const [])
            .cast<Map<String, dynamic>>(),
      );
}

class TransitApi {
  final ApiClient _client;
  TransitApi(this._client);

  Future<List<TransitLineSummary>> listLines({TransitOperator? operator}) async {
    final res = await _client.dio.get('/transit/lines',
        queryParameters: operator != null ? {'operator': operatorToString(operator)} : null);
    final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>;
    return ((data['lines'] as List?) ?? const [])
        .map((e) => TransitLineSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransitLineDetail> getLine(String lineId) async {
    final res = await _client.dio.get('/transit/lines/$lineId');
    final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>;
    return TransitLineDetail.fromJson(data['line'] as Map<String, dynamic>);
  }

  Future<TransitLiveResponse> getLineLive(String lineId) async {
    final res = await _client.dio.get('/transit/lines/$lineId/live');
    final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>;
    return TransitLiveResponse.fromJson(data);
  }

  Future<TransitDraft> getDraft(String lineId) async {
    final res = await _client.dio.get('/transit/lines/$lineId/draft');
    final data = (res.data?['data'] ?? res.data) as Map<String, dynamic>;
    return TransitDraft.fromJson(data);
  }
}

extension _NullableLet<T> on T? {
  R? let<R>(R Function(T) f) => this == null ? null : f(this as T);
}
