import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address.dart';
import '../models/garage.dart';
import '../services/api/addresses_api.dart';
import '../services/api/client.dart';
import '../services/api_service.dart';

final addressesApiProvider =
    Provider<AddressesApi>((ref) => AddressesApi(ApiClient()));

final addressesProvider = FutureProvider<List<Address>>(
  (ref) => ref.watch(addressesApiProvider).listAddresses(),
);

final favoriteGaragesProvider = FutureProvider<List<Garage>>(
  (ref) => ref.watch(addressesApiProvider).favoriteGarages(),
);

/// La liste publique est encore portée par le client historique. Seules les
/// mutations de favoris, nouvelles dans ce lot, passent par l'API modulaire.
final availableGaragesProvider = FutureProvider<List<Garage>>(
  (ref) => ApiService().getAllGarages(),
);

Future<void> refreshAddresses(WidgetRef ref) async {
  ref.invalidate(addressesProvider);
  await ref.read(addressesProvider.future);
}

Future<void> refreshFavoriteGarages(WidgetRef ref) async {
  ref.invalidate(favoriteGaragesProvider);
  await ref.read(favoriteGaragesProvider.future);
}
