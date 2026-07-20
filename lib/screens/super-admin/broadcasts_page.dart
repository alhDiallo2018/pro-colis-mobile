import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../models/broadcast.dart';
import '../../services/broadcast_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';
import '../../providers/broadcast_provider.dart';

class BroadcastsPage extends ConsumerStatefulWidget {
  const BroadcastsPage({super.key});

  @override
  ConsumerState<BroadcastsPage> createState() => _BroadcastsPageState();
}

class _BroadcastsPageState extends ConsumerState<BroadcastsPage> {
  final BroadcastService _service = BroadcastService();
  List<Broadcast> _list = [];
  Broadcast? _editing;
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final b = await _service.adminLoadBroadcasts();
      if (mounted) setState(() { _list = b; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _persist(List<Broadcast> next) {
    setState(() => _list = next);
    _service.adminSaveBroadcasts(next);
  }

  void _save(Broadcast b) {
    final next = b.id.isNotEmpty
        ? _list.map((x) => x.id == b.id ? b : x).toList()
        : [..._list, b.copyWith(
            id: DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
                (DateTime.now().microsecondsSinceEpoch % 1000000).toRadixString(36),
            createdAt: DateTime.now().toIso8601String().substring(0, 10),
          )];
    _persist(next);
    setState(() { _editing = null; _saved = true; });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _remove(String id) {
    _persist(_list.where((x) => x.id != id).toList());
  }

  void _toggle(String id) {
    _persist(_list.map((x) => x.id == id ? x.copyWith(active: !x.active) : x).toList());
  }

  Broadcast _empty() {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    return Broadcast(
      id: '',
      title: '',
      message: '',
      scroll: true,
      targetRoles: ['client', 'driver'],
      type: 'info',
      active: true,
      startsAt: now,
      endsAt: DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10),
      createdAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Bandeaux d'information"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bandeaux d'information", style: AppFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text('Diffusez un message ciblé dans la barre supérieure.', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                    PcButton(
                      'Nouveau',
                      icon: Icons.add,
                      variant: PcButtonVariant.primary,
                      onPressed: _editing != null ? null : () => setState(() => _editing = _empty()),
                    ),
                  ],
                ),
                if (_saved) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.green50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.green600, size: 18),
                        const SizedBox(width: 8),
                        Text('Bandeau enregistré.', style: AppFonts.manrope(fontSize: 13, color: AppTheme.green700)),
                      ],
                    ),
                  ),
                ],
                if (_editing != null) ...[
                  const SizedBox(height: 16),
                  _BroadcastForm(
                    broadcast: _editing!,
                    onSave: _save,
                    onCancel: () => setState(() => _editing = null),
                  ),
                ],
                const SizedBox(height: 16),
                if (_list.isEmpty && _editing == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Text('Aucun bandeau pour le moment.', style: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400)),
                    ),
                  ),
                ..._list.map((b) => _BroadcastTile(
                      broadcast: b,
                      onToggle: () => _toggle(b.id),
                      onEdit: () => setState(() => _editing = b),
                      onDelete: () => _remove(b.id),
                    )),
              ],
            ),
    );
  }
}

