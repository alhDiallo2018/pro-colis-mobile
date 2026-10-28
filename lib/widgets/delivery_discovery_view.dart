import 'live_journeys_map.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/driver_discovery.dart';
import '../models/garage.dart';
import '../models/vehicle_type.dart';
import '../services/api_service.dart';
import '../services/location_fix.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import 'garage_picker.dart';
import 'zone_picker_sheet.dart';
import 'location_autocomplete.dart' show PlaceDetails;

/// Recherche centrée sur le retrait : carte et liste partagent le même résultat
/// et la même sélection. Aucune voiture ou durée d'arrivée n'est simulée.
class DeliveryDiscoveryView extends StatefulWidget {
  const DeliveryDiscoveryView(
      {super.key,
      required this.zones,
      required this.initial,
      required this.onChanged,
      this.loadDrivers,
      this.mapBuilder});
  final List<Garage> zones;
  final DeliveryDiscoverySelection initial;
  final ValueChanged<DeliveryDiscoverySelection> onChanged;
  final Future<DriverMapResult> Function(DriverDiscoveryQuery)? loadDrivers;
  @visibleForTesting
  final WidgetBuilder? mapBuilder;
  @override
  State<DeliveryDiscoveryView> createState() => _DeliveryDiscoveryViewState();
}

