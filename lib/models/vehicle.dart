// mobile/lib/models/vehicle.dart

class Vehicle {
  final String id;
  final String plateNumber;
  final String model;
  final String type;
  final int capacity;
  final String garageId;
  final String? driverId;
  final bool isAvailable;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.model,
    required this.type,
    required this.capacity,
    required this.garageId,
    this.driverId,
    required this.isAvailable,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      plateNumber: json['plateNumber']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      capacity: json['capacity'] ?? 0,
      garageId: json['garageId']?.toString() ?? '',
      driverId: json['driverId']?.toString(),
      isAvailable: json['isAvailable'] ?? false,
      createdAt: DateTime.parse(json['createdAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plateNumber': plateNumber,
    'model': model,
    'type': type,
    'capacity': capacity,
    'garageId': garageId,
    'driverId': driverId,
    'isAvailable': isAvailable,
    'createdAt': createdAt.toIso8601String(),
  };
}