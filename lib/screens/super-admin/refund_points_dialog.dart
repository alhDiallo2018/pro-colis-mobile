// lib/screens/super-admin/refund_points_dialog.dart
//
// Remboursement de points (super_admin / support). Appelle POST /score/refund
// avec motif obligatoire : la route serveur force type='refund' +
// direction='credit', donc on ne peut pas accidentellement convertir ce
// remboursement en débit.

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class RefundPointsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onSuccess;

  const RefundPointsDialog({super.key, required this.userId, this.onSuccess});

  static Future<bool?> show(
    BuildContext context,
    String userId, {
    VoidCallback? onSuccess,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          RefundPointsDialog(userId: userId, onSuccess: onSuccess),
    );
  }

  @override
  State<RefundPointsDialog> createState() => _RefundPointsDialogState();
}

class _RefundPointsDialogState extends State<RefundPointsDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    final reason = _reasonCtrl.text.trim();
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Le montant doit être supérieur à 0.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Un motif de remboursement est obligatoire.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.adminRefundPoints(
        userId: widget.userId,
        amount: amount,
        reason: reason,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        widget.onSuccess?.call();
        Navigator.pop(context, true);
      } else {
        setState(() {
          _error = res['message']?.toString() ??
              'Remboursement refusé par le serveur.';
          _loading = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint(
        'RefundPointsDialog: remboursement impossible '
        '($error)\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _error = 'Remboursement impossible.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.refresh_rounded, color: AppTheme.teal500, size: 24),
          const SizedBox(width: 10),
          const Text('Rembourser des points'),
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
              prefixIcon: Icon(Icons.stars, color: AppTheme.amber400),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motif',
              hintText: 'Pourquoi rembourser ?',
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
                  Icon(Icons.error_outline,
                      size: 16, color: AppTheme.red400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style:
                          TextStyle(fontSize: 13, color: AppTheme.red500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: Icon(Icons.close,
                        size: 14, color: AppTheme.red400),
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
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.teal500),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Rembourser'),
        ),
      ],
    );
  }
}
