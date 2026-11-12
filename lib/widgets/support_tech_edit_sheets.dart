// lib/widgets/support_tech_edit_sheets.dart
//
// Feuilles d'édition pour le support technique : ticket (status + priority +
// catégorie) et incident (title + scope + severity + impactedUsers + mitigated).
// Les cartes du dashboard conservent leurs actions inline rapides ; ces
// sheets couvrent les champs que `updateTicket` / `updateIncident`
// exposent au-delà du cycle de vie basique.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:procolis/theme/fonts.dart';

import '../models/support.dart';
import '../providers/support_provider.dart';
import '../theme/app_theme.dart';
import 'pc_components.dart';

// ============================================================
// Ticket — édition complète
// ============================================================

class TicketEditSheet extends ConsumerStatefulWidget {
  final SupportTicket ticket;

  const TicketEditSheet({super.key, required this.ticket});

  static Future<bool?> show(
    BuildContext context, {
    required SupportTicket ticket,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TicketEditSheet(ticket: ticket),
    );
  }

  @override
  ConsumerState<TicketEditSheet> createState() => _TicketEditSheetState();
}

class _TicketEditSheetState extends ConsumerState<TicketEditSheet> {
  late TicketStatus _status;
  late TicketPriority _priority;
  late final TextEditingController _categoryCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _priority = widget.ticket.priority;
    _categoryCtrl = TextEditingController(text: widget.ticket.category ?? '');
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final hasChanged = _status != widget.ticket.status ||
          _priority != widget.ticket.priority ||
          _categoryCtrl.text.trim() != (widget.ticket.category ?? '');
      if (!hasChanged) {
        Navigator.of(context).pop(false);
        return;
      }
      await ref.read(supportRolesApiProvider).updateTicket(
            widget.ticket.id,
            status: _status,
            priority: _priority,
            category: _categoryCtrl.text.trim().isEmpty
                ? null
                : _categoryCtrl.text.trim(),
          );
      if (!mounted) return;
      invalidateSupportTechnique(ref);
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('TicketEditSheet: échec de mise à jour $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec : $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  Text(
                    t.reference,
                    style: AppTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.slate500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PcBadge(t.priority.label, tone: t.priority.tone),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.subject,
                style: AppFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
              if ((t.body ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  t.body!,
                  style: AppFonts.manrope(
                    fontSize: 13,
                    color: AppTheme.slate600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Demandeur : ${t.requesterName ?? 'inconnu'}',
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((t.assigneeName ?? '').isNotEmpty)
                Text(
                  'Assigné à : ${t.assigneeName}',
                  style: AppFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 18),
              DropdownButtonFormField<TicketStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: [
                  for (final s in TicketStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TicketPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priorité'),
                items: [
                  for (final p in TicketPriority.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
              const SizedBox(height: 16),
              PcButton(
                'Enregistrer',
                onPressed: _submitting ? null : _submit,
                loading: _submitting,
                icon: Icons.save_rounded,
                size: PcButtonSize.lg,
                block: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Incident — édition complète
// ============================================================

class IncidentEditSheet extends ConsumerStatefulWidget {
  final PlatformIncident incident;

  const IncidentEditSheet({super.key, required this.incident});

  static Future<bool?> show(
    BuildContext context, {
    required PlatformIncident incident,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncidentEditSheet(incident: incident),
    );
  }

  @override
  ConsumerState<IncidentEditSheet> createState() =>
      _IncidentEditSheetState();
}

class _IncidentEditSheetState extends ConsumerState<IncidentEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _scopeCtrl;
  late final TextEditingController _impactedCtrl;
  late IncidentSeverity _severity;
  late bool _mitigated;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.incident.title);
    _scopeCtrl = TextEditingController(text: widget.incident.scope);
    _impactedCtrl = TextEditingController(
      text: widget.incident.impactedUsers.toString(),
    );
    _severity = widget.incident.severity;
    _mitigated = widget.incident.mitigated;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _scopeCtrl.dispose();
    _impactedCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final title = _titleCtrl.text.trim();
      final scope = _scopeCtrl.text.trim();
      final impactedUsers =
          int.tryParse(_impactedCtrl.text.trim()) ?? widget.incident.impactedUsers;

      await ref.read(supportRolesApiProvider).updateIncident(
            widget.incident.id,
            title: title == widget.incident.title ? null : title,
            scope: scope == widget.incident.scope ? null : scope,
            severity:
                _severity == widget.incident.severity ? null : _severity,
            impactedUsers: impactedUsers == widget.incident.impactedUsers
                ? null
                : impactedUsers,
            mitigated:
                _mitigated == widget.incident.mitigated ? null : _mitigated,
          );
      if (!mounted) return;
      invalidateSupportTechnique(ref);
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('IncidentEditSheet: échec de mise à jour $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Échec : $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'Éditer l\'incident',
                style: AppFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _scopeCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Scope'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<IncidentSeverity>(
                initialValue: _severity,
                decoration: const InputDecoration(labelText: 'Sévérité'),
                items: [
                  for (final s in IncidentSeverity.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _impactedCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Utilisateurs touchés'),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _mitigated,
                onChanged: (v) => setState(() => _mitigated = v),
                title: Text(
                  'Contournement actif',
                  style: AppFonts.manrope(fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              PcButton(
                'Enregistrer',
                onPressed: _submitting ? null : _submit,
                loading: _submitting,
                icon: Icons.save_rounded,
                size: PcButtonSize.lg,
                block: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
