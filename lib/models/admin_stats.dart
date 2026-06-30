// mobile/lib/models/admin_stats.dart

class AdminStats {
  final int totalUsers;
  final int totalDrivers;
  final int totalClients;
  final int totalGarages;
  final int totalVehicles;
  final int totalParcels;
  final int parcelsInTransit;
  final int parcelsDeliveredToday;
  final int parcelsPending;
  final double totalRevenue;
  final double revenueThisMonth;
  final double revenueLastMonth;
  final Map<String, int> parcelsByRegion;
  final List<DailyStats> dailyStats;
  final List<GaragePerformance> garagePerformance;

  AdminStats({
    required this.totalUsers,
    required this.totalDrivers,
    required this.totalClients,
    required this.totalGarages,
    required this.totalVehicles,
    required this.totalParcels,
    required this.parcelsInTransit,
    required this.parcelsDeliveredToday,
    required this.parcelsPending,
    required this.totalRevenue,
    required this.revenueThisMonth,
    required this.revenueLastMonth,
    required this.parcelsByRegion,
    required this.dailyStats,
    required this.garagePerformance,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['totalUsers'] ?? 0,
      totalDrivers: json['totalDrivers'] ?? 0,
      totalClients: json['totalClients'] ?? 0,
      totalGarages: json['totalGarages'] ?? 0,
      totalVehicles: json['totalVehicles'] ?? 0,
      totalParcels: json['totalParcels'] ?? 0,
      parcelsInTransit: json['parcelsInTransit'] ?? 0,
      parcelsDeliveredToday: json['parcelsDeliveredToday'] ?? 0,
      parcelsPending: json['parcelsPending'] ?? 0,
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      revenueThisMonth: (json['revenueThisMonth'] ?? 0).toDouble(),
      revenueLastMonth: (json['revenueLastMonth'] ?? 0).toDouble(),
      parcelsByRegion: Map<String, int>.from(json['parcelsByRegion'] ?? {}),
      dailyStats: (json['dailyStats'] as List?)
          ?.map((e) => DailyStats.fromJson(e))
          .toList() ?? [],
      garagePerformance: (json['garagePerformance'] as List?)
          ?.map((e) => GaragePerformance.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'totalUsers': totalUsers,
    'totalDrivers': totalDrivers,
    'totalClients': totalClients,
    'totalGarages': totalGarages,
    'totalVehicles': totalVehicles,
    'totalParcels': totalParcels,
    'parcelsInTransit': parcelsInTransit,
    'parcelsDeliveredToday': parcelsDeliveredToday,
    'parcelsPending': parcelsPending,
    'totalRevenue': totalRevenue,
    'revenueThisMonth': revenueThisMonth,
    'revenueLastMonth': revenueLastMonth,
    'parcelsByRegion': parcelsByRegion,
    'dailyStats': dailyStats.map((d) => d.toJson()).toList(),
    'garagePerformance': garagePerformance.map((g) => g.toJson()).toList(),
  };
}

class DailyStats {
  final DateTime date;
  final int parcels;
  final double revenue;
  final int activeDrivers;

  DailyStats({
    required this.date,
    required this.parcels,
    required this.revenue,
    required this.activeDrivers,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: DateTime.parse(json['date']),
      parcels: json['parcels'] ?? 0,
      revenue: (json['revenue'] ?? 0).toDouble(),
      activeDrivers: json['activeDrivers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'parcels': parcels,
    'revenue': revenue,
    'activeDrivers': activeDrivers,
  };
}

class GaragePerformance {
  final String garageId;
  final String garageName;
  final String city;
  final int parcelsHandled;
  final int onTimeDeliveries;
  final double rating;
  final double revenue;

  GaragePerformance({
    required this.garageId,
    required this.garageName,
    required this.city,
    required this.parcelsHandled,
    required this.onTimeDeliveries,
    required this.rating,
    required this.revenue,
  });

  factory GaragePerformance.fromJson(Map<String, dynamic> json) {
    return GaragePerformance(
      garageId: json['garageId'] ?? '',
      garageName: json['garageName'] ?? '',
      city: json['city'] ?? '',
      parcelsHandled: json['parcelsHandled'] ?? 0,
      onTimeDeliveries: json['onTimeDeliveries'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      revenue: (json['revenue'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'garageId': garageId,
    'garageName': garageName,
    'city': city,
    'parcelsHandled': parcelsHandled,
    'onTimeDeliveries': onTimeDeliveries,
    'rating': rating,
    'revenue': revenue,
  };
}