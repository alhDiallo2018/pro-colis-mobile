// lib/services/api/shuttle_operator_api.dart
//
// SCP-007 (Phase 2 chantier 2) — API client pour l'espace opérateur de
// navette. Mirroring des wrappers Web `src/lib/api/shuttle-operator.ts` :
// CRUD lignes, flotte, horaires + overview + supervision temps réel.
//
// Toutes les routes sont scopées côté backend à `req.user.id`, donc aucune
// manipulation d'opérateurId ici — le token suffit.

import 'client.dart';

typedef TransitOperatorKind = String; // 'ddd' | 'aftu'
typedef TransitDirectionKind = String; // 'aller' | 'retour'

const List<TransitOperatorKind> kTransitOperators = ['ddd', 'aftu'];
const List<TransitDirectionKind> kTransitDirections = ['aller', 'retour'];
const List<String> kShuttleVehicleTypes = ['bus', 'minibus', 'car', 'van'];
const List<String> kShuttleVehicleStatuses = ['available', 'maintenance', 'retired'];

class ShuttleLineStop {
  final int order;
  final String label;
  final String zoneId;

  const ShuttleLineStop({required this.order, required this.label, required this.zoneId});

  factory ShuttleLineStop.fromJson(Map<String, dynamic> json) => ShuttleLineStop(
        order: (json['order'] as num?)?.toInt() ?? 0,
        label: json['label']?.toString() ?? '',
        zoneId: json['zoneId']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'order': order, 'label': label, 'zoneId': zoneId};
}

class ShuttleLine {
  final String id;
  final TransitOperatorKind operator;
  final String number;
  final TransitDirectionKind direction;
  final String name;
  final String origin;
  final String destination;
  final String? operatorUserId;
  final List<ShuttleLineStop> stops;

  const ShuttleLine({
    required this.id,
    required this.operator,
    required this.number,
    required this.direction,
    required this.name,
    required this.origin,
    required this.destination,
    this.operatorUserId,
    this.stops = const [],
  });

