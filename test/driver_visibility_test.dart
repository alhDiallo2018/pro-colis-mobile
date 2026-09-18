import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/utils/driver_visibility.dart';

void main() {
  User driver({
    required String id,
    required String name,
    bool verified = false,
    DriverStatus status = DriverStatus.available,
    double rating = 0,
    int deliveries = 0,
  }) {
    return User(
      id: id,
      email: '',
      phone: '',
      fullName: name,
      role: UserRole.driver,
      isVerified: verified,
      driverStatus: status,
      rating: rating,
      completedDeliveries: deliveries,
      createdAt: DateTime.utc(2026),
    );
  }

  test('place les chauffeurs vérifiés avant les autres', () {
    final result = visibleDrivers([
      driver(id: 'a', name: 'Non vérifié', rating: 5),
      driver(id: 'b', name: 'Vérifié', verified: true, rating: 3),
    ]);

    expect(result.map((d) => d.id), ['b', 'a']);
  });

  test('peut masquer tous les chauffeurs non vérifiés', () {
    final result = visibleDrivers(
      [
        driver(id: 'a', name: 'Non vérifié'),
        driver(id: 'b', name: 'Vérifié', verified: true),
      ],
      verifiedOnly: true,
    );

    expect(result.map((d) => d.id), ['b']);
  });

  test('priorise ensuite disponibilité, note et expérience', () {
    final result = visibleDrivers([
      driver(
        id: 'offline',
        name: 'Hors ligne',
        verified: true,
        status: DriverStatus.offline,
        rating: 5,
      ),
      driver(
        id: 'available-low',
        name: 'Disponible B',
        verified: true,
        rating: 4,
      ),
      driver(
        id: 'available-high',
        name: 'Disponible A',
        verified: true,
        rating: 4.8,
      ),
    ]);

    expect(
      result.map((d) => d.id),
      ['available-high', 'available-low', 'offline'],
    );
  });
}
