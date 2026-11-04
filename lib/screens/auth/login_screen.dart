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
import '../../widgets/auth_fields.dart';
import '../../widgets/auth_shell.dart';
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
    await prefs.setString('login_mode', google || _emailMode ? 'email' : 'phone');
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
      if (mounted) {
        setState(() => _error = 'Connexion impossible. Veuillez réessayer.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
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
        if (!mounted) return;
        if (result == null) {
          setState(() => _error =
              'Connexion Google annulée ou non aboutie. Aucun compte n’a été connecté.');
          return;
        }
        await _savePreferences(google: true);
        if (!mounted) return;
        if (result['status'] == 'authenticated') {
          await ref.read(authProvider.notifier).completeGoogleLogin(result);
        } else {
          await context.push('/google-auth', extra: result);
        }
      });

  void _switchMode(int index) {
    final email = index == 1;
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
    final googleSupported = ref.read(googleAuthServiceProvider).supported;

    return AuthShell(
      eyebrow: 'Connexion',
      heroIcon: Icons.local_shipping_rounded,
      title: 'Bon retour 👋',
      lead: 'Retrouvez vos colis, vos messages et vos livraisons.',
      onBrandTap: disabled ? null : () => context.go('/landing'),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthSegment(
              value: _emailMode ? 1 : 0,
              enabled: !disabled,
              onChanged: _switchMode,
              options: const [
                AuthSegmentOption(icon: Icons.phone_outlined, label: 'Téléphone'),
                AuthSegmentOption(icon: Icons.mail_outline_rounded, label: 'Email'),
              ],
            ),
            const SizedBox(height: 24),
            if (_emailMode && googleSupported) ...[
              OutlinedButton.icon(
                onPressed: disabled ? null : _google,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(color: AppTheme.slate200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: Image.asset('assets/icons/google_g.png', width: 20, height: 20),
                label: Text(
                  'Se connecter avec Google',
                  style: AppFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Divider(color: AppTheme.slate200)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou avec votre email',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.slate200)),
              ]),
              const SizedBox(height: 20),
            ],
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
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Saisissez une adresse email valide',
                  )
                else
                  AuthPhoneField(
                    controller: _phone,
                    country: _country,
                    enabled: !disabled,
                    onCountryChanged: (country) => setState(() => _country = country),
                  ),
                const SizedBox(height: 16),
                AuthPinField(
                  key: ValueKey('pin-$_emailMode'),
                  controller: _pin,
                  enabled: !disabled,
                  onSubmitted: _login,
                ),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: disabled
                    ? null
                    : () => context.push('/forgot-pin', extra: _identifier),
                child: const Text('Code PIN oublié ?'),
              ),
            ),
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
                    },
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.red50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.red100),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: AppTheme.red500, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppTheme.red500, height: 1.4, fontSize: 13.5),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 16),
            PcButton(
              'Se connecter',
              block: true,
              size: PcButtonSize.lg,
              loading: _busy,
              onPressed: disabled ? null : _login,
              iconTrailing: Icons.arrow_forward_rounded,
            ),
            if (_biometricReady) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Utiliser mon empreinte'),
                onPressed: disabled
                    ? null
                    : () => _run(() async {
                          final unlocked = await ref
                              .read(authProvider.notifier)
                              .unlockWithBiometrics();
                          if (!unlocked && mounted) {
                            setState(() =>
                                _error = 'Déverrouillage impossible. Saisissez votre PIN.');
                          }
                        }),
              ),
            ],
          ],
        ),
      ),
      footer: Column(
        children: [
          Divider(color: AppTheme.slate200, height: 1),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              children: [
                const TextSpan(text: 'Pas encore de compte ? '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: disabled ? null : () => context.push('/register'),
                    child: Text(
                      'Créer un compte',
                      style: AppFonts.plusJakartaSans(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
