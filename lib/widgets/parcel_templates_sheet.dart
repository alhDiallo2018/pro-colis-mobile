// lib/widgets/parcel_templates_sheet.dart
//
// Sélecteur de modèles de colis. Retourne la map JSON du modèle choisi
// pour que l'appelant préremplisse son formulaire. Permet aussi d'en
// enregistrer un nouveau depuis le brouillon courant et d'en supprimer.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:procolis/theme/fonts.dart';

import '../services/parcel_template_store.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

class ParcelTemplatesSheet extends StatefulWidget {
  final String ownerId;
  final Map<String, dynamic>? currentDraft;

  const ParcelTemplatesSheet({
    super.key,
    required this.ownerId,
    this.currentDraft,
  });

  /// Retourne le data map du modèle sélectionné (ou null si fermé).
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required String ownerId,
    Map<String, dynamic>? currentDraft,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParcelTemplatesSheet(
        ownerId: ownerId,
        currentDraft: currentDraft,
      ),
    );
  }

  @override
  State<ParcelTemplatesSheet> createState() => _ParcelTemplatesSheetState();
}

class _ParcelTemplatesSheetState extends State<ParcelTemplatesSheet> {
  late final ParcelTemplateStore _store =
      ParcelTemplateStore(ownerId: widget.ownerId);
  List<ParcelTemplate> _templates = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final templates = await _store.list();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _saveCurrent() async {
    if (widget.currentDraft == null || widget.currentDraft!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remplissez d\'abord le formulaire : rien à enregistrer.',
          ),
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nommer ce modèle'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex. Envoi hebdo Dakar → Thiès',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _store.save(name: name, data: widget.currentDraft!);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modèle « $name » enregistré')),
      );
    }
  }

  Future<void> _delete(ParcelTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce modèle ?'),
        content: Text('« ${template.name} » sera définitivement effacé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _store.delete(template.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM y', 'fr');
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.75,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mes modèles de colis',
                      style: AppFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (widget.currentDraft != null)
                    TextButton.icon(
                      onPressed: _saveCurrent,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Enregistrer'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Réutilisez vos destinataires et trajets fréquents : les '
                'modèles sont stockés sur cet appareil.',
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _templates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bookmarks_outlined,
                                    size: 48, color: AppTheme.slate300),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucun modèle enregistré.',
                                  style: AppFonts.manrope(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _templates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final t = _templates[i];
                              return PcCard(
                                onTap: () =>
                                    Navigator.of(context).pop(t.data),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppTheme.teal50,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.bookmark_rounded,
                                        color: AppTheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.name,
                                            style:
                                                AppFonts.plusJakartaSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Créé le ${df.format(t.createdAt)}',
                                            style: AppFonts.manrope(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Supprimer',
                                      onPressed: () => _delete(t),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppTheme.red400,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
