import '../models/user.dart';

/// Prépare une liste publique de chauffeurs pour les écrans client.
///
/// Les chauffeurs vérifiés sont toujours prioritaires. À niveau de
/// vérification égal, la disponibilité, la note puis le nombre de livraisons
/// déterminent l'ordre. Le filtre permet au client de masquer immédiatement
/// les profils non vérifiés sans altérer les données reçues de l'API.
List<User> visibleDrivers(
  Iterable<User> source, {
  bool verifiedOnly = false,
  bool availableOnly = false,
  bool nearestFirst = false,
}) {
  final drivers = source
      .where((driver) =>
          (!verifiedOnly || driver.isVerified) &&
          (!availableOnly || driver.driverStatus == DriverStatus.available))
      .toList(growable: false);

  int statusRank(DriverStatus? status) => switch (status) {
        DriverStatus.available => 0,
        DriverStatus.busy => 1,
        DriverStatus.offline || null => 2,
      };

  drivers.sort((a, b) {
    // Un tri de proximité explicite prime sur la note ; les GPS inconnus sont derniers.
    if (nearestFirst) {
      final distance = (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity);
      if (distance != 0) return distance;
    }
    final verified = (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
    if (verified != 0) return verified;

    final status =
        statusRank(a.driverStatus).compareTo(statusRank(b.driverStatus));
    if (status != 0) return status;

    final rating = (b.rating ?? 0).compareTo(a.rating ?? 0);
    if (rating != 0) return rating;

    final deliveries =
        (b.completedDeliveries ?? 0).compareTo(a.completedDeliveries ?? 0);
    if (deliveries != 0) return deliveries;

    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  });

  return drivers;
}
