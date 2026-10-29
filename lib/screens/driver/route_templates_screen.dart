import 'route_import_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../models/route_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/advertisement_provider.dart';
import '../../services/api_service.dart';
import '../../services/route_schedule_store.dart';

class RouteTemplatesScreen extends ConsumerStatefulWidget {
  const RouteTemplatesScreen({super.key, this.sourceAdvertisementId});
  final String? sourceAdvertisementId;
  @override
  ConsumerState<RouteTemplatesScreen> createState() =>
      _RouteTemplatesScreenState();
}

class _RouteTemplatesScreenState extends ConsumerState<RouteTemplatesScreen> {
  final _api = ApiService();
  late final RouteScheduleStore _store;
  List<Map<String, dynamic>> _templates = [], _recent = [];
  Map<String, dynamic>? _pending;
  bool _loading = true, _created = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _store = RouteScheduleStore(ref.read(authProvider).user?.id ?? '');
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    setState(() => _loading = true);
    try {
      final pending = await _store.load();
      Map<String, dynamic>? imported;
      if (initial && widget.sourceAdvertisementId != null && pending == null)
        imported = await _api.rememberRoute(widget.sourceAdvertisementId!);
      final templates = await _api.getRouteTemplates();
      final recent = await _api.getMyAdvertisements();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _recent =
            recent.where((ad) => ad['itinerary'] is Map).take(30).toList();
        _pending = pending;
        _error = null;
        _loading = false;
      });
      if (imported != null) _schedule(imported, false);
    } catch (error, stack) {
      debugPrint('[Routes] Chargement impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() {
          _error =
              'Impossible de charger les trajets. Vérifiez la connexion et réessayez.';
          _loading = false;
        });
    }
  }

  Future<void> _schedule(Map<String, dynamic> template, bool multiple,
      {Map<String, dynamic>? pending}) async {
    if (_pending != null && pending == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Vérifiez d’abord la publication en attente pour éviter un doublon.')));
      return;
    }
    final count = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => RouteScheduleSheet(
            template: template,
            store: _store,
            multiple: multiple,
            pending: pending));
    if (!mounted) return;
    if (count != null) {
      _created = true;
      await ref.read(advertisementProvider.notifier).loadMyAdvertisements();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '$count départ${count > 1 ? 's' : ''} publié${count > 1 ? 's' : ''}.')));
    }
    if (mounted) _load();
  }

  Future<void> _reuse(Map<String, dynamic> ad) async {
    try {
      final template = await _api.rememberRoute(ad['id'].toString());
      if (mounted) await _schedule(template, false);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Impossible de reprendre ce trajet. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _created);
      },
      child: Scaffold(
          appBar: AppBar(
              title: const Text('Mes trajets habituels'),
              leading:
                  BackButton(onPressed: () => Navigator.pop(context, _created)),
              actions: [
                IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _loading ? null : () => _load(),
                    icon: const Icon(Icons.refresh))
              ]),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    const Text('Les arrêts sont déjà prêts.',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text(
                        'Choisissez votre trajet, puis l’horaire. Pour plusieurs rotations, préparez tous les départs en une seule fois.'),
                    if (_error != null)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_error!))),
                    if (_pending != null)
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.sync_problem),
                              title: const Text('Publication à vérifier'),
                              subtitle: const Text(
                                  'La réponse précédente n’a pas été confirmée. Reprenez la même demande sans créer de doublons.'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _schedule(
                                  Map<String, dynamic>.from(
                                      _pending!['template']),
                                  false,
                                  pending: Map<String, dynamic>.from(
                                      _pending!['payload'])))),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final imported = await showModalBottomSheet<bool>(
                          context: context, isScrollControlled: true, useSafeArea: true,
                          isDismissible: false, enableDrag: false,
                          builder: (_) => const RouteImportSheet());
                        if (imported == true && mounted) await _load();
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importer des itinéraires CSV'),
                    ),
                    if (_templates.isEmpty && _error == null)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                              'Vos nouveaux trajets sont mémorisés automatiquement. Vous pouvez aussi reprendre un voyage ci-dessous.')),
                    for (final template in _templates) _card(template),
                    if (_recent.isNotEmpty)
                      ExpansionTile(
                          title: const Text('Reprendre un voyage existant'),
                          children: [
                            for (final ad in _recent)
                              ListTile(
                                  leading: const Icon(Icons.history),
                                  title: Text(
                                      '${ad['departureName'] ?? ad['departureCity'] ?? 'Départ'} → ${ad['arrivalName'] ?? ad['arrivalCity'] ?? 'Arrivée'}'),
                                  subtitle: Text(ad['itinerary']
                                              ?['lineNumber'] ==
                                          null
                                      ? 'Réutiliser les arrêts et les durées'
                                      : 'Ligne ${ad['itinerary']['lineNumber']}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _reuse(ad))
                          ]),
                  ]))));
  Widget _card(Map<String, dynamic> template) {
    final data = Map<String, dynamic>.from(template['data']);
    final route = Map<String, dynamic>.from(data['itinerary']);
    final stops = route['stops'] as List;
    return Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(template['name'].toString(),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  '${stops.length} arrêts · ${stops.last['offsetMinutes']} min · ${data['availableWeight']} kg disponibles par défaut'),
              const SizedBox(height: 6),
              Text(stops.map((s) => s['name']).join(' → '),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                    onPressed: () => _schedule(template, false),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau départ')),
                OutlinedButton.icon(
                    onPressed: () => _schedule(template, true),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Plusieurs départs')),
              ]),
            ])));
  }
}

