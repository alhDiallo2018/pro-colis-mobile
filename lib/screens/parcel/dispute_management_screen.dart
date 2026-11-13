// lib/screens/parcel/dispute_management_screen.dart
//
// Gestion des litiges côté client. Trois écrans :
//   - DisputesListScreen : liste des litiges ouverts/historiques de l'utilisateur
//   - NewDisputeScreen   : soumission d'un litige rattaché à un colis
//   - DisputeDetailScreen: suivi d'un litige (événements, commentaires)
//
// Les endpoints backend sont facultatifs (404-safe) : si indisponibles, l'UI
// affiche simplement « Aucun litige ».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/api/client.dart';
import '../../services/api/disputes_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

final _disputesApiProvider =
    Provider<DisputesApi>((ref) => DisputesApi(ApiClient()));

final myDisputesProvider =
    FutureProvider.autoDispose<List<Dispute>>((ref) async {
  final api = ref.read(_disputesApiProvider);
  return api.listMine();
});

final disputeDetailProvider = FutureProvider.family
    .autoDispose<Dispute?, String>((ref, disputeId) async {
  final api = ref.read(_disputesApiProvider);
  return api.get(disputeId);
});

class DisputesListScreen extends ConsumerWidget {
  const DisputesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(myDisputesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.disputesTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(err.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (disputes) => disputes.isEmpty
            ? EmptyState(
                icon: Icons.gavel_rounded,
                title: l.disputesEmpty,
                message:
                    'Depuis un colis livré, vous pouvez signaler un problème formel.',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(myDisputesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: disputes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _DisputeTile(dispute: disputes[i]),
                ),
              ),
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  final Dispute dispute;
  const _DisputeTile({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final statusLabel = _statusLabel(l, dispute.status);
    final statusTone = _statusTone(dispute.status);
    final subtitle = [
      if (dispute.parcelTrackingNumber != null) dispute.parcelTrackingNumber!,
      if (dispute.createdAt != null)
        DateFormat('d MMM y', 'fr').format(dispute.createdAt!),
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusTone.withValues(alpha: 0.12),
          child: Icon(_categoryIcon(dispute.category), color: statusTone),
        ),
        title: Text(dispute.subject ?? _categoryLabel(l, dispute.category)),
        subtitle: Text(subtitle),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusTone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusTone)),
        ),
        onTap: () => context.push('/disputes/${dispute.id}'),
      ),
    );
  }
}

class NewDisputeScreen extends ConsumerStatefulWidget {
  final String parcelId;
  final String? parcelTrackingNumber;
  const NewDisputeScreen(
      {super.key, required this.parcelId, this.parcelTrackingNumber});

  @override
  ConsumerState<NewDisputeScreen> createState() => _NewDisputeScreenState();
}

