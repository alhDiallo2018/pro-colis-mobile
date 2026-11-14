// lib/screens/client/csv_bulk_import_sheet.dart
//
// Import CSV côté client : on parse un fichier local et on crée les colis
// un par un via POST /client/parcels/create (pas d'endpoint bulk côté
// serveur). Chaque ligne échouée est reportée à l'utilisateur sans bloquer
// les autres : on privilégie le progrès partiel à l'annulation globale.
//
// Format attendu (séparateur `;`, en-tête optionnel) :
//   receiverName; receiverPhone; description; weightKg; receiverAddress?
//
// Exemple :
//   Awa Diop;770000000;Boîte de livres;2.5;Mermoz, Dakar
//   Moussa Sy;770000001;Pièces auto;5;Guédiawaye

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:procolis/theme/fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class CsvBulkImportSheet extends StatefulWidget {
  const CsvBulkImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CsvBulkImportSheet(),
    );
  }

  @override
  State<CsvBulkImportSheet> createState() => _CsvBulkImportSheetState();
}

class _ParcelRow {
  final int lineNumber;
  final String receiverName;
  final String receiverPhone;
  final String description;
  final double weightKg;
  final String? receiverAddress;
  final String? parseError;

  const _ParcelRow({
    required this.lineNumber,
    required this.receiverName,
    required this.receiverPhone,
    required this.description,
    required this.weightKg,
    this.receiverAddress,
    this.parseError,
  });

  bool get isValid => parseError == null;

  factory _ParcelRow.error(int line, String message) => _ParcelRow(
        lineNumber: line,
        receiverName: '',
        receiverPhone: '',
        description: '',
        weightKg: 0,
        parseError: message,
      );
}

class _ImportOutcome {
  final _ParcelRow row;
  final bool success;
  final String? message;
  const _ImportOutcome(
      {required this.row, required this.success, this.message});
}

class _CsvBulkImportSheetState extends State<CsvBulkImportSheet> {
  final ApiService _api = ApiService();
  List<_ParcelRow> _preview = const [];
  String? _fileName;
  bool _parsing = false;
  bool _uploading = false;
  List<_ImportOutcome> _outcomes = const [];

