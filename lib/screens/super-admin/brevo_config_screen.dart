import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../../services/brevo_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class BrevoConfigScreen extends StatefulWidget {
  const BrevoConfigScreen({super.key});

  @override
  State<BrevoConfigScreen> createState() => _BrevoConfigScreenState();
}

class _BrevoConfigScreenState extends State<BrevoConfigScreen> {
  final BrevoService _brevoService = BrevoService();

  final _senderEmailCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController();
  final _smsSenderCtrl = TextEditingController();
  final _testEmailCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  BrevoConfig? _config;
  String? _message;
  bool _messageSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _senderEmailCtrl.dispose();
    _senderNameCtrl.dispose();
    _smsSenderCtrl.dispose();
    _testEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await _brevoService.getBrevoConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _loading = false;
        if (config != null) {
          _senderEmailCtrl.text = config.senderEmail;
          _senderNameCtrl.text = config.senderName;
          _smsSenderCtrl.text = config.smsSender;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; });
    final result = await _brevoService.updateBrevoConfig({
      'senderEmail': _senderEmailCtrl.text.trim(),
      'senderName': _senderNameCtrl.text.trim(),
      'smsSender': _smsSenderCtrl.text.trim(),
    });
    if (mounted) {
      setState(() {
        _saving = false;
        if (result != null) {
          _config = result;
          _message = 'Configuration Brevo enregistrée.';
          _messageSuccess = true;
        } else {
          _message = 'Échec de la sauvegarde.';
          _messageSuccess = false;
        }
      });
    }
  }

  Future<void> _testConnection() async {
    final email = _testEmailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _testing = true; _message = null; });
    final result = await _brevoService.testBrevoConnection(email);
    if (mounted) {
      setState(() {
        _testing = false;
        _messageSuccess = result.success;
        _message = result.success
            ? 'Email de test envoyé à $email. Vérifiez votre boîte de réception.'
            : (result.error ?? 'Échec de l\'envoi du test.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Configuration Brevo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PcCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configuration Brevo (Email & SMS)', style: AppFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        "Brevo (ex-SendinBlue) est le fournisseur d'emails transactionnels et de SMS. La clé API est configurée côté serveur.",
                        style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _senderEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email expéditeur',
                          hintText: 'no-reply@sendprocolis.com',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _senderNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom expéditeur',
                          hintText: 'SENDPROCOLIS',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _smsSenderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expéditeur SMS (max 11 caractères)',
                          hintText: 'SENDPROCOLIS',
                        ),
                      ),
                      const SizedBox(height: 20),
                      PcButton(
                        'Enregistrer',
                        icon: Icons.save,
                        loading: _saving,
                        variant: PcButtonVariant.primary,
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PcCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tester la connexion Brevo', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Envoyez un email de test pour vérifier que la configuration fonctionne.', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _testEmailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Adresse email de test',
                                hintText: 'support-technic@sendprocolis.com',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          PcButton(
                            'Tester',
                            icon: Icons.send,
                            loading: _testing,
                          ).let((b) => SizedBox(height: 50, child: Center(child: b))),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _messageSuccess ? AppTheme.green50 : AppTheme.red50,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _messageSuccess ? Icons.check_circle : Icons.error_outline,
                          color: _messageSuccess ? AppTheme.green600 : AppTheme.red500,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message!,
                            style: AppFonts.manrope(
                              fontSize: 13,
                              color: _messageSuccess ? AppTheme.green700 : AppTheme.red500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

extension _WidgetExt on Widget {
  Widget let(Widget Function(Widget) fn) => fn(this);
}
