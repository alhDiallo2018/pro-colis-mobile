import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_location.dart';
import '../models/parcel.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'live_tracking_map.dart';
import 'pc_components.dart';

const kParcelTrackingRefreshInterval = Duration(seconds: 5);

/// Même carte dans la fiche client et la recherche de suivi. Un seul appel en
/// vol ; les erreurs gardent la dernière mesure avec son vrai horodatage.
class ParcelLiveTrackingCard extends StatefulWidget {
  const ParcelLiveTrackingCard(
      {super.key,
      required this.parcel,
      this.fetchImmediately = true,
      this.load,
      this.onUpdated,
      this.mapBuilder,
      this.now});
  final Parcel parcel;
  final bool fetchImmediately;
  final Future<Parcel> Function(String trackingNumber)? load;
  final ValueChanged<Parcel>? onUpdated;
  final Widget Function(Parcel parcel, DriverLocation? location)? mapBuilder;
  final DateTime Function()? now;
  @override
  State<ParcelLiveTrackingCard> createState() => _ParcelLiveTrackingCardState();
}

class _ParcelLiveTrackingCardState extends State<ParcelLiveTrackingCard> {
  late Parcel _parcel;
  Timer? _timer;
  int _generation = 0;
  int? _loadingGeneration;
  bool _offline = false;
  final _api = ApiService();
  bool get _finished => _parcel.isFinished;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _parcel = widget.parcel;
    _syncTimer();
    if (widget.fetchImmediately && !_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ParcelLiveTrackingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parcel.trackingNumber != widget.parcel.trackingNumber) {
      _generation++;
      _parcel = widget.parcel;
      _offline = false;
      _syncTimer();
      unawaited(_refresh());
    } else if (oldWidget.parcel.status != widget.parcel.status) {
      _generation++;
      // Le détail authentifié ne contient pas forcément de GPS : conserver la
      // dernière mesure locale sans réinitialiser le statut métier reçu.
      _parcel = widget.parcel.copyWith(driverLocation: _parcel.driverLocation);
      _syncTimer();
    }
  }

  void _syncTimer() {
    if (_finished) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(kParcelTrackingRefreshInterval, (_) {
        // La fraîcheur diminue même si un appel réseau est encore en attente.
        if (mounted) setState(() {});
        unawaited(_refresh());
      });
    }
  }

  Future<void> _refresh() async {
    final generation = _generation;
    if (!mounted || _finished || _loadingGeneration == generation) return;
    _loadingGeneration = generation;
    try {
      final parcel = widget.load == null
          ? await _api.trackParcelPosition(_parcel)
          : await widget.load!(_parcel.trackingNumber);
      if (!mounted || generation != _generation) return;
      setState(() {
        _parcel = parcel;
        _offline = false;
      });
      _syncTimer();
      widget.onUpdated?.call(parcel);
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      debugPrint(
          '[ParcelGPS] Actualisation indisponible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      setState(() => _offline = true);
    } finally {
      if (_loadingGeneration == generation) _loadingGeneration = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _parcel.isBeingTransported &&
            _parcel.driverLocation?.hasCoordinates == true
        ? _parcel.driverLocation
        : null;
    final isLive = location != null && !location.isStale(_now) && !_offline;
    final arrived = _parcel.status == ParcelStatus.arrived ||
        _parcel.status == ParcelStatus.delivered;
    final label = _offline
        ? 'Connexion interrompue'
        : arrived
            ? 'Colis arrivé'
            : isLive
                ? 'En direct'
                : location != null
                    ? 'Dernière position connue'
                    : 'En attente du GPS';
    final description = _finished
        ? 'Le transport est terminé. Le partage GPS de ce colis est arrêté.'
        : _offline
            ? 'Nouvelle tentative automatique. La dernière position reste horodatée.'
            : location != null
                ? _age(location)
                : _parcel.isBeingTransported
                    ? 'En attente de la position du téléphone du chauffeur.'
                    : 'La position du colis apparaîtra dès sa prise en charge et son départ.';
    return PcCard(
      key: const ValueKey('parcel-gps-card'),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Position GPS du colis',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: _finished ? null : _refresh,
                  tooltip: 'Actualiser la position GPS',
                  icon: const Icon(Icons.refresh_rounded)),
            ]),
            const SizedBox(height: 8),
            Wrap(children: [
              PcBadge(label,
                  tone: _offline || !isLive ? PcTone.amber : PcTone.green)
            ]),
            const SizedBox(height: 8),
            Text(description,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
                height: 240,
                child: widget.mapBuilder?.call(_parcel, location) ??
                    LiveTrackingMap(
                      departureLatitude: _parcel.departureLatitude,
                      departureLongitude: _parcel.departureLongitude,
                      arrivalLatitude: _parcel.arrivalLatitude,
                      arrivalLongitude: _parcel.arrivalLongitude,
                      driverLatitude: location?.latitude,
                      driverLongitude: location?.longitude,
                      driverAccuracy: location?.accuracy,
                      departureLabel: _parcel.departureZoneName,
                      arrivalLabel:
                          _parcel.arrivalZoneName ?? _parcel.arrivalCity,
                    )),
            if (location != null) ...[
              const SizedBox(height: 12),
              Text(
                  'GPS : ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              if (location.accuracy?.isFinite == true &&
                  location.accuracy! >= 0)
                Text('Précision : ± ${location.accuracy!.round()} m',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': '${location.latitude},${location.longitude}'
                    });
                    try {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } catch (error) {
                      debugPrint(
                          '[ParcelGPS] Carte externe indisponible (${error.runtimeType})');
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir cette position dans Maps')),
            ],
          ]),
    );
  }

  String _age(DriverLocation location) {
    final age = location.age(_now);
    if (age == null) return 'Heure de mesure inconnue · position non confirmée';
    if (age.isNegative && age < const Duration(seconds: -5))
      return 'Horodatage GPS non confirmé';
    if (age.inSeconds < 60)
      return 'Position mise à jour à l’instant · actualisation automatique';
    if (age.inMinutes < 60) return 'Position reçue il y a ${age.inMinutes} min';
    return 'Position reçue il y a ${age.inHours} h';
  }
}
