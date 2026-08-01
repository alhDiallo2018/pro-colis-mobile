import '../models/parcel.dart';
import '../models/user.dart';

/// Normalise un numéro sénégalais pour une comparaison d'identité.
///
/// Un numéro incomplet ou vide retourne `null` : deux valeurs absentes ne
/// doivent jamais suffire à donner accès à un colis.
String? normalizeParcelIdentityPhone(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length < 9) return null;
  return digits.substring(digits.length - 9);
}

/// L'expéditeur est identifié uniquement par la relation persistée
/// `senderId`. Le nom, l'e-mail et le téléphone ne sont pas des preuves
/// d'appartenance fiables.
bool isParcelSender(Parcel parcel, User? user) {
  if (user == null || user.id.isEmpty || parcel.senderId.isEmpty) return false;
  return parcel.senderId == user.id;
}

/// Normalise un email pour comparaison, comme le fait le backend avec
/// `normalizeEmail`.
String? _normalizeEmail(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.toLowerCase();
}

/// Le schéma ne possède pas encore de `receiverId`; l'identité du destinataire
/// repose donc sur le téléphone OU l'email, après normalisation.
/// Les deux sont comparés avec la même logique que le backend
/// (`normalizePhone` / `normalizeEmail` du service parcel).
bool isParcelRecipient(Parcel parcel, User? user) {
  if (user == null) return false;

  final receiverPhone = normalizeParcelIdentityPhone(parcel.receiverPhone);
  final userPhone = normalizeParcelIdentityPhone(user.phone);
  if (receiverPhone != null && userPhone != null && receiverPhone == userPhone) {
    return true;
  }

  final receiverEmail = _normalizeEmail(parcel.receiverEmail);
  final userEmail = _normalizeEmail(user.email);
  if (receiverEmail != null && userEmail != null && receiverEmail == userEmail) {
    return true;
  }

  return false;
}

bool canClientReadParcel(Parcel parcel, User? user) {
  return isParcelSender(parcel, user) || isParcelRecipient(parcel, user);
}

/// Les mutations client restent réservées à l'expéditeur, même lorsque le
/// destinataire est autorisé à consulter le détail et la timeline.
bool canClientMutateParcel(Parcel parcel, User? user) {
  return isParcelSender(parcel, user);
}
