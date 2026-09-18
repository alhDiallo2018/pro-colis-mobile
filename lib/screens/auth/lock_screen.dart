// mobile/lib/screens/auth/lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/session_lock_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/custom_button.dart';

/// Écran de verrouillage affiché au retour d'une absence prolongée.
///
/// Il se superpose à l'application plutôt que de passer par le routeur : la
/// page en cours reste montée, donc l'utilisateur la retrouve telle quelle
/// après son empreinte, sans avoir perdu sa saisie.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // La demande part d'elle-même : au retour dans l'application, réclamer un
    // appui supplémentaire avant le capteur n'apporte rien.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final unlocked =
          await ref.read(authProvider.notifier).unlockWithBiometrics();
      if (!mounted) return;

      if (unlocked) {
        ref.read(sessionLockProvider.notifier).unlock();
        return;
      }

      setState(() {
        _busy = false;
        _error =
            'Déverrouillage impossible. Réessayez ou utilisez votre code PIN.';
      });
    } catch (error, stackTrace) {
      debugPrint('[LockScreen] Erreur de déverrouillage : $error');
      debugPrintStack(
        label: '[LockScreen] Trace de déverrouillage',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Une erreur est survenue. Utilisez votre code PIN.';
      });
    }
  }

  /// Repli toujours accessible : un capteur mouillé, sale ou défaillant ne doit
  /// jamais enfermer l'utilisateur hors de son compte.
  Future<void> _usePin() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // On garde l'écran opaque jusqu'à la fin de la déconnexion. Le retirer
      // avant exposerait brièvement le dashboard restauré au démarrage.
      await ref.read(authProvider.notifier).logout(forgetBiometrics: false);
    } catch (error, stackTrace) {
      debugPrint('[LockScreen] Repli vers le PIN impossible : $error');
      debugPrintStack(
        label: '[LockScreen] Trace du repli PIN',
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) ref.read(sessionLockProvider.notifier).unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 52,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Application verrouillée',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Utilisez votre empreinte ou la biométrie configurée sur '
                    'cet appareil pour ouvrir SENDPROCOLIS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 14.5,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13.5,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  CustomButton(
                    text: 'Déverrouiller',
                    icon: Icons.fingerprint_rounded,
                    isLoading: _busy,
                    onPressed: _busy ? null : _unlock,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _usePin,
                    child: Text(
                      'Utiliser mon code PIN',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