class _NewDisputeScreenState extends ConsumerState<NewDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  String _category = 'damage';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final api = ref.read(_disputesApiProvider);
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    final result = await api.open(
      parcelId: widget.parcelId,
      category: _category,
      description: _description.text.trim(),
      subject: _subject.text.trim().isEmpty ? null : _subject.text.trim(),
      claimedAmount: amount,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _submitting = false;
        _error = AppLocalizations.of(context).disputesSubmitError;
      });
      return;
    }
    ref.invalidate(myDisputesProvider);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.disputesNewTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.parcelTrackingNumber != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(widget.parcelTrackingNumber!,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l.disputesCategoryLabel),
              isExpanded: true,
              items: [
                DropdownMenuItem(
                    value: 'damage',
                    child: Text(l.disputesCategoryDamage)),
                DropdownMenuItem(
                    value: 'lost', child: Text(l.disputesCategoryLost)),
                DropdownMenuItem(
                    value: 'delay', child: Text(l.disputesCategoryDelay)),
                DropdownMenuItem(
                    value: 'payment',
                    child: Text(l.disputesCategoryPayment)),
                DropdownMenuItem(
                    value: 'other', child: Text(l.disputesCategoryOther)),
              ],
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              enabled: !_submitting,
              decoration: InputDecoration(labelText: l.disputesSubjectLabel),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              enabled: !_submitting,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration:
                  InputDecoration(labelText: l.disputesDescriptionLabel),
              validator: (v) => (v?.trim().length ?? 0) < 20
                  ? l.disputesDescriptionValidator
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              enabled: !_submitting,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: l.disputesClaimedAmountLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? l.disputesSubmitting : l.disputesSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class DisputeDetailScreen extends ConsumerStatefulWidget {
  final String disputeId;
  const DisputeDetailScreen({super.key, required this.disputeId});

  @override
  ConsumerState<DisputeDetailScreen> createState() =>
      _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends ConsumerState<DisputeDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final api = ref.read(_disputesApiProvider);
    await api.comment(widget.disputeId, text);
    if (!mounted) return;
    _comment.clear();
    setState(() => _sending = false);
    ref.invalidate(disputeDetailProvider(widget.disputeId));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(disputeDetailProvider(widget.disputeId));
    return Scaffold(
      appBar: AppBar(title: Text(l.disputesDetailTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (dispute) {
          if (dispute == null) {
            return Center(child: Text(l.disputesEmpty));
          }
          final statusTone = _statusTone(dispute.status);
          return Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(_categoryIcon(dispute.category),
                                color: statusTone),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dispute.subject ??
                                    _categoryLabel(l, dispute.category),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusTone.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                  _statusLabel(l, dispute.status),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusTone)),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(dispute.description),
                          if (dispute.claimedAmount != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${l.disputesClaimedAmountLabel} : ${NumberFormat.decimalPattern('fr').format(dispute.claimedAmount!.round())} ${dispute.currency ?? 'FCFA'}',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                          if (dispute.parcelTrackingNumber != null) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context.push(
                                  '/parcel/${dispute.parcelId}'),
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text(
                                  '${l.disputesParcelLink} · ${dispute.parcelTrackingNumber}'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (dispute.resolutionNote != null &&
                      dispute.resolutionNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: AppTheme.teal50,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.disputesResolutionNote,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.teal700)),
                            const SizedBox(height: 6),
                            Text(dispute.resolutionNote!),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (dispute.events.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(l.disputesEventsTitle,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...dispute.events.map((e) => Card(
                          child: ListTile(
                            leading: Icon(_eventIcon(e.type)),
                            title: Text(e.actorName ?? e.type),
                            subtitle: Text([
                              if (e.message != null) e.message!,
                              if (e.occurredAt != null)
                                e.occurredAt!.toLocal().toString(),
                            ].join('\n')),
                            isThreeLine:
                                e.message != null && e.occurredAt != null,
                          ),
                        )),
                  ],
                ],
              ),
            ),
            if (dispute.isOpen)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        enabled: !_sending,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l.disputesCommentLabel,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: l.disputesCommentSend,
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

String _statusLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'open':
      return l.disputesStatusOpen;
    case 'in_review':
      return l.disputesStatusInReview;
    case 'resolved':
      return l.disputesStatusResolved;
    case 'rejected':
      return l.disputesStatusRejected;
    default:
      return status;
  }
}

Color _statusTone(String status) {
  switch (status) {
    case 'resolved':
      return AppTheme.green600;
    case 'rejected':
      return AppTheme.red500;
    case 'in_review':
      return AppTheme.amber500;
    default:
      return AppTheme.primary;
  }
}

String _categoryLabel(AppLocalizations l, String category) {
  switch (category) {
    case 'damage':
      return l.disputesCategoryDamage;
    case 'lost':
      return l.disputesCategoryLost;
    case 'delay':
      return l.disputesCategoryDelay;
    case 'payment':
      return l.disputesCategoryPayment;
    default:
      return l.disputesCategoryOther;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'damage':
      return Icons.broken_image_rounded;
    case 'lost':
      return Icons.help_outline_rounded;
    case 'delay':
      return Icons.schedule_rounded;
    case 'payment':
      return Icons.payments_rounded;
    default:
      return Icons.flag_rounded;
  }
}

IconData _eventIcon(String type) {
  switch (type) {
    case 'created':
      return Icons.add_circle_outline;
    case 'comment':
      return Icons.chat_bubble_outline_rounded;
    case 'status_change':
      return Icons.change_circle_outlined;
    case 'resolved':
      return Icons.check_circle_outline;
    case 'rejected':
      return Icons.cancel_outlined;
    default:
      return Icons.circle_outlined;
  }
}
