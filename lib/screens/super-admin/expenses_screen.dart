import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Registre des dépenses (date / montant / justificatif) — parité avec le web.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _status = '';

  static const _categories = ['Loyer', 'Salaires', 'Marketing', 'Transport', 'Fournitures', 'Maintenance', 'Commissions', 'Autre'];
  static const _statuses = {'paid': 'Payé', 'pending': 'En attente'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getExpenses(status: _status);
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(res['expenses'] ?? res['data'] ?? []);
      _summary = Map<String, dynamic>.from(res['summary'] ?? {});
      _loading = false;
    });
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v : num.tryParse('$v') ?? 0;
    return '${n.toStringAsFixed(0)} FCFA';
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer la dépense ${e['reference'] ?? ''} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await _api.deleteExpense(e['id']?.toString() ?? '');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Dépenses'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _openForm())],
      ),
      body: Column(
        children: [
          if (_summary.isNotEmpty) _summaryRow(),
          _filterBar(),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Aucune dépense'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _tile(_items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow() {
    Widget tile(String label, String v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(color: AppTheme.slate50, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(v, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: c)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        tile('Total', _fcfa(_summary['totalAmount']), AppTheme.textPrimary),
        tile('Payé', _fcfa(_summary['paidAmount']), AppTheme.green700),
        tile('En attente', _fcfa(_summary['pendingAmount']), AppTheme.amber700),
      ]),
    );
  }

  Widget _filterBar() {
    Widget chip(String label, String value) {
      final sel = _status == value;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) {
            setState(() => _status = value);
            _load();
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [chip('Toutes', ''), chip('Payées', 'paid'), chip('En attente', 'pending')]),
    );
  }

  Widget _tile(Map<String, dynamic> e) {
    final st = e['status']?.toString() ?? 'paid';
    final stColor = st == 'paid' ? AppTheme.green700 : AppTheme.amber700;
    final proof = e['proofUrl']?.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(e['reference']?.toString() ?? '', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  Text(e['category']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text(e['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Row(children: [
                  Text(_fcfa(e['amount']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(_statuses[st] ?? st, style: TextStyle(fontSize: 12, color: stColor, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          if (proof != null && proof.isNotEmpty)
            const Icon(Icons.receipt_long, size: 20, color: AppTheme.primary),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openForm(e)),
          IconButton(icon: const Icon(Icons.delete, size: 20, color: AppTheme.red500), onPressed: () => _delete(e)),
        ],
      ),
    );
  }

  void _openForm([Map<String, dynamic>? existing]) {
    final title = TextEditingController(text: existing?['title']?.toString() ?? '');
    final amount = TextEditingController(text: existing?['amount']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    final category = ValueNotifier<String>(existing?['category']?.toString() ?? 'Autre');
    final status = ValueNotifier<String>(existing?['status']?.toString() ?? 'paid');
    final proofUrl = ValueNotifier<String?>(existing?['proofUrl']?.toString());
    final spentAt = ValueNotifier<DateTime>(
      DateTime.tryParse(existing?['spentAt']?.toString() ?? '') ?? DateTime.now(),
    );
    final busy = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Nouvelle dépense' : 'Dépense ${existing['reference'] ?? ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Libellé')),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
              Row(children: [
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: category,
                    builder: (_, v, __) => DropdownButtonFormField<String>(
                      value: v,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (nv) => category.value = nv ?? 'Autre',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: status,
                    builder: (_, v, __) => DropdownButtonFormField<String>(
                      value: v,
                      decoration: const InputDecoration(labelText: 'Statut'),
                      items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (nv) => status.value = nv ?? 'paid',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ValueListenableBuilder<DateTime>(
                valueListenable: spentAt,
                builder: (_, v, __) => InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: v,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) spentAt.value = picked;
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text('${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}'),
                  ),
                ),
              ),
              TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              ValueListenableBuilder<String?>(
                valueListenable: proofUrl,
                builder: (_, url, __) => ValueListenableBuilder<bool>(
                  valueListenable: busy,
                  builder: (_, isBusy, __) => Row(
                    children: [
                      if (url != null && url.isNotEmpty)
                        const Icon(Icons.check_circle, color: AppTheme.green700)
                      else
                        const Icon(Icons.receipt_long, color: AppTheme.slate400),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: isBusy
                            ? null
                            : () async {
                                final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                                if (img == null) return;
                                busy.value = true;
                                final u = await _api.uploadChatPhoto(img);
                                busy.value = false;
                                if (u != null) proofUrl.value = u;
                              },
                        icon: const Icon(Icons.upload),
                        label: Text(isBusy ? 'Envoi…' : (url != null && url.isNotEmpty ? 'Justificatif ajouté' : 'Ajouter un justificatif')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amt = num.tryParse(amount.text.trim()) ?? 0;
                    if (title.text.trim().isEmpty || amt <= 0) return;
                    final d = spentAt.value;
                    final data = {
                      'title': title.text.trim(),
                      'amount': amt,
                      'category': category.value,
                      'description': description.text.trim(),
                      'status': status.value,
                      'spentAt': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                      if (proofUrl.value != null) 'proofUrl': proofUrl.value,
                    };
                    if (existing == null) {
                      await _api.createExpense(data);
                    } else {
                      await _api.updateExpense(existing['id']?.toString() ?? '', data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Text(existing == null ? 'Créer' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