class RouteScheduleSheet extends StatefulWidget {
  const RouteScheduleSheet(
      {required this.template,
      required this.store,
      required this.multiple,
      this.pending,
      this.publish});
  final Map<String, dynamic> template;
  final RouteScheduleStore store;
  final bool multiple;
  final Map<String, dynamic>? pending;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
      publish;
  @override
  State<RouteScheduleSheet> createState() => RouteScheduleSheetState();
}

class RouteScheduleSheetState extends State<RouteScheduleSheet> {
  final _api = ApiService();
  final _count = TextEditingController(),
      _interval = TextEditingController(),
      _weight = TextEditingController();
  late DateTime _first;
  late bool _multiple;
  bool _reverse = false, _alternate = false, _busy = false, _all = false;
  String? _error;
  Map<String, dynamic>? _pending;
  Map<String, dynamic> get data =>
      Map<String, dynamic>.from(widget.template['data']);
  List get stops => data['itinerary']['stops'] as List;
  int get duration => (stops.last['offsetMinutes'] as num).toInt();
  bool get locked => _busy || _pending != null;
  @override
  void initState() {
    super.initState();
    _multiple = widget.multiple;
    _first = DateTime.now().add(const Duration(minutes: 15));
    _first = DateTime(_first.year, _first.month, _first.day, _first.hour,
        ((_first.minute + 4) ~/ 5) * 5);
    _count.text = _multiple ? '2' : '1';
    _interval.text = duration.toString();
    _weight.text = '${data['availableWeight']}';
    _pending = widget.pending;
    if (_pending != null) {
      final list = (_pending!['departures'] as List).cast<Map>();
      if (list.isNotEmpty) {
        _first = DateTime.parse(list.first['departureAt']).toLocal();
        _multiple = list.length > 1;
        _count.text = '${list.length}';
        _reverse = list.first['reverse'] == true;
        if (list.length > 1) {
          _interval.text =
              '${DateTime.parse(list[1]['departureAt']).difference(DateTime.parse(list.first['departureAt'])).inMinutes}';
          _alternate = list[1]['reverse'] != list.first['reverse'];
        }
      }
      _weight.text = '${_pending!['availableWeight']}';
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _interval.dispose();
    _weight.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get departures => _pending != null
      ? (_pending!['departures'] as List)
          .map((d) => Map<String, dynamic>.from(d))
          .toList()
      : buildRouteDepartures(
          first: _first,
          count: _multiple ? (int.tryParse(_count.text) ?? 0) : 1,
          intervalMinutes: int.tryParse(_interval.text) ?? 0,
          durationMinutes: duration,
          reverseFirst: _reverse,
          alternate: _multiple && _alternate);
  Future<void> _date() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: _first,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_first));
    if (t != null && mounted)
      setState(
          () => _first = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_pending == null) {
        final list = departures;
        final weight = double.tryParse(_weight.text.replaceAll(',', '.'));
        if (!_first.isAfter(DateTime.now()))
          throw const FormatException('Choisissez un horaire futur.');
        if (weight == null || !weight.isFinite || weight <= 0)
          throw const FormatException(
              'Indiquez une capacité disponible positive.');
        final payload = <String, dynamic>{
          'requestId': const Uuid().v4(),
          'departures': list,
          'availableWeight': weight,
          // Le prix sera négocié pour chaque colis ; les reprises utilisent
          // toujours leur requête déjà mémorisée, sans en modifier le contenu.
          'proposedPrice': null
        };
        // Écriture durable AVANT le premier envoi. Toute reprise conserve le
        // même identifiant et le même planning jusqu’au résultat définitif.
        await widget.store
            .save({'template': widget.template, 'payload': payload});
        _pending = payload;
      }
      final result = await (widget.publish ?? _api.scheduleRouteDepartures)(
          widget.template['id'].toString(), _pending!);
      await widget.store.clear();
      if (mounted) Navigator.pop(context, (result['count'] as num).toInt());
    } catch (error, stack) {
      debugPrint(
          '[RouteSchedule] Publication non confirmée (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      final code = error is ApiException
          ? error.statusCode
          : error is DioException
              ? error.response?.statusCode
              : null;
      if ([400, 401, 403, 404, 409, 422].contains(code)) {
        await widget.store.clear();
        _pending = null;
      }
      if (mounted)
        setState(() => _error = error is FormatException
            ? error.message
            : error is ApiException
                ? error.message
                : _pending != null
                    ? 'La réponse n’a pas été confirmée. Réessayez cette demande ; aucun départ ne sera créé en double.'
                    : 'Publication impossible. Vérifiez la connexion et réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> preview = [];
    String? invalid;
    try {
      preview = departures;
    } on FormatException catch (e) {
      invalid = e.message;
    }
    final shown = _all ? preview : preview.take(6).toList();
    return PopScope(
        canPop: !_busy,
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .88,
                child: Column(children: [
                  ListTile(
                      title: Text(_pending != null
                          ? 'Vérifier la publication'
                          : _multiple
                              ? 'Planifier les départs'
                              : 'Nouveau départ'),
                      subtitle: Text(widget.template['name'].toString()),
                      trailing: IconButton(
                          onPressed:
                              _busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close))),
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                        Text(
                            '${stops.length} arrêts et ${duration} minutes repris du trajet habituel.',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (_pending == null) ...[
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.schedule),
                              title: const Text('Premier départ'),
                              subtitle: Text(_when(_first)),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: locked ? null : _date),
                          SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Sens retour'),
                              subtitle: Text(_reverse
                                  ? '${stops.last['name']} → ${stops.first['name']}'
                                  : '${stops.first['name']} → ${stops.last['name']}'),
                              value: _reverse,
                              onChanged: locked
                                  ? null
                                  : (v) => setState(() => _reverse = v)),
                          SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Créer plusieurs départs'),
                              value: _multiple,
                              onChanged: locked
                                  ? null
                                  : (v) => setState(() {
                                        _multiple = v;
                                        if (v &&
                                            (int.tryParse(_count.text) ?? 0) <
                                                2) _count.text = '2';
                                      })),
                          if (_multiple) ...[
                            TextField(
                                controller: _count,
                                enabled: !locked,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Nombre de départs (1 à 100)'),
                                onChanged: (_) => setState(() {})),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _interval,
                                enabled: !locked,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText:
                                        'Intervalle entre départs (minutes)',
                                    helperText:
                                        'Au moins $duration min pour ce véhicule'),
                                onChanged: (_) => setState(() {})),
                            SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Alterner aller et retour'),
                                value: _alternate,
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() => _alternate = v)),
                          ],
                          if (_multiple && !_alternate)
                            const Text(
                                'Prévoyez aussi le temps de retour et de pause dans l’intervalle lorsque tous les départs sont dans le même sens.',
                                style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _weight,
                              enabled: !locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                  labelText:
                                      'Capacité disponible par départ (kg)')),
                          const SizedBox(height: 12),
                          const Text(
                              'Prix à négocier après réception de l’offre et des détails du colis.'),
                        ],
                        const SizedBox(height: 18),
                        Text('Récapitulatif · ${preview.length} départs',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        if (preview.isNotEmpty)
                          Text(
                              'Dernier départ : ${_when(DateTime.parse(preview.last['departureAt']))}'),
                        if (invalid != null)
                          Text(invalid,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        for (final d in shown)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Icon(d['reverse'] == true
                                  ? Icons.west
                                  : Icons.east),
                              title:
                                  Text(_when(DateTime.parse(d['departureAt']))),
                              subtitle: Text(d['reverse'] == true
                                  ? '${stops.last['name']} → ${stops.first['name']}'
                                  : '${stops.first['name']} → ${stops.last['name']}')),
                        if (preview.length > 6)
                          TextButton(
                              onPressed: () => setState(() => _all = !_all),
                              child: Text(_all
                                  ? 'Réduire'
                                  : 'Voir les ${preview.length} départs')),
                        if (_pending != null)
                          const Text(
                              'Cette demande est conservée sur ce téléphone jusqu’à confirmation. Les horaires restent identiques lors d’un nouvel essai.'),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 12),
                        const Text(
                            'Chaque départ aura ses propres offres et réservations. Le GPS ne s’active que lorsque vous démarrez son suivi.'),
                        const SizedBox(height: 20),
                      ])),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed:
                                      _busy || invalid != null ? null : _submit,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.check),
                                  label: Text(_busy
                                      ? 'Publication…'
                                      : _pending != null
                                          ? 'Vérifier / réessayer'
                                          : 'Publier ${preview.length} départ${preview.length > 1 ? 's' : ''}')))))
                ]))));
  }
}
