double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class UserStats {
  final int totalParcels;
  final int activeParcels;
  final int deliveredParcels;
  final int pendingBids;
  final int unreadNotifications;
  final int scoreBalance;

  const UserStats({
    required this.totalParcels,
    required this.activeParcels,
    required this.deliveredParcels,
    required this.pendingBids,
    required this.unreadNotifications,
    required this.scoreBalance,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalParcels: _intValue(json['totalParcels']),
        activeParcels: _intValue(json['activeParcels']),
        deliveredParcels: _intValue(json['deliveredParcels']),
        pendingBids: _intValue(json['pendingBids']),
        unreadNotifications: _intValue(json['unreadNotifications']),
        scoreBalance: _intValue(json['scoreBalance']),
      );
}

class ClientBidStats {
  final int received;
  final int pending;
  final int accepted;
  final int rejected;

  const ClientBidStats({
    required this.received,
    required this.pending,
    required this.accepted,
    required this.rejected,
  });

  factory ClientBidStats.fromJson(Map<String, dynamic> json) => ClientBidStats(
        received: _intValue(json['received']),
        pending: _intValue(json['pending']),
        accepted: _intValue(json['accepted']),
        rejected: _intValue(json['rejected']),
      );
}

class ClientProfileStats {
  final UserStats user;
  final ClientBidStats bids;

  const ClientProfileStats({required this.user, required this.bids});
}

class DriverStats {
  final int assignedParcels;
  final int activeParcels;
  final int completedDeliveries;
  final double rating;
  final int scoreBalance;
  final int pendingBids;
  final int openAdvertisements;

  const DriverStats({
    required this.assignedParcels,
    required this.activeParcels,
    required this.completedDeliveries,
    required this.rating,
    required this.scoreBalance,
    required this.pendingBids,
    required this.openAdvertisements,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) => DriverStats(
        assignedParcels: _intValue(json['assignedParcels']),
        activeParcels: _intValue(json['activeParcels']),
        completedDeliveries: _intValue(json['completedDeliveries']),
        rating: _doubleValue(json['rating']),
        scoreBalance: _intValue(json['scoreBalance']),
        pendingBids: _intValue(json['pendingBids']),
        openAdvertisements: _intValue(json['openAdvertisements']),
      );
}

class GarageStats {
  final String? garageId;
  final int totalParcels;
  final int activeParcels;
  final int deliveredToday;
  final int activeDrivers;
  final double revenue;
  final Map<String, int> parcelsByStatus;

  const GarageStats({
    required this.garageId,
    required this.totalParcels,
    required this.activeParcels,
    required this.deliveredToday,
    required this.activeDrivers,
    required this.revenue,
    required this.parcelsByStatus,
  });

  factory GarageStats.fromJson(Map<String, dynamic> json) {
    // L'agrégat Prisma est un objet dynamique ; convertir chaque valeur évite
    // qu'un entier sérialisé comme chaîne casse l'affichage.
    final rawStatuses = json['parcelsByStatus'];
    final statuses = <String, int>{};
    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        statuses[entry.key.toString()] = _intValue(entry.value);
      }
    }

    return GarageStats(
      garageId: json['garageId']?.toString(),
      totalParcels: _intValue(json['totalParcels']),
      activeParcels: _intValue(json['activeParcels']),
      deliveredToday: _intValue(json['deliveredToday']),
      activeDrivers: _intValue(json['activeDrivers']),
      revenue: _doubleValue(json['revenue']),
      parcelsByStatus: statuses,
    );
  }
}

class GlobalStats {
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

  const GlobalStats({
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
  });

  factory GlobalStats.fromJson(Map<String, dynamic> json) => GlobalStats(
        totalUsers: _intValue(json['totalUsers']),
        totalDrivers: _intValue(json['totalDrivers']),
        totalClients: _intValue(json['totalClients']),
        totalGarages: _intValue(json['totalGarages']),
        totalVehicles: _intValue(json['totalVehicles']),
        totalParcels: _intValue(json['totalParcels']),
        parcelsInTransit: _intValue(json['parcelsInTransit']),
        parcelsDeliveredToday: _intValue(json['parcelsDeliveredToday']),
        parcelsPending: _intValue(json['parcelsPending']),
        totalRevenue: _doubleValue(json['totalRevenue']),
      );
}

class AdvertisementStats {
  final int total;
  final int open;
  final int closed;

  const AdvertisementStats({
    required this.total,
    required this.open,
    required this.closed,
  });

  factory AdvertisementStats.fromJson(Map<String, dynamic> json) =>
      AdvertisementStats(
        total: _intValue(json['total']),
        open: _intValue(json['open']),
        closed: _intValue(json['closed']),
      );
}
