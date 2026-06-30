// lib/models/parcel.dart

// ignore_for_file: unused_import

import 'dart:convert';

import 'package:flutter/material.dart';

import 'payment.dart';
import 'voice_message.dart';

// ==================== ENUM PARCEL STATUS ====================
enum ParcelStatus {
  pending('pending', 'En attente', Colors.orange),
  free('free', 'Libre service', Colors.purple),
  confirmed('confirmed', 'Confirmé', Colors.blue),
  pickedUp('picked_up', 'Ramassé', Colors.indigo),
  inTransit('in_transit', 'En transit', Colors.deepPurple),
  arrived('arrived', 'Arrivé', Colors.teal),
  outForDelivery('out_for_delivery', 'En livraison', Colors.lightBlue),
  delivered('delivered', 'Livré', Colors.green),
  cancelled('cancelled', 'Annulé', Colors.red);

  final String value;
  final String label;
  final Color color;
  const ParcelStatus(this.value, this.label, this.color);

  static ParcelStatus fromString(String value) {
    return ParcelStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParcelStatus.pending,
    );
  }
  
  bool get isFree => this == ParcelStatus.free;
  bool get isPending => this == ParcelStatus.pending;
  bool get isConfirmed => this == ParcelStatus.confirmed;
  bool get isInProgress => this == ParcelStatus.confirmed || 
                            this == ParcelStatus.pickedUp || 
                            this == ParcelStatus.inTransit || 
                            this == ParcelStatus.arrived || 
                            this == ParcelStatus.outForDelivery;
  bool get isCompleted => this == ParcelStatus.delivered;
  bool get isCancelled => this == ParcelStatus.cancelled;
}

// ==================== ENUM PARCEL TYPE ====================
enum ParcelType {
  document('document', 'Documents', Icons.description),
  package('package', 'Colis standard', Icons.inventory),
  fragile('fragile', 'Fragile', Icons.warning_amber),
  perishable('perishable', 'Périssable', Icons.kitchen),
  valuable('valuable', 'Valeur', Icons.attach_money);

  final String value;
  final String label;
  final IconData icon;
  const ParcelType(this.value, this.label, this.icon);

  static ParcelType fromString(String value) {
    return ParcelType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ParcelType.package,
    );
  }
}

// ==================== ENUM BID STATUS ====================
enum BidStatus {
  pending('pending', 'En attente', Colors.orange),
  accepted('accepted', 'Acceptée', Colors.green),
  rejected('rejected', 'Refusée', Colors.red);

  final String value;
  final String label;
  final Color color;
  const BidStatus(this.value, this.label, this.color);

  static BidStatus fromString(String value) {
    return BidStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BidStatus.pending,
    );
  }
}

// ==================== CLASSE BID (OFFRE) ====================
class Bid {
  final String id;
  final String parcelId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final double price;
  final String? message;
  final BidStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseMessage;
  final String? audioUrl; // ✅ URL du message audio du chauffeur

  Bid({
    required this.id,
    required this.parcelId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.price,
    this.message,
    this.status = BidStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.responseMessage,
    this.audioUrl,
  });

