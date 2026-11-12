// lib/services/api/manifest_api.dart
//
// Phase 1 — Manifeste navette : consomme `GET /advertisements/:id/manifest`
// qui liste les offres acceptées regroupées par arrêt pour un trajet
// (TransitLine). Chaque arrêt contient `picked` (colis à embarquer) et
// `dropOffs` (colis à remettre). Les offres sans affectation d'arrêt sont
// listées dans `unassigned`.
//
// Le backend renvoie directement les champs à plat (voir mobile.controller
// `advertisementManifest`), sans wrapper `data`. On garde la même forme ici.

import 'client.dart';

class ManifestOfferSummary {
  final String id;
  final String? parcelId;
  final String? trackingNumber;
  final String? receiverName;
  final double? price;
  final int? boardingStopOrder;
  final int? dropOffStopOrder;

  const ManifestOfferSummary({
    required this.id,
    this.parcelId,
    this.trackingNumber,
    this.receiverName,
    this.price,
    this.boardingStopOrder,
    this.dropOffStopOrder,
  });

  factory ManifestOfferSummary.fromJson(Map<String, dynamic> json) {
    final parcel = (json['parcel'] as Map?)?.cast<String, dynamic>();
    final rawPrice = json['price'];
    double? parsedPrice;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice);
    }
    return ManifestOfferSummary(
      id: json['id']?.toString() ?? '',
      parcelId: json['parcelId']?.toString(),
      trackingNumber: parcel?['trackingNumber']?.toString(),
      receiverName: parcel?['receiverName']?.toString(),
      price: parsedPrice,
      boardingStopOrder: json['boardingStop'] is Map
          ? (json['boardingStop']['order'] as num?)?.toInt()
          : null,
      dropOffStopOrder: json['dropOffStop'] is Map
          ? (json['dropOffStop']['order'] as num?)?.toInt()
          : null,
    );
  }
}

class ManifestStop {
  final int order;
  final String? label;
  final String? zoneId;
  final List<ManifestOfferSummary> picked;
  final List<ManifestOfferSummary> dropOffs;

  const ManifestStop({
    required this.order,
    this.label,
    this.zoneId,
    this.picked = const [],
    this.dropOffs = const [],
  });

  factory ManifestStop.fromJson(Map<String, dynamic> json) => ManifestStop(
        order: json['order'] is num ? (json['order'] as num).toInt() : 0,
        label: json['label']?.toString(),
        zoneId: json['zoneId']?.toString(),
        picked: (json['picked'] as List?)
                ?.whereType<Map>()
                .map((e) => ManifestOfferSummary.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        dropOffs: (json['dropOffs'] as List?)
                ?.whereType<Map>()
                .map((e) => ManifestOfferSummary.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  int get totalOffers => picked.length + dropOffs.length;
}

class AdvertisementManifest {
  final String advertisementId;
  final String? transitLineId;
  final int totalOffers;
  final List<ManifestStop> stops;
  final List<ManifestOfferSummary> unassigned;

  const AdvertisementManifest({
    required this.advertisementId,
    this.transitLineId,
    this.totalOffers = 0,
    this.stops = const [],
    this.unassigned = const [],
  });

  factory AdvertisementManifest.fromJson(Map<String, dynamic> json) =>
      AdvertisementManifest(
        advertisementId: json['advertisementId']?.toString() ?? '',
        transitLineId: json['transitLineId']?.toString(),
        totalOffers: json['totalOffers'] is num
            ? (json['totalOffers'] as num).toInt()
            : 0,
        stops: (json['stops'] as List?)
                ?.whereType<Map>()
                .map((e) => ManifestStop.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        unassigned: (json['unassigned'] as List?)
                ?.whereType<Map>()
                .map((e) => ManifestOfferSummary.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class ManifestApi {
  final ApiClient client;

  ManifestApi(this.client);

  /// `GET /advertisements/:advertisementId/manifest`.
  /// Le payload backend n'est pas enveloppé dans `data`.
  Future<AdvertisementManifest> fetch(String advertisementId) async {
    final res = await client.dio.get('/advertisements/$advertisementId/manifest');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return AdvertisementManifest.fromJson(payload);
  }
}
