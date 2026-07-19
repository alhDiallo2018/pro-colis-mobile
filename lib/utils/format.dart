import 'package:intl/intl.dart';

final _nf = NumberFormat('#,##0', 'fr_FR');

String formatFcfa(num? amount) {
  if (amount == null) return '—';
  return '${_nf.format(amount.round())} FCFA';
}

String formatPoints(num? points) {
  if (points == null) return '—';
  final sign = points > 0 ? '+' : '';
  return '$sign${_nf.format(points)} pts';
}

String formatWeight(num? weight) {
  if (weight == null) return '—';
  return '${_nf.format(weight)} kg';
}

final _dateFmt = DateFormat("dd MMM yyyy", 'fr_FR');
final _dateTimeFmt = DateFormat("dd MMM yyyy HH:mm", 'fr_FR');

String formatDate(DateTime? date) {
  if (date == null) return '—';
  return _dateFmt.format(date);
}

String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  return _dateTimeFmt.format(date);
}

String formatDateIso(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return _dateFmt.format(d);
}

String formatDateTimeIso(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return _dateTimeFmt.format(d);
}

String formatTrackingNumber(String? trackingNumber) {
  if (trackingNumber == null || trackingNumber.isEmpty) return '—';
  if (trackingNumber.length <= 8) return trackingNumber.toUpperCase();
  return '${trackingNumber.substring(0, 4)}-${trackingNumber.substring(4, 8).toUpperCase()}';
}

const statusLabelMap = <String, String>{
  'pending': 'En attente',
  'free': 'Disponible aux enchères',
  'confirmed': 'Confirmé',
  'picked_up': 'Ramassé',
  'in_transit': 'En transit',
  'arrived': 'Arrivé à destination',
  'out_for_delivery': 'En cours de livraison',
  'delivered': 'Livré',
  'cancelled': 'Annulé',
};

String formatStatusLabel(String? status) {
  if (status == null) return '—';
  return statusLabelMap[status] ?? status;
}