  factory Bid.fromJson(Map<String, dynamic> json) {
    return Bid(
      id: json['id']?.toString() ?? '',
      parcelId: json['parcel_id']?.toString() ?? json['parcelId']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? json['driver_id']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? json['driver_name']?.toString() ?? '',
      driverPhone: json['driverPhone']?.toString() ?? json['driver_phone']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      message: json['message']?.toString(),
      status: json['status'] != null ? BidStatus.fromString(json['status'].toString()) : BidStatus.pending,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now()),
      respondedAt: json['respondedAt'] != null 
          ? DateTime.parse(json['respondedAt'].toString())
          : (json['responded_at'] != null ? DateTime.parse(json['responded_at'].toString()) : null),
      responseMessage: json['responseMessage']?.toString() ?? json['response_message']?.toString(),
      audioUrl: json['audioUrl']?.toString() ?? json['audio_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcel_id': parcelId,
    'driver_id': driverId,
    'driver_name': driverName,
    'driver_phone': driverPhone,
    'price': price,
    'message': message,
    'status': status.value,
    'created_at': createdAt.toIso8601String(),
    'responded_at': respondedAt?.toIso8601String(),
    'response_message': responseMessage,
    'audio_url': audioUrl,
  };

  // Propriétés calculées
  String get formattedPrice => '${price.toStringAsFixed(0)} FCFA';
  String get formattedDate => '${createdAt.day}/${createdAt.month} à ${createdAt.hour}h${createdAt.minute}';
  bool get isPending => status == BidStatus.pending;
  bool get isAccepted => status == BidStatus.accepted;
  bool get isRejected => status == BidStatus.rejected;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  Bid copyWith({
    String? id,
    String? parcelId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? price,
    String? message,
    BidStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? responseMessage,
    String? audioUrl,
  }) {
    return Bid(
      id: id ?? this.id,
      parcelId: parcelId ?? this.parcelId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      price: price ?? this.price,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}

// ==================== CLASSE PARCEL ====================
class Parcel {
  final String id;
  final String trackingNumber;
  
  // Expéditeur (client réel)
  final String senderId;
  final String senderName;
  final String senderPhone;
  final String? senderEmail;
  
  // Destinataire
  final String receiverName;
  final String receiverPhone;
  final String? receiverEmail;
  final String? receiverAddress;
  
  // Détails du colis
  final String description;
  final double weight;
  final double? length;
  final double? width;
  final double? height;
  final ParcelType type;
  final ParcelStatus status;
  
  // Trajet
  final String departureGarageId;
  final String departureGarageName;
  final String? arrivalGarageId;
  final String? arrivalGarageName;
  
  // Chauffeur
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  
  // Prix et options
  final double? price;
  final double? proposedPrice;
  final double? negotiatedPrice;
  final double? deliveryFees;
  final double? totalAmount;
  final bool isInsured;
  final double? insuranceAmount;
  final bool isUrgent;
  final double? urgentFee;
  
  // MARCHANDAGE (LIBRE SERVICE)
  final bool isFreeForBidding;
  final List<Bid> bids;
  final String? selectedBidId;
  
  // Paiement
  final PaymentMethod? paymentMethod;
  final String? paymentPhoneNumber;
  final String? paymentStatus;
  
  // Médias
  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> audioUrls;  // ✅ Messages vocaux du colis
  final String? signatureUrl;
  
  // Notes
  final String? notes;
  
  // Dates
  final DateTime? pickupDate;
  final DateTime? deliveryDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Traçabilité
  final String? createdBy;
  final String? createdByName;
  
  // Annulation
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  
  // Événements
  final List<ParcelEvent> events;

  Parcel({
    required this.id,
    required this.trackingNumber,
    required this.senderName,
    required this.senderPhone,
    this.senderId = '',
    this.senderEmail,
    required this.receiverName,
    required this.receiverPhone,
    this.receiverEmail,
    this.receiverAddress,
    required this.description,
    required this.weight,
    this.length,
    this.width,
    this.height,
    required this.type,
    required this.status,
    required this.departureGarageId,
    required this.departureGarageName,
    this.arrivalGarageId,
    this.arrivalGarageName,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.price,
    this.proposedPrice,
    this.negotiatedPrice,
    this.deliveryFees,
    this.totalAmount,
    this.isInsured = false,
    this.insuranceAmount,
    this.isUrgent = false,
    this.urgentFee,
    this.isFreeForBidding = false,
    this.bids = const [],
    this.selectedBidId,
    this.paymentMethod,
    this.paymentPhoneNumber,
    this.paymentStatus,
    this.photoUrls = const [],
    this.videoUrls = const [],
    this.audioUrls = const [],  // ✅ 
    this.signatureUrl,
    this.notes,
    this.pickupDate,
    this.deliveryDate,
    this.estimatedDeliveryDate,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.createdByName,
    this.cancelledBy,
    this.cancellationReason,
    this.cancelledAt,
    this.events = const [],
  });

  // ==================== FACTORY CONSTRUCTORS ====================
  
  factory Parcel.fromMinimalJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id']?.toString() ?? '',
      trackingNumber: json['trackingNumber']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderPhone: json['senderPhone']?.toString() ?? '',
      receiverName: json['receiverName']?.toString() ?? '',
      receiverPhone: json['receiverPhone']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      type: json['type'] != null ? ParcelType.fromString(json['type'].toString()) : ParcelType.package,
      status: json['status'] != null ? ParcelStatus.fromString(json['status'].toString()) : ParcelStatus.pending,
      departureGarageId: json['departureGarageId']?.toString() ?? '',
      departureGarageName: json['departureGarageName']?.toString() ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
    );
  }

  factory Parcel.fromJson(Map<String, dynamic> json) {
    String? parseString(dynamic value) => value?.toString();
    double? parseDouble(dynamic value) => value != null ? (value is double ? value : double.tryParse(value.toString())) : null;
    DateTime? parseDateTime(dynamic value) => value != null ? DateTime.tryParse(value.toString()) : null;
    
    List<String> parseList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) {
        if (value.isEmpty || value == '[]') return [];
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (e) {
          return [];
        }
      }
      return [];
    }
    
