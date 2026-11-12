// lib/screens/super-admin/backups_screen.dart
//
// Super-admin — sauvegardes de la base applicative.
//
// Expose les 4 endpoints de `backup.controller.js` :
//   - liste des backups (polling manuel via pull-to-refresh)
//   - déclenchement d'un dump (POST async)
//   - téléchargement (binaire) : enregistré en tmp et partagé via Share
//   - restauration : confirmation en clair + flag serveur `restoreEnabled`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api/backups_api.dart';
import '../../services/api/client.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  late final BackupsApi _api = BackupsApi(ApiClient());

  BackupsPage _page = const BackupsPage();
  bool _loading = true;
  bool _creating = false;
  String? _downloadingId;
  String? _restoringId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.list();
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      await _api.create();
      if (!mounted) return;
      _snack('Sauvegarde lancée : le dump tourne en arrière-plan.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _download(BackupEntry entry) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = entry.id);
    try {
      final bytes = await _api.download(entry.id);
      final tempDir = await getTemporaryDirectory();
      final fileName = entry.fileName?.split('/').last ??
          'backup_${entry.id}.dump';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Sauvegarde ProColis',
        text: 'Dump applicatif exporté le ${_formatDate(entry.completedAt)}.',
      );
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _restore(BackupEntry entry) async {
    if (_restoringId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'opération remplace toutes les tables par le contenu du dump '
              'du ${_formatDate(entry.completedAt)}.',
              style: AppFonts.manrope(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'L\'API est indisponible pendant la restauration : vérifiez les '
              'journaux applicatifs avant de rouvrir le trafic.',
              style: AppFonts.manrope(
                fontSize: 12,
                color: AppTheme.red500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _restoringId = entry.id);
    try {
      await _api.restore(entry.id);
      if (!mounted) return;
      _snack('Restauration déclenchée — surveillez les journaux.');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return DateFormat('d MMM y · HH:mm', 'fr').format(d);
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
    double v = bytes.toDouble();
    int idx = 0;
    while (v >= 1024 && idx < units.length - 1) {
      v /= 1024;
      idx++;
    }
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${units[idx]}';
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? EmptyState(
                icon: Icons.error_outline,
                tone: AppTheme.red400,
                title: 'Erreur',
                message: _error,
                action: PcButton('Réessayer', onPressed: _load),
              )
            : _page.backups.isEmpty
                ? const EmptyState(
                    icon: Icons.backup_outlined,
                    title: 'Aucune sauvegarde',
                    message:
                        'Utilisez le bouton « Nouveau dump » pour en créer une.',
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: _page.backups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _entryTile(_page.backups[i]),
                    ),
                  );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Sauvegardes'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating || _loading ? null : _create,
        icon: _creating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload_rounded),
        label: const Text('Nouveau dump'),
      ),
      body: body,
    );
  }

  Widget _entryTile(BackupEntry entry) {
    final isDownloading = _downloadingId == entry.id;
    final isRestoring = _restoringId == entry.id;
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.fileName ?? entry.id,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusChip(entry.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Créée le ${_formatDate(entry.createdAt)}'
            '${entry.completedAt != null ? ' · terminée le ${_formatDate(entry.completedAt)}' : ''}',
            style: AppFonts.manrope(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.requesterName ?? entry.requestedBy,
                  style: AppFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                _formatSize(entry.sizeBytes),
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (entry.isFailed && (entry.errorMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.red50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.errorMessage!,
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.red500,
                ),
              ),
            ),
          ],
          if (entry.isDownloadable) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PcButton(
                    'Télécharger',
                    onPressed:
                        isDownloading ? null : () => _download(entry),
                    loading: isDownloading,
                    icon: Icons.download_rounded,
                    variant: PcButtonVariant.secondary,
                    size: PcButtonSize.sm,
                    block: true,
                  ),
                ),
                if (_page.restoreEnabled) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: PcButton(
                      'Restaurer',
                      onPressed:
                          isRestoring ? null : () => _restore(entry),
                      loading: isRestoring,
                      icon: Icons.settings_backup_restore_rounded,
                      variant: PcButtonVariant.danger,
                      size: PcButtonSize.sm,
                      block: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'completed':
        bg = AppTheme.green50;
        fg = AppTheme.green700;
        label = 'Terminée';
        break;
      case 'running':
        bg = AppTheme.amber50;
        fg = AppTheme.amber600;
        label = 'En cours';
        break;
      case 'failed':
        bg = AppTheme.red50;
        fg = AppTheme.red500;
        label = 'Échec';
        break;
      default:
        bg = AppTheme.slate100;
        fg = AppTheme.slate500;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        label,
        style: AppFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