  Future<void> _pick() async {
    setState(() {
      _parsing = true;
      _preview = const [];
      _outcomes = const [];
    });
    try {
      final picker = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (picker == null || picker.files.isEmpty) {
        if (mounted) setState(() => _parsing = false);
        return;
      }
      final file = picker.files.single;
      String contents;
      if (file.bytes != null) {
        contents = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        contents =
            await File(file.path!).readAsString(encoding: utf8);
      } else {
        throw const FormatException('Fichier illisible.');
      }
      final rows = _parse(contents);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _preview = rows;
        _parsing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lecture impossible : $error')),
      );
    }
  }

  List<_ParcelRow> _parse(String contents) {
    final lines = const LineSplitter().convert(contents);
    final rows = <_ParcelRow>[];
    for (int i = 0; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;
      // En-tête tolérée (mots-clés fréquents) → ignorée silencieusement.
      final lower = raw.toLowerCase();
      if (i == 0 &&
          (lower.contains('receiver') ||
              lower.contains('destinataire') ||
              lower.contains('name') && lower.contains('phone'))) {
        continue;
      }
      final parts = raw.split(';').map((v) => v.trim()).toList();
      if (parts.length < 4) {
        rows.add(_ParcelRow.error(
          i + 1,
          'Au moins 4 colonnes attendues (nom; téléphone; description; poids).',
        ));
        continue;
      }
      final name = parts[0];
      final phone = parts[1];
      final desc = parts[2];
      final weight = double.tryParse(parts[3].replaceAll(',', '.'));
      final addr = parts.length > 4 ? parts[4] : null;

      if (name.isEmpty || phone.isEmpty || desc.isEmpty) {
        rows.add(_ParcelRow.error(
            i + 1, 'Un des champs obligatoires est vide.'));
        continue;
      }
      if (weight == null || !weight.isFinite || weight <= 0) {
        rows.add(_ParcelRow.error(
            i + 1, 'Poids invalide (nombre > 0 attendu).'));
        continue;
      }
      rows.add(_ParcelRow(
        lineNumber: i + 1,
        receiverName: name,
        receiverPhone: phone,
        description: desc,
        weightKg: weight,
        receiverAddress:
            addr == null || addr.isEmpty ? null : addr,
      ));
    }
    return rows;
  }

  Future<void> _upload() async {
    final valid = _preview.where((r) => r.isValid).toList(growable: false);
    if (valid.isEmpty || _uploading) return;
    setState(() {
      _uploading = true;
      _outcomes = const [];
    });

    final payloads = valid
        .map((row) => <String, dynamic>{
              'receiverName': row.receiverName,
              'receiverPhone': row.receiverPhone,
              'description': row.description,
              'weight': row.weightKg,
              if (row.receiverAddress != null)
                'receiverAddress': row.receiverAddress,
            })
        .toList(growable: false);

    // Essaie d'abord l'endpoint bulk atomique (backend v2+). Si 404, retombe
    // sur une création séquentielle pour garder le progrès partiel.
    try {
      final bulk = await _api.bulkCreateParcels(payloads);
      if (bulk != null) {
        // Le serveur préserve l'ordre d'envoi : result[i] correspond à valid[i].
        final outcomes = <_ImportOutcome>[
          for (var i = 0; i < valid.length; i++)
            _ImportOutcome(
              row: valid[i],
              success: i < bulk.results.length
                  ? bulk.results[i]['success'] == true
                  : false,
              message: i < bulk.results.length
                  ? bulk.results[i]['message']?.toString()
                  : 'Réponse serveur incomplète',
            ),
        ];
        if (!mounted) return;
        setState(() {
          _outcomes = outcomes;
          _uploading = false;
        });
        return;
      }
    } catch (_) {
      // L'endpoint bulk existe mais a échoué : on tente ligne par ligne.
    }

    final outcomes = <_ImportOutcome>[];
    for (var i = 0; i < valid.length; i++) {
      final row = valid[i];
      try {
        await _api.createParcel(payloads[i]);
        outcomes.add(_ImportOutcome(row: row, success: true));
      } catch (error) {
        outcomes.add(_ImportOutcome(
          row: row,
          success: false,
          message: error.toString(),
        ));
      }
      if (!mounted) return;
      setState(() => _outcomes = List<_ImportOutcome>.of(outcomes));
    }
    if (!mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _preview.where((r) => r.isValid).length;
    final invalid = _preview.length - valid;
    final successes = _outcomes.where((o) => o.success).length;
    final failures = _outcomes.where((o) => !o.success).length;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Import groupé CSV',
                style: AppFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chaque ligne : destinataire ; téléphone ; description ; '
                'poids (kg) ; adresse (optionnelle).',
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PcButton(
                      _fileName == null
                          ? 'Choisir un fichier'
                          : 'Changer de fichier',
                      icon: Icons.upload_file_rounded,
                      variant: PcButtonVariant.secondary,
                      onPressed: _parsing || _uploading ? null : _pick,
                      loading: _parsing,
                    ),
                  ),
                ],
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 10),
                Text(
                  '$_fileName · ${_preview.length} ligne${_preview.length > 1 ? 's' : ''} '
                  '($valid valides, $invalid à corriger)',
                  style: AppFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
              if (_outcomes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '✓ $successes importé${successes > 1 ? 's' : ''} · '
                  '✗ $failures échec${failures > 1 ? 's' : ''}',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: failures == 0
                        ? AppTheme.green700
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              PcButton(
                _uploading
                    ? 'Import en cours… ${_outcomes.length}/$valid'
                    : 'Importer $valid colis',
                icon: Icons.cloud_upload_rounded,
                size: PcButtonSize.lg,
                block: true,
                onPressed: valid == 0 || _uploading ? null : _upload,
                loading: _uploading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_preview.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: AppTheme.slate300),
            const SizedBox(height: 12),
            Text(
              'Choisissez un fichier CSV pour prévisualiser les colis.',
              style: AppFonts.manrope(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(
                  text:
                      'Awa Diop;770000000;Boîte de livres;2.5;Mermoz\n'
                      'Moussa Sy;770000001;Pièces auto;5;Guédiawaye',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exemple copié dans le presse-papiers'),
                  ),
                );
              },
              icon: const Icon(Icons.content_copy_rounded, size: 16),
              label: const Text('Copier un exemple'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _preview.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final row = _preview[i];
        final outcome = i < _outcomes.length ? _outcomes[i] : null;
        return _row(row, outcome);
      },
    );
  }

  Widget _row(_ParcelRow row, _ImportOutcome? outcome) {
    final Color tone;
    final IconData icon;
    final String label;

    if (outcome != null) {
      tone = outcome.success ? AppTheme.green700 : AppTheme.red500;
      icon = outcome.success
          ? Icons.check_circle_rounded
          : Icons.error_rounded;
      label = outcome.success
          ? 'Importé'
          : (outcome.message ?? 'Échec');
    } else if (!row.isValid) {
      tone = AppTheme.red500;
      icon = Icons.warning_amber_rounded;
      label = row.parseError!;
    } else {
      tone = AppTheme.slate500;
      icon = Icons.pending_outlined;
      label = '${row.weightKg.toStringAsFixed(1)} kg';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: outcome == null
            ? AppTheme.slate100
            : (outcome.success ? AppTheme.green50 : AppTheme.red50),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.isValid
                      ? '${row.receiverName} · ${row.receiverPhone}'
                      : 'Ligne ${row.lineNumber}',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: AppFonts.manrope(
                    fontSize: 11.5,
                    color: tone,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
