import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/live_journey.dart';
import '../services/api_service.dart';
import '../screens/parcel/ads/advertisement_detail_screen.dart';

/// Les repères ont pour clé le départ, pas la ligne. Deux « 45 » ne fusionnent
/// donc jamais, même quand ils se trouvent au même arrêt ou vont en sens inverse.
class LiveJourneysMap extends StatefulWidget {
  const LiveJourneysMap(
      {super.key,
      this.advertisementId,
      this.pickupZoneId,
      this.dropoffZoneId,
      this.lineNumber,
      this.load,
      this.mapBuilder});
  final String? advertisementId, pickupZoneId, dropoffZoneId, lineNumber;
  final Future<List<Map<String, dynamic>>> Function(Map<String, dynamic>)? load;
  final WidgetBuilder? mapBuilder;
  @override
  State<LiveJourneysMap> createState() => _LiveJourneysMapState();
}

class _LiveJourneysMapState extends State<LiveJourneysMap>
    with WidgetsBindingObserver {
  final _api = ApiService();
  final _line = TextEditingController();
  Timer? _timer, _debounce;
  GoogleMapController? _map;
  List<LiveJourney> _journeys = [];
  String? _selected, _direction, _error;
  bool _loading = false, _active = true, _centered = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _line.text = widget.lineNumber ?? '';
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_active) return;
      setState(() {
        _journeys = _journeys.where((j) => j.isFresh(DateTime.now())).toList();
      });
      if (!_loading) _reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      ++_generation;
      if (mounted)
        setState(() {
          _journeys = [];
          _loading = false;
        });
    } else
      _reload();
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _debounce?.cancel();
    _line.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final rows = await (widget.load ?? _api.getLiveJourneys)({
        if (widget.advertisementId != null)
          'advertisementId': widget.advertisementId,
        if (widget.pickupZoneId != null) 'pickupZoneId': widget.pickupZoneId,
        if (widget.dropoffZoneId != null) 'dropoffZoneId': widget.dropoffZoneId,
        if (_line.text.trim().isNotEmpty) 'lineNumber': _line.text.trim(),
      });
      if (!mounted || generation != _generation || !_active) return;
      final journeys = rows
          .map(LiveJourney.fromJson)
          .whereType<LiveJourney>()
          .where((j) => j.isFresh(DateTime.now()))
          .toList();
      setState(() {
        _journeys = journeys;
        _error = null;
        _loading = false;
        if (!_journeys.any((j) => j.id == _selected)) _selected = null;
        if (!_journeys.any((j) => j.direction == _direction)) _direction = null;
      });
      _center();
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      debugPrint(
          '[LiveJourneys] Actualisation impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      setState(() {
        _journeys = [];
        _selected = null;
        _loading = false;
        _error = 'Connexion indisponible. Aucune position actuelle vérifiable.';
      });
    }
  }

  void _center() {
    if (_centered || _map == null || _journeys.isEmpty) return;
    _centered = true;
    final p = _journeys.first;
    _map!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 12));
  }

  void _select(LiveJourney j) {
    setState(() => _selected = j.id);
    _map?.animateCamera(
        CameraUpdate.newLatLng(LatLng(j.latitude, j.longitude)));
  }

  @override
  Widget build(BuildContext context) {
    final journeys = _journeys
        .where((j) =>
            j.isFresh(DateTime.now()) &&
            (_direction == null || j.direction == _direction))
        .toList();
    final directions = {
      for (final j in _journeys) j.direction: '${j.from} → ${j.to}'
    };
    final selected = journeys.where((j) => j.id == _selected).firstOrNull;
    return Scaffold(
        appBar: AppBar(title: const Text('Véhicules en direct')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                  controller: _line,
                  decoration: const InputDecoration(
                      labelText: 'Ligne (facultatif)',
                      hintText: 'Ex. 45',
                      prefixIcon: Icon(Icons.directions_bus)),
                  onChanged: (_) {
                    ++_generation;
                    _debounce?.cancel();
                    setState(() {
                      _journeys = [];
                      _loading = false;
                      _centered = false;
                    });
                    _debounce =
                        Timer(const Duration(milliseconds: 400), _reload);
                  })),
          if (directions.isNotEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                    isExpanded: true,
                    value: _direction ?? '',
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Tous les sens')),
                      ...directions.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child:
                              Text(e.value, overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: (v) => setState(() {
                          _direction = v == '' ? null : v;
                          _selected = null;
                        }))),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
              child: Stack(children: [
            Positioned.fill(
                child: widget.mapBuilder?.call(context) ??
                    GoogleMap(
                        initialCameraPosition: const CameraPosition(
                            target: LatLng(14.73, -17.4), zoom: 11),
                        onMapCreated: (controller) {
                          _map = controller;
                          _center();
                        },
                        mapToolbarEnabled: false,
                        markers: journeys
                            .map((j) => Marker(
                                markerId: MarkerId(j.id),
                                position: LatLng(j.latitude, j.longitude),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                    j.id == _selected
                                        ? BitmapDescriptor.hueOrange
                                        : BitmapDescriptor.hueAzure),
                                infoWindow: InfoWindow(
                                    title:
                                        '${j.label} · véhicule ${j.vehicleReference}',
                                    snippet: '${j.from} → ${j.to}'),
                                onTap: () => _select(j)))
                            .toSet(),
                        circles: {
                          if (selected != null)
                            Circle(
                                circleId: const CircleId('accuracy'),
                                center: LatLng(
                                    selected.latitude, selected.longitude),
                                radius: selected.accuracy,
                                strokeWidth: 1,
                                fillColor: Colors.blue.withValues(alpha: .1))
                        })),
            if (journeys.isEmpty)
              Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error ??
                              (_loading
                                  ? 'Recherche de véhicules…'
                                  : 'Aucun véhicule ne partage actuellement une position récente pour cette recherche.'))))),
          ])),
          SizedBox(
              height: 200,
              child: journeys.isEmpty
                  ? const Center(
                      child: Text(
                          'GPS partagé volontairement · positions de moins d’une minute',
                          textAlign: TextAlign.center))
                  : ListView(children: [
                      for (final j in [...journeys]
                        ..sort((a, b) => a.id == _selected
                            ? -1
                            : b.id == _selected
                                ? 1
                                : 0))
                        ListTile(
                            selected: j.id == _selected,
                            leading: const Icon(Icons.directions_bus_outlined),
                            title: Text('${j.label} · ${j.vehicleReference}'),
                            subtitle: Text(
                                '${j.from} → ${j.to}\n${j.driverName} · départ ${_time(j.departureAt)}\nGPS il y a ${DateTime.now().difference(j.capturedAt).inSeconds.clamp(0, 60)} s · précision ±${j.accuracy.round()} m'),
                            isThreeLine: true,
                            onTap: () => _select(j),
                            trailing: IconButton(
                                tooltip: 'Voir ce départ',
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            AdvertisementDetailScreen(
                                                adId: j.id)))))
                    ])),
        ]));
  }

  String _time(DateTime? date) {
    final d = date?.toLocal();
    return d == null
        ? 'à confirmer'
        : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
