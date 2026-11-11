import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_location.dart';
import '../models/parcel.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'live_tracking_map.dart';
import 'pc_components.dart';
import 'transit/data_quality_tag.dart';

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
            DataQualityTag(
              // Suffisant à lui seul : la pastille colorée + le texte d'état
              // transmettent déjà la qualité de la donnée. Un second badge
              // dupliquait le libellé et débordait sur petit écran.
              quality: _offline || _finished
                  ? DataQuality.unavailable
                  : isLive
                      ? DataQuality.live
                      : location != null
                          ? DataQuality.estimated
                          : DataQuality.unavailable,
              label: label,
              freshnessSeconds: isLive ? location.age(_now)?.inSeconds : null,
            ),
            const SizedBox(height: 10),
            _AnomalyBanner(anomalies: _parcel.anomalies),
            _EtaBanner(eta: _parcel.eta, now: _now),
            _ProgressBar(parcel: _parcel, location: location),
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

}

/// Barre de progression Citymapper-style : estimation à vol d'oiseau entre
/// départ et arrivée. Toujours accompagnée de son DataQualityTag pour éviter
/// de laisser croire qu'elle est précise au mètre.
class _ProgressBar extends StatelessWidget {
  final Parcel parcel;
  final DriverLocation? location;
  const _ProgressBar({required this.parcel, required this.location});

  double get _progress {
    final dep = _coord(parcel.departureLatitude, parcel.departureLongitude);
    final arr = _coord(parcel.arrivalLatitude, parcel.arrivalLongitude);
    final drv = location != null && location!.hasCoordinates
        ? _coord(location!.latitude, location!.longitude)
        : null;
    if (dep == null || arr == null || drv == null) return 0;
    final total = _distance(dep, arr);
    if (total == 0) return 0;
    final done = _distance(dep, drv);
    return (done / total).clamp(0, 1).toDouble();
  }

  static (double, double)? _coord(double? lat, double? lng) =>
      lat == null || lng == null ? null : (lat, lng);
  static double _distance((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1, dy = a.$2 - b.$2;
    return dx * dx + dy * dy;
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(
          parcel.departureCity ?? 'Départ',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, letterSpacing: 0.04),
        )),
        Text(
          parcel.arrivalCity ?? 'Arrivée',
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, letterSpacing: 0.04),
        ),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          Container(height: 8, color: AppTheme.backgroundColor),
          FractionallySizedBox(
            widthFactor: p,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.teal500, AppTheme.green500]),
              ),
            ),
          ),
        ]),
      ),
      if (p > 0) Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          p >= 1 ? 'Colis arrivé' : '~ ${(p * 100).round()}% du trajet (estimation à vol d\'oiseau)',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ),
    ]);
  }
}

/// Bannière rouge/orange qui liste les anomalies trajet détectées par le
/// backend. Un seul widget condensé : titre résumé + liste compacte des
/// types. Masqué quand la liste est vide (pas d'anomalie = pas de bruit).
class _AnomalyBanner extends StatelessWidget {
  final List<ParcelAnomaly> anomalies;
  const _AnomalyBanner({required this.anomalies});

  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) return const SizedBox.shrink();
    final hasCritical = anomalies.any(
      (a) => a.severity == AnomalySeverity.critical,
    );
    final color = hasCritical ? Colors.red.shade700 : Colors.orange.shade800;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasCritical ? Icons.error_outline : Icons.warning_amber_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasCritical
                        ? 'Alerte trajet'
                        : 'Vérification trajet recommandée',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    anomalies.map((a) => a.label).join(' · '),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière d'ETA dynamique. Se rend uniquement quand `eta != null` — sinon
/// renvoie un SizedBox.shrink() (le fallback `estimatedDeliveryDate` statique
/// reste visible ailleurs dans la fiche colis). Couleurs selon confidence,
/// mention « à l'arrêt » quand le chauffeur ne bouge plus.
class _EtaBanner extends StatelessWidget {
  final ParcelEta? eta;
  final DateTime now;
  const _EtaBanner({required this.eta, required this.now});

  @override
  Widget build(BuildContext context) {
    final current = eta;
    if (current == null) return const SizedBox.shrink();

    // Préférer arrivalAt absolu à etaMinutes figé côté serveur : si l'écran
    // reste ouvert, le compteur local baisse naturellement.
    final remaining = current.remainingMinutesFrom(now);
    final minDisplay = (current.minMinutes - (current.etaMinutes - remaining))
        .clamp(1, 24 * 60);
    final maxDisplay = (current.maxMinutes - (current.etaMinutes - remaining))
        .clamp(remaining <= 0 ? 1 : remaining, 24 * 60);

    final (bg, fg) = switch (current.confidence) {
      EtaConfidence.high => (AppTheme.green500.withValues(alpha: 0.12), AppTheme.green500),
      EtaConfidence.medium => (AppTheme.teal500.withValues(alpha: 0.12), AppTheme.teal500),
      EtaConfidence.low => (Colors.grey.withValues(alpha: 0.15), AppTheme.textSecondary),
    };

    final mainLabel = remaining <= 0
        ? 'Arrivée imminente'
        : 'Arrive dans ~$remaining min ($minDisplay–$maxDisplay)';

    final tail = switch (current.movingState) {
      EtaMovingState.stopped => ' · Chauffeur à l\'arrêt',
      EtaMovingState.unknown => current.confidence == EtaConfidence.low
          ? ' · Position ancienne'
          : '',
      EtaMovingState.moving => '',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mainLabel,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (tail.isNotEmpty || current.distanceRemainingKm > 0)
                    Text(
                      '~${current.distanceRemainingKm.toStringAsFixed(1)} km restants$tail',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _ParcelLiveTrackingCardState {
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