class _DeliveryDiscoveryViewState extends State<DeliveryDiscoveryView>
    with WidgetsBindingObserver {
  final _api = ApiService();
  final _sheet = DraggableScrollableController();
  GoogleMapController? _map;
  final Map<String, BitmapDescriptor> _vehicleMarkers = {};
  Garage? _pickup, _destination;
  NearbyDriver? _selected;
  String? _vehicleType;
  double? _weight;
  double _radius = 10;
  bool _verified = false, _loading = false, _locating = false, _offers = false;
  bool _listMode = false, _active = true;
  String? _error;
  DriverMapResult? _result;
  int _generation = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _pickup = value.pickup;
    _destination = value.destination;
    _vehicleType = value.vehicleType;
    _weight = value.weight;
    _offers = value.openForOffers;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _search();
        if (widget.mapBuilder == null) _buildVehicleMarkers();
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_active && !_loading && !_offers) _search(background: true);
    });
  }

  /// Petits véhicules dessinés à la résolution native : la catégorie reste
  /// identifiable sans multiplier les grandes épingles et les bulles de texte.
  Future<void> _buildVehicleMarkers() async {
    try {
      final icons = <String, BitmapDescriptor>{};
      for (final type in vehicleTypes.keys) {
        for (final selected in [false, true]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(3);
          final path = Path()
            ..addRRect(RRect.fromRectAndRadius(
                const Rect.fromLTWH(3, 3, 42, 38), const Radius.circular(12)));
          canvas.drawShadow(path, Colors.black.withValues(alpha: .3), 2, true);
          canvas.drawPath(path,
              Paint()..color = selected ? AppTheme.primary : Colors.white);
          final triangle = Path()
            ..moveTo(18, 40)
            ..lineTo(24, 47)
            ..lineTo(30, 40)
            ..close();
          canvas.drawPath(triangle,
              Paint()..color = selected ? AppTheme.primary : Colors.white);
          final icon = _icon(type);
          final painter = TextPainter(
              textDirection: TextDirection.ltr,
              text: TextSpan(
                  text: String.fromCharCode(icon.codePoint),
                  style: TextStyle(
                      fontFamily: icon.fontFamily,
                      package: icon.fontPackage,
                      fontSize: 26,
                      color:
                          selected ? Colors.white : const Color(0xFF173D3A))))
            ..layout();
          painter.paint(canvas, Offset((48 - painter.width) / 2, 8));
          final picture = recorder.endRecording();
          final image = await picture.toImage(144, 150);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null)
            icons['$type:$selected'] = BitmapDescriptor.bytes(
                bytes.buffer.asUint8List(),
                width: 48,
                height: 50);
          image.dispose();
          picture.dispose();
          painter.dispose();
        }
      }
      if (mounted) setState(() => _vehicleMarkers.addAll(icons));
    } catch (error) {
      // Les repères natifs restent utilisables si la génération d'icônes échoue.
      debugPrint('[DriverMap] Icônes indisponibles (${error.runtimeType})');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active)
      _search();
    else {
      // Un résultat revenu en arrière-plan n'autorise pas une sélection périmée.
      _generation++;
      _loading = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _poll?.cancel();
    _map?.dispose();
    _sheet.dispose();
    super.dispose();
  }

  LatLng? _point(Garage? place) {
    final lat = place?.latitude, lng = place?.longitude;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) return null;
    return LatLng(lat, lng);
  }

  List<NearbyDriver> get _drivers =>
      (_result?.drivers ?? []).where((d) => d.isFresh(DateTime.now())).toList();
  void _emit() => widget.onChanged(DeliveryDiscoverySelection(
      pickup: _pickup,
      destination: _destination,
      vehicleType: _vehicleType,
      weight: _weight,
      driver: _offers ? null : _selected?.user,
      openForOffers: _offers));

  Future<void> _search({bool background = false}) async {
    final point = _point(_pickup);
    final generation = ++_generation;
    if (point == null || _offers) {
      setState(() {
        _loading = false;
        _selected = null;
        _result = null;
        _error = null;
      });
      _emit();
      return;
    }
    final selectedId = _selected?.user.id ?? widget.initial.driver?.id;
    setState(() {
      _loading = true;
      _error = null;
      if (!background) {
        _selected = null;
        _result = null;
      }
    });
    if (!background) _emit();
    try {
      final result = await (widget.loadDrivers ?? _api.getDriverDiscovery)(
          DriverDiscoveryQuery(
              latitude: point.latitude,
              longitude: point.longitude,
              radiusKm: _radius,
              vehicleType: _vehicleType,
              minCapacity: _weight,
              verifiedOnly: _verified));
      if (!mounted || generation != _generation || !_active) return;
      final fresh =
          result.drivers.where((d) => d.isFresh(DateTime.now())).toList();
      setState(() {
        _result = result;
        _selected = fresh.where((d) => d.user.id == selectedId).firstOrNull;
        _loading = false;
      });
      _emit();
    } catch (error, stack) {
      debugPrint('[DriverMap] Recherche indisponible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _result = null;
        _selected = null;
        _error =
            'Connexion indisponible. Actualisez pour vérifier les chauffeurs.';
      });
      _emit();
    }
  }

  Future<void> _pickPlace(bool pickup) async {
    final value = await GaragePickerSheet.show(
        context: context,
        garages: widget.zones,
        initial: pickup ? _pickup : _destination,
        exclude: pickup ? _destination : _pickup,
        title: pickup ? 'Où récupérer le colis ?' : 'Où livrer le colis ?');
    if (mounted && value != null) _setPlace(value, pickup);
  }

  void _setPlace(Garage value, bool pickup) {
    setState(() {
      if (pickup) {
        _pickup = value;
        _selected = null;
      } else {
        _destination = value;
      }
    });
    _emit();
    if (pickup) {
      _center();
      _search();
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await resolveCurrentPosition();
      final place = await PlacesService.reverseGeocode(
          position.latitude, position.longitude);
      if (!mounted) return;
      // Le point GPS est confirmé par l'utilisateur : il peut déplacer le repère
      // et préciser l'entrée avant de lancer une recherche autour du retrait.
      final chosen = await ZonePickerSheet.show(
          context: context,
          title: 'Confirmer le point de retrait',
          initialPlace: (place ?? const PlaceDetails()).copyWith(
              exactPoint: true,
              latitude: position.latitude,
              longitude: position.longitude));
      if (mounted && chosen != null) _setPlace(chosen, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error is LocationFailure
                ? error.message
                : 'Position indisponible. Recherchez une adresse ou choisissez sur la carte.')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _mapPoint(LatLng point) async {
    final pickup = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Récupérer le colis ici'),
                  onTap: () => Navigator.pop(ctx, true)),
              ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Livrer le colis ici'),
                  onTap: () => Navigator.pop(ctx, false)),
            ])));
    if (pickup == null || !mounted) return;
    final place =
        await PlacesService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    final chosen = await ZonePickerSheet.show(
        context: context,
        title: pickup ? 'Confirmer le retrait' : 'Confirmer la destination',
        initialPlace: (place ?? const PlaceDetails()).copyWith(
            exactPoint: true,
            latitude: point.latitude,
            longitude: point.longitude));
    if (mounted && chosen != null) _setPlace(chosen, pickup);
  }

  Future<void> _center() async {
    final point = _point(_pickup);
    if (point == null || _map == null) return;
    try {
      await _map!.animateCamera(CameraUpdate.newLatLngZoom(
          point,
          _radius <= 3
              ? 14
              : _radius <= 10
                  ? 12.5
                  : _radius <= 25
                      ? 11.5
                      : 10.5));
    } catch (error) {
      debugPrint('[DriverMap] Recentrage indisponible (${error.runtimeType})');
    }
  }

  void _select(NearbyDriver driver) {
    if (!driver.isFresh(DateTime.now()) || _loading || _error != null) return;
    setState(() => _selected = driver);
    _emit();
    if (_sheet.isAttached)
      _sheet.animateTo(.72,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
  }

  Future<void> _setWeight() async {
    final controller = TextEditingController(text: _weight?.toString() ?? '');
    final value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Quel poids transportez-vous ?'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Poids du colis en kg',
                        helperText: 'Laisser vide pour tous les véhicules')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Appliquer'))
                ]));
    // Le dialogue conserve son contrôleur pendant son animation de fermeture.
    Future.delayed(const Duration(seconds: 1), controller.dispose);
    if (!mounted || value == null) return;
    final weight = double.tryParse(value.replaceAll(',', '.'));
    if (value.trim().isNotEmpty &&
        (weight == null || !weight.isFinite || weight <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indiquez un poids supérieur à zéro.')));
      return;
    }
    setState(() {
      _weight = weight;
      _selected = null;
    });
    _emit();
    _search();
  }

  static IconData _icon(String? type) => switch (type) {
        'motorcycle' => Icons.two_wheeler_rounded,
        'truck' => Icons.local_shipping_rounded,
        'van' => Icons.airport_shuttle_rounded,
        'tricycle' => Icons.electric_rickshaw_rounded,
        'bus' => Icons.directions_bus_rounded,
        'gp' => Icons.flight_takeoff_rounded,
        _ => Icons.apps_rounded,
      };

  Set<Marker> get _markers => {
        if (_point(_pickup) case final point?)
          Marker(
              markerId: const MarkerId('pickup'),
              position: point,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Retrait du colis')),
        if (_point(_destination) case final point?)
          Marker(
              markerId: const MarkerId('destination'),
              position: point,
              infoWindow: const InfoWindow(title: 'Livraison')),
        for (final driver in _drivers)
          Marker(
              markerId: MarkerId(driver.user.id),
              position: LatLng(driver.latitude, driver.longitude),
              zIndexInt: _selected?.user.id == driver.user.id ? 2 : 1,
              icon: _vehicleMarkers[
                      '${driver.user.vehicleType}:${_selected?.user.id == driver.user.id}'] ??
                  BitmapDescriptor.defaultMarkerWithHue(
                      _selected?.user.id == driver.user.id
                          ? BitmapDescriptor.hueOrange
                          : BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(
                  title: driver.user.fullName,
                  snippet:
                      '${vehicleTypeLabel(driver.user.vehicleType)} · position approximative'),
              onTap: () => _select(driver)),
      };

  Widget _mapView() {
    if (widget.mapBuilder != null) return widget.mapBuilder!(context);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
          target: _point(_pickup) ?? const LatLng(14.6928, -17.4467),
          zoom: _pickup == null ? 10 : 12.5),
      onMapCreated: (controller) {
        _map = controller;
      },
      markers: _markers,
      onLongPress: _mapPoint,
      circles: {
        if (_point(_pickup) case final point?)
          Circle(
              circleId: const CircleId('radius'),
              center: point,
              radius: _radius * 1000,
              strokeWidth: 1,
              strokeColor: AppTheme.primary.withValues(alpha: .35),
              fillColor: AppTheme.primary.withValues(alpha: .035)),
        if (_selected case final driver?)
          Circle(
              circleId: const CircleId('accuracy'),
              center: LatLng(driver.latitude, driver.longitude),
              radius: driver.accuracyMeters,
              fillColor: Colors.orange.withValues(alpha: .15),
              strokeColor: Colors.orange,
              strokeWidth: 1),
      },
      padding: const EdgeInsets.only(top: 170, bottom: 160),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
    );
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 470 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final panelOnly = _listMode || compact;
        return Stack(children: [
          if (!panelOnly) Positioned.fill(child: _mapView()),
          if (!panelOnly)
            Positioned(top: 12, left: 14, right: 14, child: _routeCard()),
          if (!panelOnly)
            Positioned(
                top: 160,
                right: 14,
                child: Column(children: [
                  _mapButton(Icons.my_location_rounded,
                      'Recentrer sur le retrait', _center),
                  const SizedBox(height: 8),
                  _mapButton(Icons.list_rounded, 'Voir la liste',
                      () => setState(() => _listMode = true)),
                ])),
          if (panelOnly)
            Positioned.fill(
                child: Material(
                    color: AppTheme.cardColor,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      _routeCard(),
                      const SizedBox(height: 12),
                      if (!compact)
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _listMode = false),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Voir la carte'))),
                      ..._panelContent(),
                    ])))
          else
            DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: .43,
                minChildSize: .32,
                maxChildSize: .78,
                snap: true,
                snapSizes: const [.43, .78],
                builder: (context, controller) => Material(
                    elevation: 12,
                    color: AppTheme.cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(26)),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                        children: [
                          Center(
                              child: Container(
                                  width: 38,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                      color: AppTheme.slate300,
                                      borderRadius: BorderRadius.circular(8)))),
                          ..._panelContent(),
                        ]))),
        ]);
      });

  Widget _mapButton(IconData icon, String label, VoidCallback onTap) =>
      Material(
          elevation: 2,
          color: AppTheme.cardColor,
          shape: const CircleBorder(),
          child: IconButton(
              onPressed: onTap,
              tooltip: label,
              icon: Icon(icon, color: AppTheme.textPrimary)));

  Widget _routeCard() => Material(
      elevation: 3,
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _routeRow(true, _pickup?.name ?? 'Où récupérer le colis ?'),
        Padding(
            padding: const EdgeInsets.only(left: 48, right: 16),
            child: Divider(height: 1, color: AppTheme.slate200)),
        _routeRow(false, _destination?.name ?? 'Où le livrer ?'),
      ]));
  Widget _routeRow(bool pickup, String title) => ListTile(
      dense: true,
      minVerticalPadding: 10,
      leading: Icon(pickup ? Icons.trip_origin_rounded : Icons.flag_rounded,
          color: pickup ? AppTheme.primary : AppTheme.textPrimary, size: 22),
      title: Text(pickup ? 'RETRAIT' : 'DESTINATION',
          style: TextStyle(
              fontSize: 9, letterSpacing: 1.2, color: AppTheme.textSecondary)),
      subtitle: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
      onTap: () => _pickPlace(pickup),
      trailing: pickup
          ? IconButton(
              onPressed: _locating ? null : _locate,
              tooltip: 'Utiliser ma position pour le retrait',
              icon: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 20))
          : const Icon(Icons.chevron_right_rounded, size: 20));

  List<Widget> _panelContent() => [
        Row(children: [
          Expanded(
              child: Text(
                  _offers
                      ? 'Recevez des offres'
                      : 'Un véhicule pour votre colis',
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.4))),
          if (!_offers)
            IconButton(
                onPressed: _loading ? null : _search,
                tooltip: 'Actualiser la disponibilité',
                icon: const Icon(Icons.refresh_rounded))
        ]),
        Text(
            _offers
                ? 'Les chauffeurs pourront répondre à votre annonce.'
                : _point(_pickup) == null
                    ? 'Choisissez le retrait pour trouver les chauffeurs autour.'
                    : 'Disponibles à moins de ${_radius.toInt()} km du retrait',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),
        if (!_offers) ...[
          SizedBox(
              height: 96 +
                  math.max(0, MediaQuery.textScalerOf(context).scale(1) - 1) *
                      70,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: vehicleTypes.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = index == 0
                        ? null
                        : vehicleTypes.keys.elementAt(index - 1);
                    final selected = type == _vehicleType;
                    final count = _result == null
                        ? null
                        : type == null
                            ? _result!.counts.values
                                .fold<int>(0, (a, b) => a + b)
                            : _result!.counts[type] ?? 0;
                    final label = type == null
                        ? 'Tous'
                        : type == 'motorcycle'
                            ? 'Moto'
                            : type == 'bus'
                                ? 'Bus'
                                : vehicleTypes[type]!;
                    return Semantics(
                        selected: selected,
                        button: true,
                        label:
                            '$label, ${count == null ? 'disponibilité à vérifier' : '$count disponibles'}',
                        child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _vehicleType = type;
                                _selected = null;
                              });
                              _emit();
                              _search();
                            },
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 106 *
                                    math.max(
                                        1,
                                        MediaQuery.textScalerOf(context)
                                            .scale(1)),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.primary
                                        : AppTheme.slate100,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_icon(type),
                                          size: 27,
                                          color: selected
                                              ? Colors.white
                                              : AppTheme.textPrimary),
                                      const SizedBox(height: 5),
                                      Text(label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? Colors.white
                                                  : AppTheme.textPrimary)),
                                      Text(
                                          count == null
                                              ? '—'
                                              : '$count disponibles',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: selected
                                                  ? Colors.white70
                                                  : AppTheme.textSecondary)),
                                    ]))));
                  })),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            ActionChip(
                avatar: const Icon(Icons.scale_outlined, size: 16),
                label: Text(_weight == null
                    ? 'Poids du colis'
                    : '${_weight! % 1 == 0 ? _weight!.toInt() : _weight} kg'),
                onPressed: _setWeight),
            PopupMenuButton<double>(
                tooltip: 'Rayon de recherche',
                initialValue: _radius,
                onSelected: (value) {
                  setState(() {
                    _radius = value;
                    _selected = null;
                  });
                  _center();
                  _search();
                },
                itemBuilder: (_) => [3.0, 10.0, 25.0, 50.0, 100.0]
                    .map((r) => PopupMenuItem(
                        value: r,
                        child: Text('Dans un rayon de ${r.toInt()} km')))
                    .toList(),
                child: Chip(
                    avatar: const Icon(Icons.radar_rounded, size: 16),
                    label: Text('${_radius.toInt()} km ▾'))),
            FilterChip(
                label: const Text('Vérifiés'),
                selected: _verified,
                onSelected: (value) {
                  setState(() => _verified = value);
                  _search();
                }),
          ]),
          if (_loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(minHeight: 3)),
          if (_error != null)
            _notice(Icons.wifi_off_rounded, _error!,
                action: 'Réessayer', onTap: _search)
          else if (!_loading && _point(_pickup) != null && _drivers.isEmpty)
            _notice(Icons.travel_explore,
                'Aucun chauffeur disponible ici pour ce besoin.',
                action: _radius < 100
                    ? 'Élargir à ${math.min(100, _radius < 25 ? 25 : _radius * 2).toInt()} km'
                    : 'Voir tous les véhicules', onTap: () {
              setState(() {
                if (_radius < 100)
                  _radius =
                      math.min(100, _radius < 25 ? 25 : _radius * 2).toDouble();
                else {
                  _vehicleType = null;
                  _weight = null;
                  _verified = false;
                }
              });
              _center();
              _search();
            }),
          if (_selected case final selected?) ...[
            _selectedCard(selected),
            const SizedBox(height: 8),
          ],
          for (final driver
              in _drivers.where((d) => d.user.id != _selected?.user.id))
            Material(color: Colors.transparent, child: _driverRow(driver)),
          if (_drivers.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                    'Positions approximatives · distances à vol d’oiseau. La prise en charge et le prix seront confirmés avec le chauffeur.',
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppTheme.textSecondary))),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LiveJourneysMap())),
            icon: const Icon(Icons.gps_fixed),
            label: const Text('Navettes et véhicules en direct')),
        TextButton.icon(
            onPressed: () => context.push('/advertisements'),
            icon: const Icon(Icons.route_outlined),
            label: const Text('Voyages, GP et navettes annoncés')),
        TextButton.icon(
            onPressed: () {
              setState(() {
                _offers = !_offers;
                _selected = null;
              });
              _emit();
              _search();
            },
            icon: Icon(
                _offers ? Icons.near_me_outlined : Icons.campaign_outlined,
                size: 18),
            label: Text(_offers
                ? 'Choisir un chauffeur sur la carte'
                : 'Préférer une annonce ouverte aux chauffeurs')),
        if (!_offers && _point(_pickup) != null)
          Text('Appui long sur la carte pour préciser un lieu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ];

  Widget _notice(IconData icon, String text,
          {required String action, required VoidCallback onTap}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Icon(icon, size: 30, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            TextButton(onPressed: onTap, child: Text(action)),
          ]));
  Widget _driverRow(NearbyDriver driver) {
    final user = driver.user;
    return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            backgroundColor: AppTheme.slate100,
            child: Icon(_icon(user.vehicleType), color: AppTheme.primary)),
        title: Row(children: [
          Expanded(
              child: Text(user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700))),
          if (user.isVerified)
            Icon(Icons.verified_rounded, size: 16, color: AppTheme.primary)
        ]),
        subtitle: Text(
            '${vehicleTypeLabel(user.vehicleType)} · ${(user.vehicleCapacity ?? 0) > 0 ? '${user.vehicleCapacity} kg max.' : 'Capacité à confirmer'}',
            maxLines: 2,
            style: const TextStyle(fontSize: 11)),
        trailing:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
              user.distanceKm == null
                  ? '—'
                  : '≈ ${user.distanceKm!.toStringAsFixed(1)} km',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
          if ((user.rating ?? 0) > 0)
            Text('★ ${user.rating!.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 11)),
        ]),
        onTap: () => _select(driver));
  }

  Widget _selectedCard(NearbyDriver driver) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: .07),
          border: Border.all(color: AppTheme.primary),
          borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle, color: AppTheme.primary, size: 18),
          const SizedBox(width: 6),
          const Text('Votre chauffeur',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
              tooltip: 'Retirer ce chauffeur',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() => _selected = null);
                _emit();
              })
        ]),
        Material(color: Colors.transparent, child: _driverRow(driver)),
        Text(
            'Position actualisée il y a ${math.max(0, DateTime.now().difference(driver.updatedAt).inMinutes)} min.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        const Text('Continuez pour décrire votre colis et proposer votre prix.',
            style: TextStyle(fontSize: 12)),
      ]));
}
