import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/nav_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../services/api/experience_api.dart';
import '../../services/api_service.dart';
import '../../models/garage.dart';

List<Map<String, dynamic>> parseShipmentLines(String text) {
  final lines =
      text.split('\n').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
  if (lines.isEmpty || lines.length > 50)
    throw const FormatException('Ajoutez entre 1 et 50 lignes.');
  return List.generate(lines.length, (index) {
    final fields = lines[index].split(';').map((v) => v.trim()).toList();
    final weight = fields.length == 4
        ? double.tryParse(fields[3].replaceAll(',', '.'))
        : null;
    if (fields.length != 4 ||
        fields.take(3).any((v) => v.isEmpty) ||
        weight == null ||
        !weight.isFinite ||
        weight <= 0) {
      throw FormatException(
          'Ligne ${index + 1} : nom ; téléphone ; description ; poids en kg.');
    }
    return {
      'id': const Uuid().v4(),
      'label': fields[0],
      'data': {
        'receiverName': fields[0],
        'receiverPhone': fields[1],
        'description': fields[2],
        'weight': weight
      }
    };
  });
}

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});
  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final _api = ExperienceApi();
  final _text = TextEditingController();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _address = TextEditingController();
  final _contactForm = GlobalKey<FormState>();
  String _contactRequest = const Uuid().v4();
  List<dynamic> _recipients = [];
  Map<String, dynamic>? _data;
  List<Garage> _zones = [];
  List<Map<String, dynamic>> _preview = [];
  String? _departure, _arrival, _error, _notice;
  int _page = 1;
  bool _consent = false, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    for (final c in [_name, _phone, _email, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.request('/workspace?page=$_page');
      final recipients = await _api.request('/recipients');
      final zones = await ApiService().getAllZones();
      if (mounted)
        setState(() {
          _data = data;
          _recipients = recipients['recipients'] as List;
          _zones = zones;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Impossible de charger les outils. Réessayez avec une connexion.');
    }
  }

  Future<void> _act(Future<void> Function() operation, String notice) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await operation();
      if (mounted) setState(() => _notice = notice);
      await _load();
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Opération non confirmée. Votre saisie est conservée ; réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile() async {
    if (_busy) return;
    await _act(() async {
      final picked = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx'],
          withReadStream: true);
      if (picked == null) return;
      final file = picked.files.single;
      final size = file.size;
      if (size > 2 * 1024 * 1024)
        throw const FormatException('Fichier limité à 2 Mo.');
      final stream = file.readStream;
      if (stream == null)
        throw const FormatException(
            'Lecture du fichier impossible. Réessayez.');
      final builder = BytesBuilder();
      await for (final chunk in stream) {
        if (builder.length + chunk.length > 2 * 1024 * 1024)
          throw const FormatException('Fichier limité à 2 Mo.');
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length > 2 * 1024 * 1024)
        throw const FormatException('Fichier limité à 2 Mo.');
      if (mounted) setState(() => _preview = []);
      final result = await _api.importFile(bytes, file.name);
      final errors = result['errors'] as List;
      if (errors.isNotEmpty)
        throw FormatException(errors
            .map((e) => "Ligne ${e['line']} : ${e['message']}")
            .join('\n'));
      if (mounted)
        setState(() => _preview = (result['drafts'] as List)
            .map((v) => Map<String, dynamic>.from(v))
            .toList());
    }, 'Vérifiez l’aperçu avant d’enregistrer les brouillons.');
  }

  Widget _contactField(String label, TextEditingController controller,
          {bool required = false, TextInputType? keyboardType}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: controller == _address
                  ? 500
                  : controller == _phone
                      ? 30
                      : 100,
              decoration: InputDecoration(labelText: label),
              onChanged: (_) => _contactRequest = const Uuid().v4(),
              validator: (v) => required && (v?.trim().length ?? 0) < 2
                  ? 'Complétez ce champ'
                  : null));

  Widget _section(String title, List<Widget> children) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children
          ])));
  String _zone(String id) =>
      _zones.where((z) => z.id == id).firstOrNull?.name ?? 'Zone à vérifier';
  Widget _zoneInput(
          String title, String? value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: title),
          items: _zones
              .map((z) => DropdownMenuItem(
                  value: z.id,
                  child: Text(z.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _busy ? null : onChanged);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Mes outils d’envoi')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton(onPressed: _load, child: const Text('Réessayer'))
                ],
                if (_notice != null)
                  Semantics(liveRegion: true, child: Text(_notice!)),
                if (_data == null && _error == null)
                  const LinearProgressIndicator(),
                _section('Préparer plusieurs colis', [
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _importFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importer un CSV ou Excel')),
                  const Text(
                      'Une feuille, 50 colis maximum. Colonnes : nom, téléphone, description, poids ; adresse et email facultatifs. Fichier limité à 2 Mo.'),
                  const Text(
                      'Jusqu’à 50 lignes. Relisez chaque colis dans le formulaire habituel avant de le publier.'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _text,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 100000,
                      decoration: const InputDecoration(
                          labelText:
                              'Nom ; téléphone ; description ; poids en kg',
                          hintText: 'Awa Diop ; +221770000000 ; Documents ; 1'),
                      onChanged: (_) => setState(() => _preview = [])),
                  OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              try {
                                setState(() {
                                  _preview = parseShipmentLines(_text.text);
                                  _error = null;
                                });
                              } on FormatException catch (e) {
                                setState(() => _error = e.message);
                              }
                            },
                      child: const Text('Vérifier les lignes')),
                  if (_preview.isNotEmpty) ...[
                    for (final d in _preview)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                              '${d['label']} · ${d['data']['receiverPhone']} · ${d['data']['weight']} kg')),
                    FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _act(() async {
                                  await _api.request('/drafts',
                                      method: 'POST',
                                      data: {'drafts': _preview});
                                  if (mounted)
                                    setState(() {
                                      _preview = [];
                                      _text.clear();
                                    });
                                }, 'Brouillons enregistrés.'),
                        child: const Text('Enregistrer les brouillons')),
                  ],
                  if ((_data?['drafts'] as List? ?? []).isNotEmpty)
                    Text(
                        "${(_data!['drafts'] as List).where((d) => d['completedParcelId'] != null).length} / ${(_data!['drafts'] as List).length} colis publiés dans votre liste."),
                  for (final d in (_data?['drafts'] as List? ?? []))
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(d['label'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Wrap(spacing: 8, children: [
                                TextButton(
                                    onPressed: () async {
                                      await context.push(d[
                                                  'completedParcelId'] !=
                                              null
                                          ? '/parcel/${d['completedParcelId']}'
                                          : '/parcel/new?draft=${d['id']}');
                                      await _load();
                                    },
                                    child: Text(d['completedParcelId'] != null
                                        ? 'Publié · Voir le colis'
                                        : 'Compléter')),
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _act(() async {
                                              await _api.request(
                                                  '/drafts/${d['id']}',
                                                  method: 'DELETE');
                                            }, 'Brouillon supprimé.'),
                                    child: const Text('Supprimer'))
                              ])
                            ])),
                ]),
                _section('Mes destinataires', [
                  Form(
                      key: _contactForm,
                      child: Column(children: [
                        _contactField('Nom', _name, required: true),
                        _contactField('Téléphone', _phone,
                            required: true, keyboardType: TextInputType.phone),
                        _contactField('Email (facultatif)', _email,
                            keyboardType: TextInputType.emailAddress),
                        _contactField('Adresse (facultatif)', _address),
                        FilledButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    if (!_contactForm.currentState!.validate())
                                      return;
                                    _act(() async {
                                      await _api.request('/recipients',
                                          method: 'POST',
                                          data: {
                                            'requestId': _contactRequest,
                                            'name': _name.text.trim(),
                                            'phone': _phone.text.trim(),
                                            'email': _email.text.trim(),
                                            'address': _address.text.trim()
                                          });
                                      _contactRequest = const Uuid().v4();
                                      for (final c in [
                                        _name,
                                        _phone,
                                        _email,
                                        _address
                                      ]) {
                                        c.clear();
                                      }
                                    }, 'Destinataire enregistré.');
                                  },
                            child: const Text('Enregistrer le destinataire')),
                      ])),
                  for (final recipient in _recipients)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(recipient['name']),
                        subtitle: Text(recipient['phone']),
                        onTap: () => context
                            .push('/parcel/new?recipient=${recipient['id']}'),
                        trailing: IconButton(
                            tooltip: 'Supprimer le destinataire',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy
                                ? null
                                : () => _act(() async {
                                      await _api.request(
                                          '/recipients/${recipient['id']}',
                                          method: 'DELETE');
                                    }, 'Destinataire supprimé.'))),
                ]),
                _section('Alertes de trajet', [
                  const Text(
                      'Une notification dans l’application pour les nouveaux départs dans le sens choisi, pendant 30 jours.'),
                  const SizedBox(height: 16),
                  _zoneInput('Départ', _departure,
                      (v) => setState(() => _departure = v)),
                  const SizedBox(height: 16),
                  _zoneInput(
                      'Arrivée', _arrival, (v) => setState(() => _arrival = v)),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consent,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _consent = v ?? false),
                      title: const Text(
                          'Je souhaite recevoir ces alertes dans SendProColis.')),
                  FilledButton(
                      onPressed: _busy ||
                              !_consent ||
                              _departure == null ||
                              _arrival == null ||
                              _departure == _arrival
                          ? null
                          : () => _act(() async {
                                await _api.request('/alerts',
                                    method: 'POST',
                                    data: {
                                      'departureZoneId': _departure,
                                      'arrivalZoneId': _arrival,
                                      'consent': true
                                    });
                                if (mounted) setState(() => _consent = false);
                              }, 'Alerte activée pour 30 jours.'),
                      child: const Text('Activer l’alerte')),
                  for (final a in (_data?['alerts'] as List? ?? []))
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(),
                          Text(
                              '${_zone(a['departureZoneId'])} → ${_zone(a['arrivalZoneId'])}'),
                          Text(
                              'Jusqu’au ${a['expiresAt'].toString().split('T').first}'),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _act(() async {
                                        await _api.request('/alerts/${a['id']}',
                                            method: 'DELETE');
                                      }, 'Alerte désactivée.'),
                              child: const Text('Désactiver'))
                        ]),
                ]),
                _section('Historique et reçus', [
                  const Text(
                      'Les reçus apparaissent après confirmation du paiement.'),
                  TextButton(
                      onPressed: () {
                        ref.read(dashboardTabProvider.notifier).state = 1;
                        context.go('/dashboard');
                      },
                      child: const Text('Consulter mes colis')),
                  for (final r in (_data?['receipts'] as List? ?? []))
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${r['parcel']?['trackingNumber'] ?? ''} · ${experienceMoney(r['amount'])}'),
                        subtitle:
                            Text(r['createdAt'].toString().split('T').first),
                        trailing: IconButton(
                            tooltip: 'Partager le reçu',
                            icon: const Icon(Icons.share),
                            onPressed: () => Share.share(receiptText(
                                Map<String, dynamic>.from(r),
                                r['parcel']?['trackingNumber'] ?? '')))),
                  if ((_data?['receipts'] as List? ?? []).isEmpty)
                    const Text('Aucun paiement confirmé sur cette page.'),
                  Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                            onPressed: _page == 1 || _busy
                                ? null
                                : () {
                                    setState(() => _page--);
                                    _load();
                                  },
                            child: const Text('Précédent')),
                        Text('Page $_page'),
                        TextButton(
                            onPressed: _data?['hasMore'] == true && !_busy
                                ? () {
                                    setState(() => _page++);
                                    _load();
                                  }
                                : null,
                            child: const Text('Suivant'))
                      ]),
                ]),
              ])));
}
