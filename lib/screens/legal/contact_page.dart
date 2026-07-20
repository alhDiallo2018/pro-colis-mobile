import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api/client.dart';
import '../../services/api/support_api.dart';
import '../../theme/app_theme.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  final SupportApi _supportApi = SupportApi(ApiClient());

  bool _isSending = false;
  bool _sent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sent = false);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSending = true);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    // Aligné sur la webapp : sujet préfixé + coordonnées reprises dans le corps.
    final result = await _supportApi.sendSupportMessage(
      subject: '[Contact] $subject',
      message: 'Nom : $name\nEmail : $email\n\n$message',
      name: name,
      email: email,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result['success'] == true) {
      setState(() => _sent = true);
      _formKey.currentState?.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _subjectCtrl.clear();
      _messageCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Message envoyé. Réponse sous 24h ouvrées.')),
      );
    } else {
      final msg = result['message']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.red500,
          content: Text(
            (msg == null || msg.isEmpty || msg.startsWith('DioException'))
                ? 'Envoi impossible. Vérifiez votre connexion et réessayez.'
                : msg,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Contact'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Nous contacter'),
          const SizedBox(height: 8),
          _bodyText(
            'Notre équipe est disponible pour répondre à toutes vos questions.',
          ),
          const SizedBox(height: 20),
          _contactCard(
            Icons.mail_rounded,
            AppTheme.teal50,
            AppTheme.primary,
            'Email',
            'support-commercial@sendprocolis.com',
            'Réponse sous 24h ouvrées',
          ),
          const SizedBox(height: 12),
          _contactCard(
            Icons.call_rounded,
            AppTheme.green50,
            AppTheme.green600,
            'Téléphone',
            '+221 76 516 27 96',
            'Lun - Sam, 8h - 20h',
          ),
          const SizedBox(height: 12),
          _contactCard(
            Icons.location_on_rounded,
            AppTheme.amber50,
            AppTheme.amber500,
            'Adresse',
            'Sacré-Cœur 3, Dakar, Sénégal',
            'Sur rendez-vous',
          ),
          const SizedBox(height: 28),
          _sectionTitle('Formulaire de contact'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border.all(color: AppTheme.slate200),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_sent) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.green50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.green100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.green600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Message envoyé. Notre équipe vous répondra '
                              'sous 24h ouvrées.',
                              style: AppFonts.manrope(
                                fontSize: 13,
                                color: AppTheme.green800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _fieldLabel('Votre nom'),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _nameCtrl,
                    hint: 'Votre nom complet',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Veuillez indiquer votre nom.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Votre email'),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _emailCtrl,
                    hint: 'votre@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) {
                        return 'Veuillez indiquer votre email.';
                      }
                      if (!_emailRe.hasMatch(value)) {
                        return 'Adresse email invalide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Sujet'),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _subjectCtrl,
                    hint: 'Sujet de votre message',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Veuillez indiquer un sujet.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Message'),
                  const SizedBox(height: 6),
                  _textField(
                    controller: _messageCtrl,
                    hint: 'Décrivez votre demande...',
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Veuillez écrire votre message.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSending ? null : _submit,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Envoyer le message'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('Horaires'),
          const SizedBox(height: 12),
          _bodyText('Lundi — Vendredi : 8h00 - 20h00'),
          _bodyText('Samedi : 9h00 - 18h00'),
          _bodyText('Dimanche : Support d\'urgence uniquement (chat).'),
          const SizedBox(height: 8),
          _bodyText(
            'Les demandes reçues en dehors des horaires sont traitées le jour '
            'ouvré suivant.',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: AppFonts.manrope(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        fillColor: AppTheme.backgroundColor,
        hintStyle: AppFonts.manrope(fontSize: 14, color: AppTheme.slate400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _contactCard(
    IconData icon,
    Color bgColor,
    Color iconColor,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate200),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppFonts.manrope(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: AppFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: AppFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppTheme.textPrimary,
        ),
      ),
    );

Widget _bodyText(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppFonts.manrope(
          fontSize: 14,
          color: AppTheme.textSecondary,
          height: 1.6,
        ),
      ),
    );
