import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/pin_recovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key, this.initialIdentifier = ''});
  final String initialIdentifier;

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifier;
  final _otp = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  Timer? _timer;
  int _resendSeconds = 0;
  String? _sentIdentifier;
  String? _error;
  bool _busy = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifier.dispose();
    _otp.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String _normalizedIdentifier() {
    final value = _identifier.text.trim();
    return value.contains('@')
        ? value
        : value.replaceAll(RegExp(r'[\s().-]'), '');
  }

  void _startResendTimer() {
    _timer?.cancel();
    _resendSeconds = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _requestCode({bool resend = false}) async {
    if (_busy || (resend && _resendSeconds > 0)) return;
    if (!resend && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Un renvoi conserve l'identifiant de la demande initiale : modifier le
      // champ en cours ne doit jamais changer le compte visé par un OTP.
      final identifier = resend ? _sentIdentifier! : _normalizedIdentifier();
      await ref.read(pinRecoveryServiceProvider).requestCode(identifier);
      if (!mounted) return;
      setState(() {
        _sentIdentifier = identifier;
        _otp.clear();
        _startResendTimer();
      });
    } catch (error, stackTrace) {
      _showError(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPin() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(pinRecoveryServiceProvider).resetPin(
            identifier: _sentIdentifier!,
            otpCode: _otp.text.trim(),
            newPin: _pin.text,
          );
      if (!mounted) return;
      _timer?.cancel();
      _otp.clear();
      _pin.clear();
      _confirmation.clear();
      setState(() => _success = true);
    } catch (error, stackTrace) {
      _showError(error, stackTrace);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error, StackTrace stackTrace) {
    if (error is! PinRecoveryException) {
      debugPrint('[ForgotPin] Échec du parcours : ${error.runtimeType}');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) return;
    setState(() => _error = error is PinRecoveryException
        ? error.message
        : 'Une erreur est survenue. Réessayez dans un instant.');
  }

  Widget _secretField(TextEditingController controller, String label,
      {bool confirmation = false, bool otp = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: _busy,
        obscureText: !otp,
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: otp ? 10 : 6,
        autofillHints: otp ? const [AutofillHints.oneTimeCode] : null,
        decoration: InputDecoration(labelText: label, counterText: ''),
        validator: (value) {
          if (otp) {
            return RegExp(r'^\d{4,10}$').hasMatch(value ?? '')
                ? null
                : 'Saisissez le code reçu.';
          }
          if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
            return 'Le PIN doit contenir exactement 6 chiffres.';
          }
          if (confirmation && value != _pin.text) {
            return 'Les deux codes PIN ne correspondent pas.';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codeSent = _sentIdentifier != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Code PIN oublié'),
        leading: IconButton(
          tooltip: 'Retour à la connexion',
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.lock_reset,
                        size: 56,
                        color: AppTheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      _success
                          ? 'Votre code PIN a été réinitialisé'
                          : codeSent
                              ? 'Choisissez votre nouveau PIN'
                              : 'Retrouvez l’accès à votre compte',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _success
                          ? 'Connectez-vous avec votre nouveau code PIN à six chiffres.'
                          : codeSent
                              ? 'Saisissez le code de vérification envoyé aux coordonnées associées à $_sentIdentifier.'
                              : 'Indiquez l’email ou le numéro de téléphone de votre compte pour recevoir un code de vérification.',
                      style:
                          TextStyle(color: AppTheme.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    if (_success)
                      CustomButton(
                          text: 'Retour à la connexion',
                          onPressed: () => context.go('/login'))
                    else ...[
                      if (!codeSent)
                        TextFormField(
                          controller: _identifier,
                          readOnly: _busy,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Email ou téléphone',
                            hintText: 'exemple@email.com ou +221771234567',
                            helperText:
                                'Pour un téléphone, incluez l’indicatif du pays.',
                            helperMaxLines: 2,
                          ),
                          validator: (_) {
                            final value = _normalizedIdentifier();
                            if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value) ||
                                RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(value))
                              return null;
                            return 'Saisissez un email ou un numéro avec indicatif.';
                          },
                        )
                      else ...[
                        _secretField(_otp, 'Code de vérification', otp: true),
                        _secretField(_pin, 'Nouveau PIN (6 chiffres)'),
                        _secretField(_confirmation, 'Confirmer le nouveau PIN',
                            confirmation: true),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: TextStyle(color: AppTheme.errorColor))),
                      ],
                      const SizedBox(height: 24),
                      CustomButton(
                        text: codeSent
                            ? 'Réinitialiser mon PIN'
                            : 'Recevoir un code',
                        isLoading: _busy,
                        onPressed: codeSent ? _resetPin : () => _requestCode(),
                      ),
                      if (codeSent) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy || _resendSeconds > 0
                              ? null
                              : () => _requestCode(resend: true),
                          child: Text(_resendSeconds > 0
                              ? 'Renvoyer le code dans ${_resendSeconds}s'
                              : 'Renvoyer le code'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  _timer?.cancel();
                                  _formKey.currentState?.reset();
                                  setState(() {
                                    _sentIdentifier = null;
                                    _error = null;
                                    _otp.clear();
                                    _pin.clear();
                                    _confirmation.clear();
                                  });
                                },
                          child: const Text('Modifier l’email ou le téléphone'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
