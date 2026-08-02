import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/utils/parcel_access_policy.dart';

void main() {
  User buildClient({
    required String id,
    required String phone,
  }) {
    return User(
      id: id,
      email: '$id@example.com',
      phone: phone,
      fullName: 'Client $id',
      role: UserRole.client,
      createdAt: DateTime(2026),
    );
  }

  Parcel buildParcel({
    String senderId = 'sender-1',
    String senderPhone = '+221 77 000 00 01',
    String receiverPhone = '+221 78 000 00 02',
  }) {
    return Parcel(
      id: 'parcel-1',
      trackingNumber: 'PC-ACCESS',
      senderId: senderId,
      senderName: 'Expéditeur',
      senderPhone: senderPhone,
      receiverName: 'Destinataire',
      receiverPhone: receiverPhone,
      description: 'Colis de contrôle',
      weight: 1,
      type: ParcelType.package,
      status: ParcelStatus.pending,
      departureZoneId: 'garage-1',
      departureZoneName: 'Dakar',
      createdAt: DateTime(2026),
    );
  }

  test('l’expéditeur est reconnu uniquement par senderId', () {
    final parcel = buildParcel();
    final sender = buildClient(id: 'sender-1', phone: '+221 70 000 00 00');
    final samePhoneThirdParty =
        buildClient(id: 'third-party', phone: parcel.senderPhone);

    expect(isParcelSender(parcel, sender), isTrue);
    expect(isParcelSender(parcel, samePhoneThirdParty), isFalse);
  });

  test('le destinataire est reconnu par receiverPhone normalisé', () {
    final parcel = buildParcel(receiverPhone: '+221 78 123 45 67');
    final recipient = buildClient(id: 'recipient', phone: '78 123 45 67');

    expect(isParcelRecipient(parcel, recipient), isTrue);
    expect(canClientReadParcel(parcel, recipient), isTrue);
    expect(canClientMutateParcel(parcel, recipient), isFalse);
  });

  test('un client tiers ne peut ni lire ni modifier le colis', () {
    final parcel = buildParcel();
    final thirdParty =
        buildClient(id: 'third-party', phone: '+221 76 999 99 99');

    expect(canClientReadParcel(parcel, thirdParty), isFalse);
    expect(canClientMutateParcel(parcel, thirdParty), isFalse);
  });

  test('deux téléphones vides ne donnent jamais accès', () {
    final parcel = buildParcel(receiverPhone: '');
    final emptyPhoneClient = buildClient(id: 'third-party', phone: '');

    expect(normalizeParcelIdentityPhone(''), isNull);
    expect(isParcelRecipient(parcel, emptyPhoneClient), isFalse);
    expect(canClientReadParcel(parcel, emptyPhoneClient), isFalse);
  });
}
