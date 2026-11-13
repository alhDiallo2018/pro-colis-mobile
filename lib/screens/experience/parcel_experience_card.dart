import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/generated/app_localizations.dart';
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
      if (!mounted || widget.parcelId != id) return;
      setState(() =>
          _error = AppLocalizations.of(context).experienceLoadFailed);
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
    final l = AppLocalizations.of(context);
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
                          onPressed: _load, child: Text(l.errorRetry))
                    ])));
    final next = value['nextAction'] as Map;
    final finance = value['finance'] as Map;
    final tracking = value['tracking'] as Map;
    final timestamp =
        DateTime.tryParse(tracking['lastPositionAt']?.toString() ?? '')
            ?.toLocal();
    final age = timestamp == null ? null : DateTime.now().difference(timestamp);
    final fresh = tracking['positionFresh'] == true &&
        age != null &&
        !age.isNegative &&
        age.inSeconds <= 120;
    final commissionEstimated = finance['commissionEstimated'] == true;
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
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(l.experienceOverdueNotice)),
                  if (timestamp != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(fresh
                            ? l.experienceLastPositionFresh(
                                timestamp.toString())
                            : l.experienceLastPositionStale(
                                timestamp.toString()))),
                  const Divider(height: 28),
                  Text(l.experienceFinanceTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  _row(l.experienceAgreedPrice, finance['agreedPrice']),
                  _row(l.experiencePaymentsConfirmed, finance['collected']),
                  if (finance.containsKey('commission')) ...[
                    _row(
                        commissionEstimated
                            ? l.experienceCommissionEstimated
                            : l.experienceCommissionRecorded,
                        finance['commission']),
                    _row(
                        commissionEstimated
                            ? l.experienceNetAfterCommissionEstimated
                            : l.experienceNetAfterCommission,
                        finance['netAfterCommission']),
                    _row(l.experienceCommissionPaid, finance['paidCommission']),
                    _row(l.experienceDebtCreated, finance['debtCreated']),
                    _row(l.experienceAccountCommissionDebt,
                        finance['accountCommissionDebt']),
                  ],
                  if (finance.containsKey('parcelPenaltyDue'))
                    _row(l.experienceParcelPenaltyDue,
                        finance['parcelPenaltyDue']),
                  for (final receipt in value['receipts'] as List)
                    TextButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        onPressed: () => Share.share(receiptText(
                            Map<String, dynamic>.from(receipt),
                            value['trackingNumber'])),
                        label: Text(l.experienceShareReceipt(
                            experienceMoney(receipt['amount'])))),
                  const Divider(height: 28),
                  for (final ticket in value['complaints'] as List)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextButton(
                            onPressed: () =>
                                context.push('/support?ticket=${ticket['id']}'),
                            child: Text(l.experienceFollowComplaint(
                                ticket['subject'].toString(),
                                complaintStatus(ticket['status']))))),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.support_agent),
                      onPressed: () async {
                        final sent = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                                builder: (_) => ParcelComplaintScreen(
                                    parcelId: widget.parcelId, api: _api)));
                        if (sent == true) await _load();
                      },
                      label: Text(l.experienceReportIssue)),
                  TextButton(
                      onPressed: () => context.push('/support'),
                      child: Text(l.experienceContactSupport)),
                  if (value['canRepeat'] == true)
                    TextButton.icon(
                        icon: const Icon(Icons.copy),
                        onPressed: () => context
                            .push('/parcel/new?source=${widget.parcelId}'),
                        label: Text(l.experienceSendSimilar)),
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
        if (url == null) throw StateError('upload_failed');
        if (mounted)
          setState(() {
            _photos.add(url);
            _requestId = const Uuid().v4();
          });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = AppLocalizations.of(context).complaintPhotoError);
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
      if (!mounted) return;
      setState(() =>
          _error = AppLocalizations.of(context).complaintSubmitError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l.experienceReportIssue)),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              DropdownButtonFormField<String>(
                  initialValue: _reason,
                  isExpanded: true,
                  decoration:
                      InputDecoration(labelText: l.complaintReasonLabel),
                  items: [
                    DropdownMenuItem(
                        value: 'delay', child: Text(l.complaintReasonDelay)),
                    DropdownMenuItem(
                        value: 'damage',
                        child: Text(l.complaintReasonDamage)),
                    DropdownMenuItem(
                        value: 'missing',
                        child: Text(l.complaintReasonMissing)),
                    DropdownMenuItem(
                        value: 'payment',
                        child: Text(l.complaintReasonPayment)),
                    DropdownMenuItem(
                        value: 'other', child: Text(l.complaintReasonOther)),
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
                      InputDecoration(labelText: l.complaintMessageLabel),
                  validator: (v) => (v?.trim().length ?? 0) < 10
                      ? l.complaintMessageValidator
                      : null,
                  onChanged: (_) => _requestId = const Uuid().v4()),
              for (var i = 0; i < _photos.length; i++)
                ListTile(
                    title: Text(l.complaintPhotoAttached(i + 1)),
                    trailing: IconButton(
                        tooltip: l.complaintRemovePhoto,
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
                  label: Text(l.complaintAddPhoto(_photos.length))),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary),
                  child:
                      Text(_busy ? l.complaintSending : l.complaintSubmit)),
            ])));
  }
}
