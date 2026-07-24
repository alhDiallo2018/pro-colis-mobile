import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Journal des assistances (mail / chat / appel) — parité avec le web.
class AssistancesScreen extends StatefulWidget {
  const AssistancesScreen({super.key});

  @override
  State<AssistancesScreen> createState() => _AssistancesScreenState();
}

class _AssistancesScreenState extends State<AssistancesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _status = '';

  static const _channels = {'chat': 'Chat', 'email': 'E-mail', 'call': 'Appel'};
  static const _statuses = {'open': 'Ouvert', 'in_progress': 'En cours', 'resolved': 'Résolu'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getAssistances(status: _status);
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(res['assistances'] ?? res['data'] ?? []);
      _summary = Map<String, dynamic>.from(res['summary'] ?? {});
      _loading = false;
    });
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer l\'assistance ${a['code'] ?? ''} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true) {
      await _api.deleteAssistance(a['id']?.toString() ?? '');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Assistances'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _openForm()),
        ],
      ),
      body: Column(
        children: [
          if (_summary.isNotEmpty) _summaryRow(),
          _filterBar(),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Aucune assistance'))
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
    Widget tile(String label, dynamic v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: AppTheme.slate50, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text('${v ?? 0}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        tile('Total', _summary['total'], AppTheme.textPrimary),
        tile('Ouverts', _summary['open'], AppTheme.amber700),
        tile('En cours', _summary['inProgress'], AppTheme.teal600),
        tile('Résolus', _summary['resolved'], AppTheme.green700),
      ]),
    );
  }

  Widget _filterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip('Tous', ''),
          ..._statuses.entries.map((e) => _chip(e.value, e.key)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
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

  Widget _tile(Map<String, dynamic> a) {
    final st = a['status']?.toString() ?? 'open';
    final user = a['user'] as Map<String, dynamic>?;
    final who = user?['fullName'] ?? a['contactName'] ?? '—';
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
                  Text(a['code']?.toString() ?? '', style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  const SizedBox(width: 8),
                  _pill(_channels[a['channel']] ?? '${a['channel']}', AppTheme.slate600),
                ]),
                const SizedBox(height: 4),
                Text(a['subject']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$who · ${_statuses[st] ?? st}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openForm(a)),
          IconButton(icon: const Icon(Icons.delete, size: 20, color: AppTheme.red500), onPressed: () => _delete(a)),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      );

  void _openForm([Map<String, dynamic>? existing]) {
    final channel = ValueNotifier<String>(existing?['channel']?.toString() ?? 'chat');
    final status = ValueNotifier<String>(existing?['status']?.toString() ?? 'open');
    final subject = TextEditingController(text: existing?['subject']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    final contactName = TextEditingController(text: existing?['contactName']?.toString() ?? '');
    final contactPhone = TextEditingController(text: existing?['contactPhone']?.toString() ?? '');

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
              Text(existing == null ? 'Nouvelle assistance' : 'Assistance ${existing['code'] ?? ''}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              ValueListenableBuilder<String>(
                valueListenable: channel,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  value: v,
                  decoration: const InputDecoration(labelText: 'Canal'),
                  items: _channels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (nv) => channel.value = nv ?? 'chat',
                ),
              ),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Motif / résumé')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
              Row(children: [
                Expanded(child: TextField(controller: contactName, decoration: const InputDecoration(labelText: 'Nom contact'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: contactPhone, decoration: const InputDecoration(labelText: 'Téléphone'))),
              ]),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  value: v,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: _statuses.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (nv) => status.value = nv ?? 'open',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (subject.text.trim().isEmpty) return;
                    final data = {
                      'channel': channel.value,
                      'subject': subject.text.trim(),
                      'notes': notes.text.trim(),
                      'contactName': contactName.text.trim(),
                      'contactPhone': contactPhone.text.trim(),
                      'status': status.value,
                    };
                    if (existing == null) {
                      await _api.createAssistance(data);
                    } else {
                      await _api.updateAssistance(existing['id']?.toString() ?? '', data);
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
