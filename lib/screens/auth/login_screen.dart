import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/country_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/google_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/auth_fields.dart';
import '../../widgets/pc_components.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  late CountryInfo _country;
  bool _emailMode = false;
  bool _busy = false;
  bool _restoring = true;
  bool _remember = true;
  bool _biometricReady = false;
  String? _error;

  String get _identifier => _emailMode
      ? _email.text.trim().toLowerCase()
      : internationalPhone(_phone.text, _country.dialCode);

  @override
  void initState() {
    super.initState();
    _country = allCountries.firstWhere((c) => c.dialCode == '+221');
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ready = await BiometricService.isEnabled();
      if (!mounted) return;
      final saved = prefs.getString('saved_identifier') ?? '';
      _remember = prefs.getBool('remember_me') ?? true;
      // Migration des préférences de l'ancien champ mixte sans perdre les
      // identifiants mémorisés. Le PIN n'est jamais stocké ici.
      _emailMode = prefs.getString('login_mode') == 'email' ||
          (prefs.getString('login_mode') == null &&
              _remember &&
              saved.contains('@'));
      _country = allCountries.firstWhere(
          (c) => c.dialCode == prefs.getString('saved_country_code'),
          orElse: () => _country);
      if (_remember && saved.isNotEmpty) {
        if (saved.contains('@')) {
          _email.text = saved;
        } else {
          var phone = saved;
          if (phone.startsWith('00')) phone = '+${phone.substring(2)}';
          if (phone.startsWith('+')) {
            final matches = allCountries
                .where((c) => phone.startsWith(c.dialCode))
                .toList()
              ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
            if (matches.isNotEmpty) {
              if (_country.dialCode != matches.first.dialCode) {
                _country = matches.first;
              }
              phone = phone.substring(_country.dialCode.length);
            }
          }
          _phone.text = phone;
        }
      }
      setState(() {
        _biometricReady = ready;
        _restoring = false;
      });
    } catch (error) {
      debugPrint('[Login] Préférences : ${error.runtimeType}');
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _savePreferences({bool google = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'login_mode', google || _emailMode ? 'email' : 'phone');
    await prefs.setBool('remember_me', _remember);
    if (_remember) {
      if (!google) await prefs.setString('saved_identifier', _identifier);
      await prefs.setString('saved_country_code', _country.dialCode);
    } else {
      await prefs.remove('saved_identifier');
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy || _restoring) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on GoogleAuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[Login] Connexion : ${error.runtimeType}');
      if (mounted)
        setState(() => _error = 'Connexion impossible. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      // Enregistrer avant l'authentification : le provider peut déclencher la
      // navigation immédiatement après succès et disposer cet écran.
      await _savePreferences();
      final result = await ref
          .read(authProvider.notifier)
          .loginWithPin(_pin.text, _identifier);
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() => _error =
            result['message']?.toString() ?? 'Identifiant ou PIN incorrect');
        _pin.clear();
      }
    });
  }

  Future<void> _google() => _run(() async {
        final result = await ref.read(googleAuthServiceProvider).signIn();
        if (!mounted || result == null) return;
        await _savePreferences(google: true);
        if (!mounted) return;
        if (result['status'] == 'authenticated') {
          await ref.read(authProvider.notifier).completeGoogleLogin(result);
        } else {
          await context.push('/google-auth', extra: result);
        }
      });

  void _switchMode(bool email) {
    if (_busy || _restoring || email == _emailMode) return;
    FocusScope.of(context).unfocus();
    _pin.clear();
    setState(() {
      _emailMode = email;
      _error = null;
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted) context.go('/dashboard');
    });
    final disabled = _busy || _restoring;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: AutofillGroup(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: AppBrandLink(
                                isWhite: false,
                                onTap: () {
                                  if (!disabled) context.go('/landing');
                                })),
                        const SizedBox(height: 28),
                        Text('Connexion',
                            style: AppFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Retrouvez vos colis et vos livraisons.',
                            style: TextStyle(
                                color: AppTheme.textSecondary, height: 1.5)),
                        const SizedBox(height: 24),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: false,
                                label: Text('Téléphone'),
                                icon: Icon(Icons.phone_outlined)),
                            ButtonSegment(
                                value: true,
                                label: Text('Email'),
                                icon: Icon(Icons.mail_outline_rounded)),
                          ],
                          selected: {_emailMode},
                          showSelectedIcon: false,
                          onSelectionChanged: disabled
                              ? null
                              : (values) => _switchMode(values.first),
                          style: ButtonStyle(
                              padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(vertical: 16))),
                        ),
                        const SizedBox(height: 28),
                        if (_emailMode &&
                            ref.read(googleAuthServiceProvider).supported) ...[
                          OutlinedButton.icon(
                            onPressed: disabled ? null : _google,
                            style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1F1F1F),
                                minimumSize: const Size(double.infinity, 52),
                                side:
                                    const BorderSide(color: Color(0xFF747775)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            icon: Image.asset('assets/icons/google_g.png',
                                width: 20, height: 20),
                            label: const Text('Se connecter avec Google',
                                textAlign: TextAlign.center),
                          ),
                          const SizedBox(height: 24),
                          Row(children: [
                            Expanded(child: Divider(color: AppTheme.slate200)),
                            Expanded(
                                flex: 4,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text('ou avec votre email',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)))),
                            Expanded(child: Divider(color: AppTheme.slate200))
                          ]),
                          const SizedBox(height: 24),
                        ],
                        // Une nouvelle clé retire les erreurs de l'autre mode sans effacer
                        // sa saisie : les contrôleurs email/téléphone restent indépendants.
                        Form(
                            key: _form,
                            child: Column(children: [
                              if (_emailMode)
                                TextFormField(
                                    key: const ValueKey('email-input'),
                                    controller: _email,
                                    enabled: !disabled,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    autocorrect: false,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'Adresse email',
                                        hintText: 'vous@exemple.com',
                                        prefixIcon:
                                            Icon(Icons.alternate_email)),
                                    validator: (value) => RegExp(
                                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(value?.trim() ?? '')
                                        ? null
                                        : 'Saisissez une adresse email valide')
                              else
                                AuthPhoneField(
                                    controller: _phone,
                                    country: _country,
                                    enabled: !disabled,
                                    onCountryChanged: (country) =>
                                        setState(() => _country = country)),
                              const SizedBox(height: 18),
                              AuthPinField(
                                  key: ValueKey('pin-$_emailMode'),
                                  controller: _pin,
                                  enabled: !disabled,
                                  onSubmitted: _login),
                            ])),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: disabled
                                    ? null
                                    : () => context.push('/forgot-pin',
                                        extra: _identifier),
                                child: const Text('Code PIN oublié ?'))),
                        CheckboxListTile(
                            value: _remember,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Mémoriser mon identifiant'),
                            onChanged: disabled
                                ? null
                                : (value) async {
                                    setState(() => _remember = value ?? false);
                                    await _savePreferences();
                                  }),
                        if (_error != null)
                          Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 12),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: AppTheme.errorColor,
                                          height: 1.4)))),
                        const SizedBox(height: 12),
                        PcButton('Se connecter',
                            block: true,
                            size: PcButtonSize.lg,
                            loading: _busy,
                            onPressed: disabled ? null : _login,
                            iconTrailing: Icons.arrow_forward_rounded),
                        if (_biometricReady) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: const Text('Utiliser mon empreinte'),
                              onPressed: disabled
                                  ? null
                                  : () => _run(() async {
                                        final unlocked = await ref
                                            .read(authProvider.notifier)
                                            .unlockWithBiometrics();
                                        if (!unlocked && mounted)
                                          setState(() => _error =
                                              'Déverrouillage impossible. Saisissez votre PIN.');
                                      })),
                        ],
                        const SizedBox(height: 20),
                        TextButton(
                            onPressed: disabled
                                ? null
                                : () => context.push('/register'),
                            child: const Text(
                                'Pas encore de compte ? Créer un compte',
                                textAlign: TextAlign.center)),
                      ])),
                ),
              ))),
    );
  }
}
