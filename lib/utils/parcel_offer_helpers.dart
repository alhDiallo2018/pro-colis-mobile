import '../models/parcel.dart';
import '../models/user.dart';

/// Retourne la zone de résidence enregistrée dans le profil.
///
/// La ville correspond au lieu renseigné par l'utilisateur. Le nom de la zone
/// de rattachement reste un repli utile pour les anciens profils chauffeur qui
/// ne possèdent pas encore de ville.
String? resolveUserResidenceZone(User? user) {
  final candidates = [user?.city, user?.zoneName];
  for (final candidate in candidates) {
    final value = candidate?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Normalise uniquement la casse et les espaces afin de conserver une
/// comparaison exacte de la zone, sans accepter une sous-chaîne voisine.
String normalizeZoneName(String? value) {
  return value?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ?? '';
}

bool parcelStartsInUserZone(Parcel parcel, User? user) {
  final userZone = normalizeZoneName(resolveUserResidenceZone(user));
  if (userZone.isEmpty) return false;

  return normalizeZoneName(parcel.departureZoneName) == userZone;
}

/// Recherche l'offre déjà envoyée par l'utilisateur sur un colis afin
/// d'empêcher l'interface de proposer une seconde soumission.
Bid? findUserBid(Parcel parcel, String? userId) {
  if (userId == null || userId.isEmpty) return null;

  for (final bid in parcel.bids) {
    if (bid.driverId == userId) return bid;
  }
  return null;
}

/// Retrouve une proposition client quelle que soit la variante du contrat API
/// (`clientId`, `client_id` ou objet `client`) renvoyée par le backend.
Map<String, dynamic>? findUserAdvertisementOffer(
  Iterable<dynamic> offers,
  String? userId,
) {
  if (userId == null || userId.isEmpty) return null;

  for (final rawOffer in offers) {
    if (rawOffer is! Map) continue;
    final offer = Map<String, dynamic>.from(rawOffer);
    final client = offer['client'];
    final nestedClientId = client is Map ? client['id']?.toString() : null;
    final clientId = offer['clientId']?.toString() ??
        offer['client_id']?.toString() ??
        nestedClientId;

    if (clientId == userId) return offer;
  }
  return null;
}
