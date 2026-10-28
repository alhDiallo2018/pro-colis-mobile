import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../services/api/experience_api.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ParcelExperienceCard extends StatefulWidget {
  const ParcelExperienceCard({super.key, required this.parcelId, this.api});
  final String parcelId;
  final ExperienceApi? api;
  @override
  State<ParcelExperienceCard> createState() => _ParcelExperienceCardState();
}

class _ParcelExperienceCardState extends State<ParcelExperienceCard> {
  late final ExperienceApi _api = widget.api ?? ExperienceApi();
  Map<String, dynamic>? _value;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ParcelExperienceCard old) {
    super.didUpdateWidget(old);
    if (old.parcelId != widget.parcelId) {
      _value = null;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.parcelId;
    try {
      final value = await _api.parcel(id);
      if (mounted && widget.parcelId == id)
        setState(() {
          _value = value;
          _error = null;
        });
    } catch (_) {
      if (mounted && widget.parcelId == id)
        setState(() => _error =
            'Récapitulatif indisponible. Réessayez avec une connexion.');
    }
  }

  Widget _row(String label, dynamic amount) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(label),
            Text(experienceMoney(amount),
                style: const TextStyle(fontWeight: FontWeight.w700))
          ]));
  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value == null)
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: _error == null
                  ? const LinearProgressIndicator()
                  : Column(children: [
                      Text(_error!),
                      TextButton(
                          onPressed: _load, child: const Text('Réessayer'))
                    ])));
    final next = value['nextAction'] as Map;
    final finance = value['finance'] as Map;
    final tracking = value['tracking'] as Map;
    final timestamp =
        DateTime.tryParse(tracking['lastPositionAt']?.toString() ?? '')
            ?.toLocal();
    // On recalcule la fraîcheur à l'affichage : une réponse chargée auparavant
    // ne peut pas faire passer une ancienne position pour du direct.
    final age = timestamp == null ? null : DateTime.now().difference(timestamp);
    final fresh = tracking['positionFresh'] == true &&
        age != null &&
        !age.isNegative &&
        age.inSeconds <= 120;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(next['title'],
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(next['description']),
                  if (tracking['overdue'] == true)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                            'L’heure estimée de livraison est dépassée. Contactez le chauffeur pour une mise à jour.')),
                  if (timestamp != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'Dernière position : $timestamp. ${fresh ? 'Position récente.' : 'Position ancienne, le véhicule peut avoir bougé.'}')),
                  const Divider(height: 28),
                  Text('Récapitulatif financier',
                      style: Theme.of(context).textTheme.titleMedium),
                  _row('Prix convenu', finance['agreedPrice']),
                  _row('Paiements confirmés', finance['collected']),
                  if (finance.containsKey('commission')) ...[
                    _row(
                        'Commission ${finance['commissionEstimated'] == true ? '(estimation)' : '(enregistrée)'}',
                        finance['commission']),
                    _row(
                        'Net après commission ${finance['commissionEstimated'] == true ? '(estimé)' : ''}',
                        finance['netAfterCommission']),
                    _row('Commission réglée', finance['paidCommission']),
                    _row('Dette créée sur ce colis', finance['debtCreated']),
                    _row('Dette actuelle du compte',
                        finance['accountCommissionDebt']),
                  ],
                  if (finance.containsKey('parcelPenaltyDue'))
                    _row('Pénalités restant à régler',
                        finance['parcelPenaltyDue']),
                  for (final receipt in value['receipts'] as List)
                    TextButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () => Share.share(receiptText(
                            Map<String, dynamic>.from(receipt),
                            value['trackingNumber'])),
                        label: Text(
                            'Partager le reçu de ${experienceMoney(receipt['amount'])}')),
                  const Divider(height: 28),
                  for (final ticket in value['complaints'] as List)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextButton(
                            onPressed: () =>
                                context.push('/support?ticket=${ticket['id']}'),
                            child: Text(
                                '${ticket['subject']} — ${complaintStatus(ticket['status'])}\nSuivre cette réclamation'))),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.support_agent),
                      onPressed: () async {
                        final sent = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => ParcelComplaintScreen(
                                    parcelId: widget.parcelId, api: _api)));
                        if (sent == true) await _load();
                      },
                      label: const Text('Signaler un problème')),
                  TextButton(
                      onPressed: () => context.push('/support'),
                      child: const Text('Conversation avec le support')),
                  if (value['canRepeat'] == true)
                    TextButton.icon(
                        icon: const Icon(Icons.copy),
                        onPressed: () => context
                            .push('/parcel/new?source=${widget.parcelId}'),
                        label: const Text('Envoyer un colis similaire')),
                ])));
  }
}

class ParcelComplaintScreen extends StatefulWidget {
  const ParcelComplaintScreen(
      {super.key, required this.parcelId, required this.api});
  final String parcelId;
  final ExperienceApi api;
  @override
  State<ParcelComplaintScreen> createState() => _ParcelComplaintScreenState();
}

class _ParcelComplaintScreenState extends State<ParcelComplaintScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  String _reason = 'delay';
  String _requestId = const Uuid().v4();
  final List<String> _photos = [];
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80);
      if (photo != null) {
        final url =
            await ApiService().uploadFile(file: photo, mediaType: 'photo');
        if (url == null) throw StateError('Photo non envoyée');
        if (mounted)
          setState(() {
            _photos.add(url);
            _requestId = const Uuid().v4();
          });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Photo non envoyée. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request('/parcels/${widget.parcelId}/complaints',
          method: 'POST',
          data: {
            'requestId': _requestId,
            'reason': _reason,
            'message': _message.text.trim(),
            'photos': _photos,
          });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Réclamation non confirmée. Votre saisie est conservée ; réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButtonFormField<String>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motif'),
                items: const [
                  DropdownMenuItem(value: 'delay', child: Text('Retard')),
                  DropdownMenuItem(
                      value: 'damage', child: Text('Colis endommagé')),
                  DropdownMenuItem(
                      value: 'missing', child: Text('Colis manquant')),
                  DropdownMenuItem(value: 'payment', child: Text('Paiement')),
                  DropdownMenuItem(
                      value: 'other', child: Text('Autre problème')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _reason = v!;
                          _requestId = const Uuid().v4();
                        })),
            const SizedBox(height: 16),
            TextFormField(
                controller: _message,
                enabled: !_busy,
                minLines: 4,
                maxLines: 8,
                maxLength: 3000,
                decoration:
                    const InputDecoration(labelText: 'Décrivez le problème'),
                validator: (v) => (v?.trim().length ?? 0) < 10
                    ? 'Décrivez le problème en au moins 10 caractères.'
                    : null,
                onChanged: (_) => _requestId = const Uuid().v4()),
            for (var i = 0; i < _photos.length; i++)
              ListTile(
                  title: Text('Photo ${i + 1} jointe'),
                  trailing: IconButton(
                      tooltip: 'Retirer la photo',
                      icon: const Icon(Icons.close),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _photos.removeAt(i);
                                _requestId = const Uuid().v4();
                              }))),
            OutlinedButton.icon(
                onPressed: _busy || _photos.length >= 4 ? null : _photo,
                icon: const Icon(Icons.add_a_photo),
                label: Text('Ajouter une photo (${_photos.length}/4)')),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _busy ? null : _send,
                style:
                    FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                child: Text(_busy ? 'Envoi…' : 'Envoyer la réclamation')),
          ])));
}
