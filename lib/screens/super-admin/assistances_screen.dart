import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Journal des assistances (mail / chat / appel) — parité avec le web.
///
/// Les supports technique et commercial codifient ici l'assistance qu'ils
/// viennent de rendre : la personne assistée est choisie parmi les comptes
/// existants, la saisie libre ne servant qu'aux personnes non inscrites.
class AssistancesScreen extends ConsumerStatefulWidget {
  const AssistancesScreen({super.key});

  @override
  ConsumerState<AssistancesScreen> createState() => _AssistancesScreenState();
}

class _AssistancesScreenState extends ConsumerState<AssistancesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _status = '';
  bool _onlyMine = false;
  bool _mineInitialized = false;

  static const _channels = {'chat': 'Chat', 'email': 'E-mail', 'call': 'Appel'};
  static const _statuses = {'open': 'Ouvert', 'in_progress': 'En cours', 'resolved': 'Résolu'};
  static const _roleLabels = {
    'client': 'Client',
    'driver': 'Chauffeur',
    'admin': 'Admin zone',
    'super_admin': 'Super admin',
    'support': 'Support',
    'support_technique': 'Support technique',
    'support_commercial': 'Support commercial',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Un agent support arrive sur ses propres assistances ; le super admin voit
    // tout. Fait une seule fois pour ne pas écraser le choix de l'utilisateur.
    if (!_mineInitialized) {
      _mineInitialized = true;
      final role = ref.read(authProvider).user?.role;
      if (role == UserRole.supportTechnique || role == UserRole.supportCommercial) {
        _onlyMine = true;
        _load();
      }
    }
  }

  /// La suppression efface la trace d'une intervention : réservée au super
  /// admin, comme côté API.
  bool get _canDelete => ref.read(authProvider).user?.role == UserRole.superAdmin;

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.getAssistances(status: _status, mine: _onlyMine);
    if (!mounted) return;
    setState(() {
      _items = List<Map<String, dynamic>>.from(res['assistances'] ?? res['data'] ?? []);
      _summary = Map<String, dynamic>.from(res['summary'] ?? {});
      _loading = false;
    });
  }

  /// Clôture en un geste depuis la liste, sans réouvrir le formulaire.
  Future<void> _resolve(Map<String, dynamic> a) async {
    await _api.updateAssistance(a['id']?.toString() ?? '', {'status': 'resolved'});
    _load();
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
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Mes assistances'),
              avatar: const Icon(Icons.person_rounded, size: 16),
              selected: _onlyMine,
              onSelected: (v) {
                setState(() => _onlyMine = v);
                _load();
              },
            ),
          ),
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
    final handledBy = (a['handledBy'] as Map<String, dynamic>?)?['fullName']?.toString();
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
                Row(
                  children: [
                    if (user != null)
                      const Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: Icon(Icons.verified_user_rounded, size: 13, color: AppTheme.green700),
                      ),
                    Expanded(
                      child: Text(
                        '$who · ${_statuses[st] ?? st}'
                        '${handledBy != null ? ' · $handledBy' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (st != 'resolved')
            IconButton(
              icon: const Icon(Icons.task_alt_rounded, size: 20, color: AppTheme.green700),
              tooltip: 'Marquer résolu',
              onPressed: () => _resolve(a),
            ),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _openForm(a)),
          if (_canDelete)
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

  void _toast(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Champ « Utilisateur assisté » : affiche le compte rattaché ou invite à en
  /// choisir un.
  Widget _userField({
    required Map<String, dynamic>? user,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final role = user?['role']?.toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.slate200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_rounded, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: user == null
                  ? const Text('Utilisateur assisté — appuyer pour choisir',
                      style: TextStyle(color: AppTheme.textSecondary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['fullName']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [user['phone']?.toString(), _roleLabels[role] ?? role]
                              .where((s) => s != null && s.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
            ),
            if (user != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Retirer',
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }

  /// Feuille de recherche d'utilisateur. Renvoie le compte choisi, une map vide
  /// pour « pas inscrit — saisir les coordonnées », ou null si annulé.
  Future<Map<String, dynamic>?> _pickUser() {
    final query = TextEditingController();
    final results = ValueNotifier<List<Map<String, dynamic>>>([]);
    final loading = ValueNotifier<bool>(true);

    Future<void> search(String term) async {
      loading.value = true;
      final users = await _api.searchAssistanceUsers(term);
      results.value = users;
      loading.value = false;
    }

    search('');

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Utilisateur assisté',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(
                controller: query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Nom, téléphone ou e-mail',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onSubmitted: search,
                onChanged: (v) {
                  // Recherche serveur dès 2 caractères ; vide = comptes récents.
                  if (v.trim().isEmpty || v.trim().length >= 2) search(v);
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: loading,
                  builder: (_, isLoading, __) => ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: results,
                    builder: (_, users, __) {
                      if (isLoading && users.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (users.isEmpty) {
                        return const Center(child: Text('Aucun compte trouvé'));
                      }
                      return ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final role = u['role']?.toString();
                          return ListTile(
                            leading: const Icon(Icons.account_circle_rounded, color: AppTheme.textSecondary),
                            title: Text(u['fullName']?.toString() ?? ''),
                            subtitle: Text([
                              u['phone']?.toString(),
                              _roleLabels[role] ?? role,
                              u['city']?.toString(),
                            ].where((s) => s != null && s.isNotEmpty).join(' · ')),
                            trailing: u['status'] == 'suspended'
                                ? const Text('SUSPENDU',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.red500))
                                : null,
                            onTap: () => Navigator.pop(ctx, u),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Cette personne n\'est pas inscrite — saisir ses coordonnées'),
                onPressed: () => Navigator.pop(ctx, <String, dynamic>{}),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm([Map<String, dynamic>? existing]) {
    final channel = ValueNotifier<String>(existing?['channel']?.toString() ?? 'chat');
    final status = ValueNotifier<String>(existing?['status']?.toString() ?? 'open');
    final subject = TextEditingController(text: existing?['subject']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    final contactName = TextEditingController(text: existing?['contactName']?.toString() ?? '');
    final contactPhone = TextEditingController(text: existing?['contactPhone']?.toString() ?? '');
    final selectedUser = ValueNotifier<Map<String, dynamic>?>(
      existing?['user'] is Map ? Map<String, dynamic>.from(existing!['user'] as Map) : null,
    );
    // Saisie libre : seulement quand la personne assistée n'est pas inscrite.
    final manual = ValueNotifier<bool>(
      existing != null &&
          existing['user'] == null &&
          ((existing['contactName']?.toString().isNotEmpty ?? false) ||
              (existing['contactPhone']?.toString().isNotEmpty ?? false)),
    );

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
              const SizedBox(height: 6),
              ValueListenableBuilder<bool>(
                valueListenable: manual,
                builder: (_, isManual, __) => isManual
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: TextField(controller: contactName, decoration: const InputDecoration(labelText: 'Nom contact'))),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(controller: contactPhone, decoration: const InputDecoration(labelText: 'Téléphone'))),
                          ]),
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            icon: const Icon(Icons.person_search_rounded, size: 18),
                            label: const Text('Finalement, choisir un utilisateur inscrit'),
                            onPressed: () {
                              contactName.clear();
                              contactPhone.clear();
                              manual.value = false;
                            },
                          ),
                        ],
                      )
                    : ValueListenableBuilder<Map<String, dynamic>?>(
                        valueListenable: selectedUser,
                        builder: (_, user, __) => _userField(
                          user: user,
                          onTap: () async {
                            final picked = await _pickUser();
                            if (picked == null) return;
                            if (picked.isEmpty) {
                              selectedUser.value = null;
                              manual.value = true;
                            } else {
                              selectedUser.value = picked;
                            }
                          },
                          onClear: () => selectedUser.value = null,
                        ),
                      ),
              ),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'Motif / résumé')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
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
                    if (subject.text.trim().isEmpty) {
                      _toast(ctx, 'Le motif est requis.');
                      return;
                    }
                    final userId = manual.value ? null : selectedUser.value?['id']?.toString();
                    if (userId == null && contactName.text.trim().isEmpty) {
                      _toast(
                        ctx,
                        'Sélectionnez l\'utilisateur assisté, ou saisissez son nom s\'il n\'est pas inscrit.',
                      );
                      return;
                    }
                    final data = {
                      'channel': channel.value,
                      'subject': subject.text.trim(),
                      'notes': notes.text.trim(),
                      'userId': userId,
                      // Compte rattaché : la saisie libre n'a plus lieu d'être.
                      'contactName': userId == null ? contactName.text.trim() : '',
                      'contactPhone': userId == null ? contactPhone.text.trim() : '',
                      'status': status.value,
                    };
                    final res = existing == null
                        ? await _api.createAssistance(data)
                        : await _api.updateAssistance(existing['id']?.toString() ?? '', data);
                    if (res['success'] == false) {
                      if (ctx.mounted) _toast(ctx, res['message']?.toString() ?? 'Enregistrement impossible.');
                      return;
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