  factory ShuttleLine.fromJson(Map<String, dynamic> json) => ShuttleLine(
        id: json['id']?.toString() ?? '',
        operator: json['operator']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        direction: json['direction']?.toString() ?? 'aller',
        name: json['name']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        operatorUserId: json['operatorUserId']?.toString(),
        stops: (json['stops'] as List?)
                ?.whereType<Map>()
                .map((e) => ShuttleLineStop.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class ShuttleVehicle {
  final String id;
  final String plateNumber;
  final String model;
  final String type;
  final int capacity;
  final String status;
  final String? notes;

  const ShuttleVehicle({
    required this.id,
    required this.plateNumber,
    required this.model,
    required this.type,
    required this.capacity,
    required this.status,
    this.notes,
  });

  factory ShuttleVehicle.fromJson(Map<String, dynamic> json) => ShuttleVehicle(
        id: json['id']?.toString() ?? '',
        plateNumber: json['plateNumber']?.toString() ?? '',
        model: json['model']?.toString() ?? '',
        type: json['type']?.toString() ?? 'minibus',
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'available',
        notes: json['notes']?.toString(),
      );
}

class ShuttleSchedule {
  final String id;
  final String transitLineId;
  final List<int> daysOfWeek;
  final String departureTime;
  final DateTime? activeFrom;
  final DateTime? activeUntil;
  final String? notes;
  final String? transitLineName;
  final String? transitLineNumber;
  final String? transitLineDirection;

  const ShuttleSchedule({
    required this.id,
    required this.transitLineId,
    required this.daysOfWeek,
    required this.departureTime,
    this.activeFrom,
    this.activeUntil,
    this.notes,
    this.transitLineName,
    this.transitLineNumber,
    this.transitLineDirection,
  });

  factory ShuttleSchedule.fromJson(Map<String, dynamic> json) {
    final line = (json['transitLine'] as Map?)?.cast<String, dynamic>();
    return ShuttleSchedule(
      id: json['id']?.toString() ?? '',
      transitLineId: json['transitLineId']?.toString() ?? '',
      daysOfWeek: (json['daysOfWeek'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toList() ??
          const [],
      departureTime: json['departureTime']?.toString() ?? '',
      activeFrom: DateTime.tryParse(json['activeFrom']?.toString() ?? ''),
      activeUntil: DateTime.tryParse(json['activeUntil']?.toString() ?? ''),
      notes: json['notes']?.toString(),
      transitLineName: line?['name']?.toString(),
      transitLineNumber: line?['number']?.toString(),
      transitLineDirection: line?['direction']?.toString(),
    );
  }
}

class ShuttleOverview {
  final int lineCount;
  final int vehicleCount;
  final int availableVehicleCount;
  final int scheduleCount;
  final int activeScheduleCount;

  const ShuttleOverview({
    required this.lineCount,
    required this.vehicleCount,
    required this.availableVehicleCount,
    required this.scheduleCount,
    required this.activeScheduleCount,
  });

  factory ShuttleOverview.fromJson(Map<String, dynamic> json) => ShuttleOverview(
        lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
        vehicleCount: (json['vehicleCount'] as num?)?.toInt() ?? 0,
        availableVehicleCount: (json['availableVehicleCount'] as num?)?.toInt() ?? 0,
        scheduleCount: (json['scheduleCount'] as num?)?.toInt() ?? 0,
        activeScheduleCount: (json['activeScheduleCount'] as num?)?.toInt() ?? 0,
      );
}

class ShuttleLivePosition {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  const ShuttleLivePosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  factory ShuttleLivePosition.fromJson(Map<String, dynamic> json) => ShuttleLivePosition(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
        capturedAt:
            DateTime.tryParse(json['capturedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class ShuttleLiveJourney {
  final String advertisementId;
  final String? driverName;
  final String? lineNumber;
  final String? lineName;
  final ShuttleLivePosition? position;
  final int stopsTotal;
  final int stopsReached;
  final int? nextStopOrder;
  final String? nextStopLabel;
  final int pickupDone;
  final int pickupTotal;
  final int dropoffDone;
  final int dropoffTotal;

  const ShuttleLiveJourney({
    required this.advertisementId,
    this.driverName,
    this.lineNumber,
    this.lineName,
    this.position,
    this.stopsTotal = 0,
    this.stopsReached = 0,
    this.nextStopOrder,
    this.nextStopLabel,
    this.pickupDone = 0,
    this.pickupTotal = 0,
    this.dropoffDone = 0,
    this.dropoffTotal = 0,
  });

  factory ShuttleLiveJourney.fromJson(Map<String, dynamic> json) {
    final driver = (json['driver'] as Map?)?.cast<String, dynamic>();
    final line = (json['line'] as Map?)?.cast<String, dynamic>();
    final position = (json['position'] as Map?)?.cast<String, dynamic>();
    final nextStop = (json['nextStop'] as Map?)?.cast<String, dynamic>();
    final conf = (json['confirmations'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ShuttleLiveJourney(
      advertisementId: json['advertisementId']?.toString() ?? '',
      driverName: driver?['fullName']?.toString(),
      lineNumber: line?['number']?.toString(),
      lineName: line?['name']?.toString(),
      position: position != null ? ShuttleLivePosition.fromJson(position) : null,
      stopsTotal: (json['stopsTotal'] as num?)?.toInt() ?? 0,
      stopsReached: (json['stopsReached'] as num?)?.toInt() ?? 0,
      nextStopOrder: (nextStop?['order'] as num?)?.toInt(),
      nextStopLabel: nextStop?['label']?.toString(),
      pickupDone: (conf['pickupDone'] as num?)?.toInt() ?? 0,
      pickupTotal: (conf['pickupTotal'] as num?)?.toInt() ?? 0,
      dropoffDone: (conf['dropoffDone'] as num?)?.toInt() ?? 0,
      dropoffTotal: (conf['dropoffTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShuttleLiveFleet {
  final int available;
  final int maintenance;
  final int retired;

  const ShuttleLiveFleet({this.available = 0, this.maintenance = 0, this.retired = 0});

  factory ShuttleLiveFleet.fromJson(Map<String, dynamic> json) => ShuttleLiveFleet(
        available: (json['available'] as num?)?.toInt() ?? 0,
        maintenance: (json['maintenance'] as num?)?.toInt() ?? 0,
        retired: (json['retired'] as num?)?.toInt() ?? 0,
      );
}

class ShuttleLiveSnapshot {
  final List<ShuttleLiveJourney> activeJourneys;
  final ShuttleLiveFleet fleet;
  final DateTime generatedAt;

  const ShuttleLiveSnapshot({
    required this.activeJourneys,
    required this.fleet,
    required this.generatedAt,
  });

  factory ShuttleLiveSnapshot.fromJson(Map<String, dynamic> json) => ShuttleLiveSnapshot(
        activeJourneys: (json['activeJourneys'] as List?)
                ?.whereType<Map>()
                .map((e) => ShuttleLiveJourney.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        fleet: json['fleet'] is Map
            ? ShuttleLiveFleet.fromJson((json['fleet'] as Map).cast<String, dynamic>())
            : const ShuttleLiveFleet(),
        generatedAt:
            DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

class ShuttleOperatorApi {
  final ApiClient client;

  ShuttleOperatorApi(this.client);

  Map<String, dynamic> _unwrap(Map<String, dynamic> body) =>
      (body['data'] as Map?)?.cast<String, dynamic>() ?? body;

  Future<ShuttleOverview> getOverview() async {
    final res = await client.dio.get('/shuttle-operator/overview');
    final body = client.handle(res);
    return ShuttleOverview.fromJson(_unwrap(body));
  }

  Future<ShuttleLiveSnapshot> getLive() async {
    final res = await client.dio.get('/shuttle-operator/live');
    final body = client.handle(res);
    return ShuttleLiveSnapshot.fromJson(_unwrap(body));
  }

  // ─── Lines ────────────────────────────────────────────────────────────────

  Future<List<ShuttleLine>> listLines() async {
    final res = await client.dio.get('/shuttle-operator/lines');
    final body = client.handle(res);
    final rows = (_unwrap(body)['lines'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((e) => ShuttleLine.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ShuttleLine> createLine({
    required String operator,
    required String number,
    required String direction,
    required String name,
    required String origin,
    required String destination,
    required List<ShuttleLineStop> stops,
  }) async {
    final res = await client.dio.post('/shuttle-operator/lines', data: {
      'operator': operator,
      'number': number,
      'direction': direction,
      'name': name,
      'origin': origin,
      'destination': destination,
      'stops': stops.map((s) => s.toJson()).toList(),
    });
    final body = client.handle(res);
    return ShuttleLine.fromJson(
        (_unwrap(body)['line'] as Map).cast<String, dynamic>());
  }

  Future<ShuttleLine> updateLine(String lineId, Map<String, dynamic> payload) async {
    final res = await client.dio.patch('/shuttle-operator/lines/$lineId', data: payload);
    final body = client.handle(res);
    return ShuttleLine.fromJson(
        (_unwrap(body)['line'] as Map).cast<String, dynamic>());
  }

  Future<void> deleteLine(String lineId) async {
    final res = await client.dio.delete('/shuttle-operator/lines/$lineId');
    client.handle(res);
  }

  // ─── Vehicles ─────────────────────────────────────────────────────────────

  Future<List<ShuttleVehicle>> listVehicles() async {
    final res = await client.dio.get('/shuttle-operator/vehicles');
    final body = client.handle(res);
    final rows = (_unwrap(body)['vehicles'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((e) => ShuttleVehicle.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ShuttleVehicle> createVehicle({
    required String plateNumber,
    required String model,
    required String type,
    required int capacity,
    String status = 'available',
    String? notes,
  }) async {
    final res = await client.dio.post('/shuttle-operator/vehicles', data: {
      'plateNumber': plateNumber,
      'model': model,
      'type': type,
      'capacity': capacity,
      'status': status,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final body = client.handle(res);
    return ShuttleVehicle.fromJson(
        (_unwrap(body)['vehicle'] as Map).cast<String, dynamic>());
  }

  Future<ShuttleVehicle> updateVehicle(String vehicleId, Map<String, dynamic> payload) async {
    final res = await client.dio.patch('/shuttle-operator/vehicles/$vehicleId', data: payload);
    final body = client.handle(res);
    return ShuttleVehicle.fromJson(
        (_unwrap(body)['vehicle'] as Map).cast<String, dynamic>());
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final res = await client.dio.delete('/shuttle-operator/vehicles/$vehicleId');
    client.handle(res);
  }

  // ─── Schedules ────────────────────────────────────────────────────────────

  Future<List<ShuttleSchedule>> listSchedules() async {
    final res = await client.dio.get('/shuttle-operator/schedules');
    final body = client.handle(res);
    final rows = (_unwrap(body)['schedules'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((e) => ShuttleSchedule.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ShuttleSchedule> createSchedule({
    required String transitLineId,
    required List<int> daysOfWeek,
    required String departureTime,
    DateTime? activeFrom,
    DateTime? activeUntil,
    String? notes,
  }) async {
    final res = await client.dio.post('/shuttle-operator/schedules', data: {
      'transitLineId': transitLineId,
      'daysOfWeek': daysOfWeek,
      'departureTime': departureTime,
      if (activeFrom != null) 'activeFrom': activeFrom.toIso8601String(),
      if (activeUntil != null) 'activeUntil': activeUntil.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    final body = client.handle(res);
    return ShuttleSchedule.fromJson(
        (_unwrap(body)['schedule'] as Map).cast<String, dynamic>());
  }

  Future<ShuttleSchedule> updateSchedule(String scheduleId, Map<String, dynamic> payload) async {
    final res = await client.dio.patch('/shuttle-operator/schedules/$scheduleId', data: payload);
    final body = client.handle(res);
    return ShuttleSchedule.fromJson(
        (_unwrap(body)['schedule'] as Map).cast<String, dynamic>());
  }

  Future<void> deleteSchedule(String scheduleId) async {
    final res = await client.dio.delete('/shuttle-operator/schedules/$scheduleId');
    client.handle(res);
  }
}

const List<String> kDayLabelsFr = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

String formatDaysOfWeek(List<int> days) {
  if (days.isEmpty) return '—';
  final sorted = [...days]..sort();
  return sorted.map((d) => d >= 0 && d < 7 ? kDayLabelsFr[d] : '$d').join(' · ');
}