class _BroadcastTile extends StatelessWidget {
  final Broadcast broadcast;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BroadcastTile({
    required this.broadcast,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeIcon = broadcast.type == 'warning'
        ? Icons.campaign
        : broadcast.type == 'success'
            ? Icons.check_circle
            : broadcast.type == 'promo'
                ? Icons.sell
                : Icons.info;
    final typeColor = broadcast.type == 'warning'
        ? AppTheme.amber500
        : broadcast.type == 'success'
            ? AppTheme.green600
            : broadcast.type == 'promo'
                ? const Color(0xFF1D4ED8)
                : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: broadcast.active ? AppTheme.cardColor : AppTheme.slate100,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        broadcast.title.isNotEmpty ? broadcast.title : 'Sans titre',
                        style: AppFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                    if (broadcast.scroll)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppTheme.teal50, borderRadius: BorderRadius.circular(99)),
                        child: Text('DÉFILANT', style: AppFonts.manrope(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  broadcast.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${broadcast.targetRoles.map(broadcastRoleLabel).join(", ")} · ${broadcast.startsAt} → ${broadcast.endsAt}',
                  style: AppFonts.manrope(fontSize: 11, color: AppTheme.slate400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: broadcast.active ? AppTheme.green50 : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: broadcast.active ? AppTheme.green600 : AppTheme.slate300),
                  ),
                  child: Text(
                    broadcast.active ? 'Actif' : 'Inactif',
                    style: AppFonts.manrope(fontSize: 11, color: broadcast.active ? AppTheme.green600 : AppTheme.slate400, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: Icon(Icons.edit, size: 18, color: AppTheme.slate400),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete, size: 18, color: AppTheme.red500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BroadcastForm extends StatefulWidget {
  final Broadcast broadcast;
  final void Function(Broadcast) onSave;
  final VoidCallback onCancel;

  const _BroadcastForm({
    required this.broadcast,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_BroadcastForm> createState() => _BroadcastFormState();
}

class _BroadcastFormState extends State<_BroadcastForm> {
  late Broadcast _b;

  void _set<K>(K Function(Broadcast) getter, dynamic value, void Function(Broadcast, dynamic) setter) {
    setState(() { setter(_b, value); });
  }

  @override
  void initState() {
    super.initState();
    _b = widget.broadcast.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _b.id.isNotEmpty ? 'Modifier le bandeau' : 'Nouveau bandeau',
            style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Offre spéciale, maintenance...',
            ),
            controller: TextEditingController(text: _b.title),
            onChanged: (v) => _b = _b.copyWith(title: v),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Votre message aux utilisateurs...',
            ),
            maxLines: 3,
            controller: TextEditingController(text: _b.message),
            onChanged: (v) => _b = _b.copyWith(message: v),
          ),
          const SizedBox(height: 14),
          Text('Type', style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['info', 'warning', 'success', 'promo'].map((t) {
              final selected = _b.type == t;
              final label = {'info': 'Info', 'warning': 'Alerte', 'success': 'Succès', 'promo': 'Promo'}[t] ?? t;
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _b = _b.copyWith(type: t)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Image (URL)',
              hintText: 'https://... (optionnel)',
            ),
            controller: TextEditingController(text: _b.imageUrl ?? ''),
            onChanged: (v) => _b = _b.copyWith(imageUrl: v.isEmpty ? null : v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: _b.scroll,
                onChanged: (v) => setState(() => _b = _b.copyWith(scroll: v == true)),
              ),
              Text('Faire défiler le message', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Cibler les rôles', style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: ['client', 'driver', 'admin', 'super_admin'].map((r) {
              final checked = _b.targetRoles.contains(r);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: checked,
                    onChanged: (_) {
                      setState(() {
                        final roles = List<String>.from(_b.targetRoles);
                        checked ? roles.remove(r) : roles.add(r);
                        _b = _b.copyWith(targetRoles: roles);
                      });
                    },
                  ),
                  Text(broadcastRoleLabel(r), style: AppFonts.manrope(fontSize: 13, color: AppTheme.textPrimary)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Du', hintText: 'AAAA-MM-JJ'),
                  controller: TextEditingController(text: _b.startsAt),
                  onChanged: (v) => _b = _b.copyWith(startsAt: v),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Au', hintText: 'AAAA-MM-JJ'),
                  controller: TextEditingController(text: _b.endsAt),
                  onChanged: (v) => _b = _b.copyWith(endsAt: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PcButton('Annuler', icon: Icons.close, variant: PcButtonVariant.secondary, onPressed: widget.onCancel),
              const SizedBox(width: 10),
              PcButton(
                _b.id.isNotEmpty ? 'Modifier' : 'Créer',
                icon: Icons.check,
                variant: PcButtonVariant.primary,
                onPressed: _b.message.trim().isNotEmpty ? () => widget.onSave(_b) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
