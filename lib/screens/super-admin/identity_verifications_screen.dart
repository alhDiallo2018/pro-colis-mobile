import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

/// Revue admin des vérifications d'identité chauffeur (KYC) — parité avec le web.
class IdentityVerificationsScreen extends StatefulWidget {
  const IdentityVerificationsScreen({super.key});

  @override
  State<IdentityVerificationsScreen> createState() => _IdentityVerificationsScreenState();
}

class _IdentityVerificationsScreenState extends State<IdentityVerificationsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _status = 'pending';

  static const _statuses = {'pending': 'À valider', 'approved': 'Vérifiés', 'rejected': 'Rejetés'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _api.getIdentityVerifications(status: _status.isEmpty ? null : _status);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> v) async {
    final res = await _api.approveIdentity(v['id']?.toString() ?? '');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['success'] == false ? 'Erreur' : 'Identité approuvée')),
      );
    }
    _load();
  }

  Future<void> _reject(Map<String, dynamic> v) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeter la vérification'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Motif du refus'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    final res = await _api.rejectIdentity(v['id']?.toString() ?? '', reason);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['success'] == false ? 'Erreur' : 'Vérification rejetée')),
      );
    }
    _load();
  }

  void _openDoc(String? url) {
    if (url == null || url.isEmpty) return;
    final full = ApiService.resolveMediaUrl(url);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(full, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text("Vérifications d'identité"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ..._statuses.entries.map((e) => _chip(e.value, e.key)),
                _chip('Tous', ''),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('Aucune vérification'))
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

  Widget _tile(Map<String, dynamic> v) {
    final st = v['status']?.toString() ?? 'pending';
    final user = v['user'] as Map<String, dynamic>?;
    final front = v['documentFrontUrl']?.toString();
    final back = v['documentBackUrl']?.toString();
    final stColor = st == 'approved'
        ? AppTheme.green700
        : st == 'rejected'
            ? AppTheme.red500
            : AppTheme.amber700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['fullName']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${user?['phone'] ?? ''} · ${v['documentType'] ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: stColor.withAlpha(30), borderRadius: BorderRadius.circular(999)),
                child: Text(_statuses[st] ?? st, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: stColor)),
              ),
            ],
          ),
          if (front != null || back != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (front != null && front.isNotEmpty) _thumb(front),
              if (back != null && back.isNotEmpty) _thumb(back),
            ]),
          ],
          if (st == 'rejected' && (v['rejectionReason']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text('Motif : ${v['rejectionReason']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (st == 'pending' || st == 'rejected') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (st == 'pending')
                  TextButton.icon(
                    onPressed: () => _reject(v),
                    icon: const Icon(Icons.close, color: AppTheme.red500, size: 18),
                    label: const Text('Rejeter', style: TextStyle(color: AppTheme.red500)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _approve(v),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approuver'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _thumb(String url) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => _openDoc(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              ApiService.resolveMediaUrl(url),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppTheme.slate100,
                child: const Icon(Icons.broken_image, color: AppTheme.slate400),
              ),
            ),
          ),
        ),
      );
}
