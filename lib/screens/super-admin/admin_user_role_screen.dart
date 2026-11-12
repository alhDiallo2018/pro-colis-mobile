// lib/screens/super-admin/admin_user_role_screen.dart
//
// OPS-2 — Écran super_admin pour promouvoir un rôle. Saisie userId + sélecteur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/admin_operations_provider.dart';

const _roles = [
  'client',
  'driver',
  'shuttle_operator',
  'admin',
  'support',
  'support_technique',
  'support_commercial',
];

class AdminUserRoleScreen extends ConsumerStatefulWidget {
  const AdminUserRoleScreen({super.key});

  @override
  ConsumerState<AdminUserRoleScreen> createState() => _AdminUserRoleScreenState();
}

class _AdminUserRoleScreenState extends ConsumerState<AdminUserRoleScreen> {
  final _userIdCtrl = TextEditingController();
  String _role = 'shuttle_operator';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(rolePromotionControllerProvider.notifier)
        .promote(_userIdCtrl.text.trim(), _role);
    if (!mounted) return;
    final state = ref.read(rolePromotionControllerProvider);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.successMessage ?? 'Mis à jour')),
      );
      _userIdCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error ?? 'Erreur')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rolePromotionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Promouvoir un rôle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Changer le rôle d\'un utilisateur. Le super_admin ne peut être modifié via cet écran.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _userIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Identifiant utilisateur (UUID)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Champ requis';
                  final uuidRe = RegExp(
                      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                      caseSensitive: false);
                  return uuidRe.hasMatch(s) ? null : 'UUID invalide';
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? 'shuttle_operator'),
                decoration: const InputDecoration(
                  labelText: 'Nouveau rôle',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.busy ? null : _submit,
                icon: state.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.verified),
                label: Text(state.busy ? 'En cours...' : 'Promouvoir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