    // Récupérer les offres (bids)
    List<Bid> bids = [];
    if (json['bids'] != null && json['bids'] is List) {
      bids = (json['bids'] as List)
          .where((e) => e != null)
          .map((e) => Bid.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    
    // Récupérer les événements
    List<ParcelEvent> events = [];
    if (json['events'] != null && json['events'] is List) {
      events = (json['events'] as List)
          .where((e) => e != null)
          .map((e) => ParcelEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Parcel(
      id: parseString(json['id']) ?? '',
      trackingNumber: parseString(json['trackingNumber']) ?? '',
      senderId: parseString(json['senderId']) ?? '',
      senderName: parseString(json['senderName']) ?? '',
      senderPhone: parseString(json['senderPhone']) ?? '',
      senderEmail: parseString(json['senderEmail']),
      receiverName: parseString(json['receiverName']) ?? '',
      receiverPhone: parseString(json['receiverPhone']) ?? '',
      receiverEmail: parseString(json['receiverEmail']),
      receiverAddress: parseString(json['receiverAddress']),
      description: parseString(json['description']) ?? '',
      weight: parseDouble(json['weight']) ?? 0,
      length: parseDouble(json['length']),
      width: parseDouble(json['width']),
      height: parseDouble(json['height']),
      type: json['type'] != null ? ParcelType.fromString(parseString(json['type'])!) : ParcelType.package,
      status: json['status'] != null ? ParcelStatus.fromString(parseString(json['status'])!) : ParcelStatus.pending,
      departureGarageId: parseString(json['departureGarageId']) ?? '',
      departureGarageName: parseString(json['departureGarageName']) ?? '',
      arrivalGarageId: parseString(json['arrivalGarageId']),
      arrivalGarageName: parseString(json['arrivalGarageName']),
      driverId: parseString(json['driverId']),
      driverName: parseString(json['driverName']),
      driverPhone: parseString(json['driverPhone']),
      price: parseDouble(json['price']),
      proposedPrice: parseDouble(json['proposedPrice'] ?? json['proposed_price']),
      negotiatedPrice: parseDouble(json['negotiatedPrice'] ?? json['negotiated_price']),
      deliveryFees: parseDouble(json['deliveryFees']),
      totalAmount: parseDouble(json['totalAmount']),
      isInsured: json['isInsured'] ?? false,
      insuranceAmount: parseDouble(json['insuranceAmount']),
      isUrgent: json['isUrgent'] ?? false,
      urgentFee: parseDouble(json['urgentFee']),
      isFreeForBidding: json['isFreeForBidding'] ?? json['is_free_for_bidding'] ?? false,
      bids: bids,
      selectedBidId: parseString(json['selectedBidId'] ?? json['selected_bid_id']),
      paymentMethod: json['paymentMethod'] != null ? PaymentMethod.fromString(parseString(json['paymentMethod'])!) : null,
      paymentPhoneNumber: parseString(json['paymentPhoneNumber']),
      paymentStatus: parseString(json['paymentStatus']),
      photoUrls: parseList(json['photoUrls']),
      videoUrls: parseList(json['videoUrls']),
      audioUrls: parseList(json['audioUrls']),  // ✅ 
      signatureUrl: parseString(json['signatureUrl']),
      notes: parseString(json['notes']),
      pickupDate: parseDateTime(json['pickupDate']),
      deliveryDate: parseDateTime(json['deliveryDate']),
      estimatedDeliveryDate: parseDateTime(json['estimatedDeliveryDate']),
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt']),
      createdBy: parseString(json['createdBy']),
      createdByName: parseString(json['createdByName']),
      cancelledBy: parseString(json['cancelledBy']),
      cancellationReason: parseString(json['cancellationReason']),
      cancelledAt: parseDateTime(json['cancelledAt']),
      events: events,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackingNumber': trackingNumber,
    'senderId': senderId,
    'senderName': senderName,
    'senderPhone': senderPhone,
    'senderEmail': senderEmail,
    'receiverName': receiverName,
    'receiverPhone': receiverPhone,
    'receiverEmail': receiverEmail,
    'receiverAddress': receiverAddress,
    'description': description,
    'weight': weight,
    'length': length,
    'width': width,
    'height': height,
    'type': type.value,
    'status': status.value,
    'departureGarageId': departureGarageId,
    'departureGarageName': departureGarageName,
    'arrivalGarageId': arrivalGarageId,
    'arrivalGarageName': arrivalGarageName,
    'driverId': driverId,
    'driverName': driverName,
    'driverPhone': driverPhone,
    'price': price,
    'proposedPrice': proposedPrice,
    'negotiatedPrice': negotiatedPrice,
    'deliveryFees': deliveryFees,
    'totalAmount': totalAmount,
    'isInsured': isInsured,
    'insuranceAmount': insuranceAmount,
    'isUrgent': isUrgent,
    'urgentFee': urgentFee,
    'isFreeForBidding': isFreeForBidding,
    'bids': bids.map((b) => b.toJson()).toList(),
    'selectedBidId': selectedBidId,
    'paymentMethod': paymentMethod?.value,
    'paymentPhoneNumber': paymentPhoneNumber,
    'paymentStatus': paymentStatus,
    'photoUrls': photoUrls,
    'videoUrls': videoUrls,
    'audioUrls': audioUrls,  // ✅ 
    'signatureUrl': signatureUrl,
    'notes': notes,
    'pickupDate': pickupDate?.toIso8601String(),
    'deliveryDate': deliveryDate?.toIso8601String(),
    'estimatedDeliveryDate': estimatedDeliveryDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'createdBy': createdBy,
    'createdByName': createdByName,
    'cancelledBy': cancelledBy,
    'cancellationReason': cancellationReason,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
  };

  // ==================== PROPRIÉTÉS CALCULÉES ====================
  
  bool get isPending => status == ParcelStatus.pending;
  bool get isFree => status == ParcelStatus.free;
  bool get isConfirmed => status == ParcelStatus.confirmed;
  bool get isPickedUp => status == ParcelStatus.pickedUp;
  bool get isInTransit => status == ParcelStatus.inTransit;
  bool get isArrived => status == ParcelStatus.arrived;
  bool get isOutForDelivery => status == ParcelStatus.outForDelivery;
  bool get isDelivered => status == ParcelStatus.delivered;
  bool get isCancelled => status == ParcelStatus.cancelled;
  
  bool get isInProgress => status == ParcelStatus.confirmed || 
                            status == ParcelStatus.pickedUp || 
                            status == ParcelStatus.inTransit || 
                            status == ParcelStatus.arrived || 
                            status == ParcelStatus.outForDelivery;
  
  bool get isFinished => status == ParcelStatus.delivered || status == ParcelStatus.cancelled;
  
  bool get hasDriver => driverId != null && driverId!.isNotEmpty;
  bool get hasClient => senderId.isNotEmpty;
  
  bool get hasBids => bids.isNotEmpty;
  int get bidsCount => bids.length;
  
  bool get hasAudio => audioUrls.isNotEmpty;
  int get audioCount => audioUrls.length;
  
  Bid? get bestBid {
    if (bids.isEmpty) return null;
    return bids.reduce((a, b) => a.price > b.price ? a : b);
  }
  
  Bid? get selectedBid {
    if (selectedBidId == null) return null;
    try {
      return bids.firstWhere((b) => b.id == selectedBidId);
    } catch (e) {
      return null;
    }
  }
  
  List<Bid> get pendingBids => bids.where((b) => b.isPending).toList();
  List<Bid> get acceptedBids => bids.where((b) => b.isAccepted).toList();
  List<Bid> get rejectedBids => bids.where((b) => b.isRejected).toList();
  
  bool get isPaid => paymentStatus == 'completed' || paymentStatus == 'paid';
  
  String get formattedWeight => '${weight.toStringAsFixed(1)} kg';
  
  String get formattedPrice => price != null ? '${price!.toStringAsFixed(0)} FCFA' : 'Non défini';
  
  String get formattedProposedPrice => proposedPrice != null ? '${proposedPrice!.toStringAsFixed(0)} FCFA' : 'Non défini';
  
  String get formattedNegotiatedPrice => negotiatedPrice != null ? '${negotiatedPrice!.toStringAsFixed(0)} FCFA' : 'Non défini';
  
  String get formattedTotal => totalAmount != null 
      ? '${totalAmount!.toStringAsFixed(0)} FCFA' 
      : (price != null ? '${price!.toStringAsFixed(0)} FCFA' : '0 FCFA');
  
  String get formattedDeliveryFees => deliveryFees != null ? '${deliveryFees!.toStringAsFixed(0)} FCFA' : '0 FCFA';
  
  double get volume {
    if (length == null || width == null || height == null) return 0;
    return length! * width! * height! / 1000000;
  }
  
  String get formattedVolume => '${volume.toStringAsFixed(2)} m³';
  
  String get formattedDate => '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  
  String get formattedTime => '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  
  String get formattedDateTime => '$formattedDate à $formattedTime';
  
  String get formattedDeliveryDate => deliveryDate != null 
      ? '${deliveryDate!.day}/${deliveryDate!.month}/${deliveryDate!.year}' 
      : 'Non livré';
  
  String get statusIcon {
    switch (status) {
      case ParcelStatus.pending:
        return '⏳';
      case ParcelStatus.free:
        return '🔓';
      case ParcelStatus.confirmed:
        return '✅';
      case ParcelStatus.pickedUp:
        return '📦';
      case ParcelStatus.inTransit:
        return '🚚';
      case ParcelStatus.arrived:
        return '📍';
      case ParcelStatus.outForDelivery:
        return '🚛';
      case ParcelStatus.delivered:
        return '🎉';
      case ParcelStatus.cancelled:
        return '❌';
    }
  }
  
  String get biddingStatusText {
    if (!isFreeForBidding) return 'Non disponible pour marchandage';
    if (selectedBidId != null) return 'Offre acceptée';
    if (bids.isEmpty) return 'Aucune offre pour le moment';
    return '${bids.length} offre(s) reçue(s)';
  }
  
  Color get biddingStatusColor {
    if (!isFreeForBidding) return Colors.grey;
    if (selectedBidId != null) return Colors.green;
    if (bids.isEmpty) return Colors.orange;
    return Colors.blue;
  }

  // ==================== COPY WITH ====================
  
  Parcel copyWith({
    String? id,
    String? trackingNumber,
    String? senderId,
    String? senderName,
    String? senderPhone,
    String? senderEmail,
    String? receiverName,
    String? receiverPhone,
    String? receiverEmail,
    String? receiverAddress,
    String? description,
    double? weight,
    double? length,
    double? width,
    double? height,
    ParcelType? type,
    ParcelStatus? status,
    String? departureGarageId,
    String? departureGarageName,
    String? arrivalGarageId,
    String? arrivalGarageName,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? price,
    double? proposedPrice,
    double? negotiatedPrice,
    double? deliveryFees,
    double? totalAmount,
    bool? isInsured,
    double? insuranceAmount,
    bool? isUrgent,
    double? urgentFee,
    bool? isFreeForBidding,
    List<Bid>? bids,
    String? selectedBidId,
    PaymentMethod? paymentMethod,
    String? paymentPhoneNumber,
    String? paymentStatus,
    List<String>? photoUrls,
    List<String>? videoUrls,
    List<String>? audioUrls,
    String? signatureUrl,
    String? notes,
    DateTime? pickupDate,
    DateTime? deliveryDate,
    DateTime? estimatedDeliveryDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? cancelledBy,
    String? cancellationReason,
    DateTime? cancelledAt,
    List<ParcelEvent>? events,
  }) {
    return Parcel(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      receiverAddress: receiverAddress ?? this.receiverAddress,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      type: type ?? this.type,
      status: status ?? this.status,
      departureGarageId: departureGarageId ?? this.departureGarageId,
      departureGarageName: departureGarageName ?? this.departureGarageName,
      arrivalGarageId: arrivalGarageId ?? this.arrivalGarageId,
      arrivalGarageName: arrivalGarageName ?? this.arrivalGarageName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      price: price ?? this.price,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      negotiatedPrice: negotiatedPrice ?? this.negotiatedPrice,
      deliveryFees: deliveryFees ?? this.deliveryFees,
      totalAmount: totalAmount ?? this.totalAmount,
      isInsured: isInsured ?? this.isInsured,
      insuranceAmount: insuranceAmount ?? this.insuranceAmount,
      isUrgent: isUrgent ?? this.isUrgent,
      urgentFee: urgentFee ?? this.urgentFee,
      isFreeForBidding: isFreeForBidding ?? this.isFreeForBidding,
      bids: bids ?? this.bids,
      selectedBidId: selectedBidId ?? this.selectedBidId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentPhoneNumber: paymentPhoneNumber ?? this.paymentPhoneNumber,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      photoUrls: photoUrls ?? this.photoUrls,
      videoUrls: videoUrls ?? this.videoUrls,
      audioUrls: audioUrls ?? this.audioUrls,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      notes: notes ?? this.notes,
      pickupDate: pickupDate ?? this.pickupDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      estimatedDeliveryDate: estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      events: events ?? this.events,
    );
  }
  
  // ==================== MÉTHODES UTILES POUR LE MARCHANDAGE ====================
  
  Parcel addBid(Bid bid) {
    final newBids = [...bids, bid];
    return copyWith(bids: newBids);
  }
  
  Parcel acceptBid(String bidId) {
    final updatedBids = bids.map((b) {
      if (b.id == bidId) {
        return b.copyWith(
          status: BidStatus.accepted,
          respondedAt: DateTime.now(),
        );
      }
      return b;
    }).toList();
    
    final acceptedBid = updatedBids.firstWhere((b) => b.id == bidId);
    
    return copyWith(
      bids: updatedBids,
      selectedBidId: bidId,
      status: ParcelStatus.confirmed,
      driverId: acceptedBid.driverId,
      driverName: acceptedBid.driverName,
      driverPhone: acceptedBid.driverPhone,
      negotiatedPrice: acceptedBid.price,
    );
  }
  
  Parcel rejectBid(String bidId, {String? responseMessage}) {
    final updatedBids = bids.map((b) {
      if (b.id == bidId) {
        return b.copyWith(
          status: BidStatus.rejected,
          respondedAt: DateTime.now(),
          responseMessage: responseMessage,
        );
      }
      return b;
    }).toList();
    
    return copyWith(bids: updatedBids);
  }
  
  Parcel setFreeForBidding({double? proposedPrice}) {
    return copyWith(
      isFreeForBidding: true,
      status: ParcelStatus.free,
      proposedPrice: proposedPrice ?? this.proposedPrice,
    );
  }
  
  Parcel closeBidding() {
    return copyWith(isFreeForBidding: false);
  }
}

// ==================== CLASSE PARCEL EVENT ====================
class ParcelEvent {
  final String id;
  final String parcelId;
  final ParcelStatus status;
  final String description;
  final String? location;
  final String? locationLat;
  final String? locationLng;
  final String? userId;
  final String? userName;
  final String? userRole;
  final String? photoUrl;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  ParcelEvent({
    required this.id,
    required this.parcelId,
    required this.status,
    required this.description,
    this.location,
    this.locationLat,
    this.locationLng,
    this.userId,
    this.userName,
    this.userRole,
    this.photoUrl,
    this.metadata = const {},
    required this.timestamp,
  });

  factory ParcelEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> metadata = {};
    if (json['metadata'] != null) {
      if (json['metadata'] is String) {
        try {
          metadata = jsonDecode(json['metadata']);
        } catch (e) {
          metadata = {};
        }
      } else if (json['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(json['metadata']);
      }
    }
    
    DateTime parseDate(dynamic dateValue) {
      if (dateValue == null) return DateTime.now();
      if (dateValue is DateTime) return dateValue;
      if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return ParcelEvent(
      id: json['id']?.toString() ?? '',
      parcelId: json['parcelId']?.toString() ?? json['parcel_id']?.toString() ?? '',
      status: json['status'] != null ? ParcelStatus.fromString(json['status'].toString()) : ParcelStatus.pending,
      description: json['description']?.toString() ?? '',
      location: json['location']?.toString(),
      locationLat: json['locationLat']?.toString(),
      locationLng: json['locationLng']?.toString(),
      userId: json['userId']?.toString(),
      userName: json['userName']?.toString(),
      userRole: json['userRole']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      metadata: metadata,
      timestamp: parseDate(json['timestamp'] ?? json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcelId': parcelId,
    'status': status.value,
    'description': description,
    'location': location,
    'locationLat': locationLat,
    'locationLng': locationLng,
    'userId': userId,
    'userName': userName,
    'userRole': userRole,
    'photoUrl': photoUrl,
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
  };
  
  String get formattedTime {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
  
  String get formattedDate {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
  
  String get formattedDateTime {
    return '$formattedDate à $formattedTime';
  }
  
  T? getMetadata<T>(String key) {
    if (metadata.containsKey(key)) {
      return metadata[key] as T?;
    }
    return null;
  }
  
  bool get hasLocation => location != null && location!.isNotEmpty;
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;
  bool get hasUser => userName != null && userName!.isNotEmpty;
}