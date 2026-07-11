import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class RemovePointsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onSuccess;

  const RemovePointsDialog({super.key, required this.userId, this.onSuccess});

  @override
  State<RemovePointsDialog> createState() => _RemovePointsDialogState();
}

class _RemovePointsDialogState extends State<RemovePointsDialog> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final amount = int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Le montant doit être supérieur à 0.');
      return;
    }
    if (desc.isEmpty) {
      setState(() => _error = 'Veuillez saisir une description.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.adminRemovePoints(widget.userId, {
        'amount': amount,
        'description': desc,
      });
      if (res['success'] == true) {
        widget.onSuccess?.call();
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => _error = res['message']?.toString() ?? 'Erreur lors du retrait de points.');
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors du retrait de points.');
    }
    setState(() => _loading = false);
  }

  static Future<bool?> show(BuildContext context, String userId, {VoidCallback? onSuccess}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => RemovePointsDialog(userId: userId, onSuccess: onSuccess),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.remove_circle, color: AppTheme.errorColor, size: 24),
          const SizedBox(width: 10),
          const Text('Retirer des points'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Points',
              hintText: 'Ex: 50',
              prefixIcon: const Icon(Icons.stars, color: AppTheme.amber400),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Motif du retrait...',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.red50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppTheme.red400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(fontSize: 13, color: AppTheme.red500))),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close, size: 14, color: AppTheme.red400),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Retirer'),
        ),
      ],
    );
  }
}
