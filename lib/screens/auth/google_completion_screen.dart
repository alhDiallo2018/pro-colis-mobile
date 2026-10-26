import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/country_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/google_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/auth_fields.dart';
import '../../widgets/pc_components.dart';

/// Le challenge circule uniquement en mémoire (extra GoRouter). Il ne doit
/// être conservé ni dans une URL, ni dans les préférences ou les journaux.
class GoogleCompletionScreen extends ConsumerStatefulWidget {
  const GoogleCompletionScreen({super.key, required this.challenge});
  final Map<String, dynamic> challenge;
  @override
  ConsumerState<GoogleCompletionScreen> createState() =>
      _GoogleCompletionScreenState();
}

class _GoogleCompletionScreenState
    extends ConsumerState<GoogleCompletionScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  late CountryInfo _country;
  late bool _linking;
  late bool _canRegister;
  bool _codeSent = false;
  bool _busy = false;
  bool _accepted = false;
  bool _expired = false;
  String _role = 'client';
  String? _error;
  DateTime? _resendAt;
  Timer? _timer;
  Map<String, dynamic>? _pendingSession;

  String get _token => widget.challenge['challengeToken'] as String;
  String get _linkIdentifier => _identifier.text.contains('@')
      ? _identifier.text.trim().toLowerCase()
      : internationalPhone(_identifier.text, _country.dialCode);
  String get _fullPhone => internationalPhone(_phone.text, _country.dialCode);
  int get _cooldown {
    final seconds =
        (_resendAt?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000;
    return seconds > 0 ? seconds.ceil() : 0;
  }

  @override
  void initState() {
    super.initState();
    _country = allCountries.firstWhere((c) => c.dialCode == '+221');
    _name.text = widget.challenge['fullName']?.toString() ?? '';
    _identifier.text = widget.challenge['email']?.toString() ?? '';
    _linking = widget.challenge['status'] == 'link_required';
    _canRegister = !_linking;
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [
      _name,
      _phone,
      _identifier,
      _otp,
      _pin,
      _confirmation
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _expired) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on GoogleAuthException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          _expired = error.code == 'GOOGLE_CHALLENGE_EXPIRED';
        });
    } catch (error) {
      debugPrint('[GoogleCompletion] Traitement : ${error.runtimeType}');
      if (mounted)
        setState(() => _error = 'Impossible de continuer. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_cooldown > 0 ||
        (!resend && !(_form.currentState?.validate() ?? false))) return;
    await _run(() async {
      await ref.read(googleAuthServiceProvider).sendOtp(_token, _fullPhone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _otp.clear();
        _resendAt = DateTime.now().add(const Duration(seconds: 60));
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _cooldown == 0) timer.cancel();
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _finish() async {
    if (_pendingSession == null && !(_form.currentState?.validate() ?? false))
      return;
    if (!_linking && !_accepted && _pendingSession == null) {
      setState(() =>
          _error = 'Veuillez accepter les conditions pour créer votre compte.');
      return;
    }
    await _run(() async {
      final service = ref.read(googleAuthServiceProvider);
      final result = _pendingSession ??
          (_linking
              ? await service.link(_token, _linkIdentifier, _pin.text)
              : await service.register({
                  'challengeToken': _token,
                  'phone': _fullPhone,
                  'otpCode': _otp.text,
                  'fullName': _name.text.trim(),
                  'pin': _pin.text,
                  'role': _role,
                  'acceptedTerms': _accepted,
                }));
      if (!mounted) return;
      if (result['status'] == 'link_required') {
        setState(() {
          _linking = true;
          _canRegister = false;
          _identifier.text = result['identifier']?.toString() ??
              widget.challenge['email']?.toString() ??
              '';
          _pin.clear();
          _confirmation.clear();
          _otp.clear();
        });
        return;
      }
      // Si l'écriture du stockage sécurisé échoue après le succès serveur,
      // réessayer la finalisation locale sans rejouer le challenge consommé.
      _pendingSession = result;
      await ref.read(authProvider.notifier).completeGoogleLogin(result);
      if (mounted) context.go('/dashboard');
    });
  }

  void _setLinking(bool linking) {
    setState(() {
      _linking = linking;
      _pin.clear();
      _confirmation.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || _expired;
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Connexion Google')),
          body: SafeArea(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                _linking
                                    ? 'Retrouvez votre compte'
                                    : _codeSent
                                        ? 'Sécurisez votre compte'
                                        : 'Bienvenue chez SendProcolis',
                                style: AppFonts.plusJakartaSans(
                                    fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Text(
                                _linking
                                    ? 'Saisissez le PIN de votre compte SendProcolis pour y associer Google.'
                                    : _codeSent
                                        ? 'Saisissez le code envoyé au $_fullPhone, puis choisissez votre PIN à 6 chiffres.'
                                        : 'Encore quelques informations pour préparer vos envois et vos livraisons.',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.5)),
                            const SizedBox(height: 12),
                            Text(widget.challenge['email']?.toString() ?? '',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                            Form(
                                key: _form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_linking) ...[
                                        TextFormField(
                                            key: const ValueKey(
                                                'google-link-identifier'),
                                            controller: _identifier,
                                            enabled: !disabled,
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Email ou téléphone du compte'),
                                            validator: (value) => (value
                                                            ?.trim()
                                                            .length ??
                                                        0) <
                                                    3
                                                ? 'Saisissez votre identifiant'
                                                : null),
                                        const SizedBox(height: 18),
                                        AuthPinField(
                                            key: const ValueKey(
                                                'google-existing-pin'),
                                            controller: _pin,
                                            label: 'Votre PIN actuel',
                                            enabled: !disabled,
                                            onSubmitted: _finish),
                                        Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                                onPressed: disabled
                                                    ? null
                                                    : () => context.push(
                                                        '/forgot-pin',
                                                        extra: _linkIdentifier),
                                                child: const Text(
                                                    'Code PIN oublié ?'))),
                                      ] else if (!_codeSent) ...[
                                        TextFormField(
                                            key: const ValueKey('google-name'),
                                            controller: _name,
                                            enabled: !disabled,
                                            autofillHints: const [
                                              AutofillHints.name
                                            ],
                                            textCapitalization:
                                                TextCapitalization.words,
                                            decoration: const InputDecoration(
                                                labelText: 'Nom complet'),
                                            validator: (value) => (value
                                                            ?.trim()
                                                            .length ??
                                                        0) <
                                                    2
                                                ? 'Saisissez votre nom complet'
                                                : null),
                                        const SizedBox(height: 18),
                                        AuthPhoneField(
                                            controller: _phone,
                                            country: _country,
                                            enabled: !disabled,
                                            onCountryChanged: (country) =>
                                                setState(
                                                    () => _country = country)),
                                        const SizedBox(height: 22),
                                        const Text(
                                            'Vous utilisez SendProcolis en tant que'),
                                        const SizedBox(height: 10),
                                        SegmentedButton<String>(
                                            segments: const [
                                              ButtonSegment(
                                                  value: 'client',
                                                  label: Text('Expéditeur')),
                                              ButtonSegment(
                                                  value: 'driver',
                                                  label: Text('Chauffeur')),
                                            ],
                                            selected: {
                                              _role
                                            },
                                            showSelectedIcon: false,
                                            onSelectionChanged: disabled
                                                ? null
                                                : (values) => setState(() =>
                                                    _role = values.first)),
                                      ] else ...[
                                        TextFormField(
                                            key: const ValueKey('google-otp'),
                                            controller: _otp,
                                            enabled: !disabled,
                                            keyboardType: TextInputType.number,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode
                                            ],
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  6)
                                            ],
                                            decoration: const InputDecoration(
                                                labelText: 'Code reçu par SMS'),
                                            validator: (value) => RegExp(
                                                        r'^\d{6}$')
                                                    .hasMatch(value ?? '')
                                                ? null
                                                : 'Saisissez les 6 chiffres du SMS'),
                                        TextButton(
                                            onPressed: disabled || _cooldown > 0
                                                ? null
                                                : () => _sendCode(resend: true),
                                            child: Text(_cooldown > 0
                                                ? 'Renvoyer le code dans ${_cooldown}s'
                                                : 'Renvoyer le code')),
                                        const SizedBox(height: 10),
                                        AuthPinField(
                                            key: const ValueKey(
                                                'google-new-pin'),
                                            controller: _pin,
                                            label: 'Créer un PIN',
                                            enabled: !disabled),
                                        const SizedBox(height: 18),
                                        AuthPinField(
                                            controller: _confirmation,
                                            label: 'Confirmer le PIN',
                                            confirmation: _pin,
                                            enabled: !disabled,
                                            onSubmitted: _finish),
                                        const SizedBox(height: 14),
                                        CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            value: _accepted,
                                            onChanged: disabled
                                                ? null
                                                : (value) => setState(() =>
                                                    _accepted = value ?? false),
                                            title: const Text(
                                                'J’accepte les conditions de transport et la politique de confidentialité.')),
                                        Wrap(children: [
                                          TextButton(
                                              onPressed: disabled
                                                  ? null
                                                  : () => context.push(
                                                      '/conditions-transport'),
                                              child: const Text(
                                                  'Conditions de transport')),
                                          TextButton(
                                              onPressed: disabled
                                                  ? null
                                                  : () => context
                                                      .push('/confidentialite'),
                                              child: const Text(
                                                  'Confidentialité')),
                                        ]),
                                      ],
                                    ])),
                            if (_error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Semantics(
                                      liveRegion: true,
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: AppTheme.errorColor)))),
                            const SizedBox(height: 24),
                            if (_expired)
                              PcButton('Revenir à la connexion',
                                  block: true,
                                  onPressed: () => context.go('/login'))
                            else
                              PcButton(
                                  _pendingSession != null
                                      ? 'Réessayer'
                                      : _linking
                                          ? 'Associer et me connecter'
                                          : _codeSent
                                              ? 'Créer mon compte'
                                              : _cooldown > 0
                                                  ? 'Recevoir le code dans ${_cooldown}s'
                                                  : 'Recevoir le code SMS',
                                  block: true,
                                  size: PcButtonSize.lg,
                                  loading: _busy,
                                  onPressed: disabled ||
                                          (!_linking &&
                                              !_codeSent &&
                                              _cooldown > 0)
                                      ? null
                                      : () {
                                          if (_linking ||
                                              _codeSent ||
                                              _pendingSession != null) {
                                            _finish();
                                          } else {
                                            _sendCode();
                                          }
                                        }),
                            if (_canRegister && !_expired)
                              TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _setLinking(!_linking),
                                  child: Text(_linking
                                      ? 'Créer un nouveau compte'
                                      : 'J’ai déjà un compte SendProcolis')),
                            if (_codeSent && !_linking && !_expired)
                              TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => setState(() {
                                            _codeSent = false;
                                            _otp.clear();
                                            _pin.clear();
                                            _confirmation.clear();
                                            _error = null;
                                          }),
                                  child:
                                      const Text('Modifier mes informations')),
                          ]),
                    ),
                  ))),
        ));
  }
}
