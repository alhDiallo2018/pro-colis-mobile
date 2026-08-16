import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/session_lock_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'screens/auth/lock_screen.dart';
import 'services/auth_notifier.dart';
import 'services/notification_badge_service.dart';
import 'services/notification_navigation.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

class ProColisApp extends ConsumerStatefulWidget {
  const ProColisApp({super.key});

  @override
  ConsumerState<ProColisApp> createState() => _ProColisAppState();
}

class _ProColisAppState extends ConsumerState<ProColisApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router();
    WidgetsBinding.instance.addObserver(this);

    // Branche la navigation depuis une notification : le handler est affecté
    // après la création du routeur, ce qui rejoue aussi une éventuelle
    // notification ouverte pendant le démarrage à froid.
    PushNotificationService.onNotificationTap = _handleNotificationTap;
    NotificationService.onNotificationTap = _handleLocalNotificationTap;
  }

  @override
  void dispose() {
    PushNotificationService.onNotificationTap = null;
    NotificationService.onNotificationTap = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleNotificationTap(Map<String, String> data) {
    NotificationNavigation.handle(data, _router);
  }

  /// Une notification locale transporte son `payload` sous forme de chaîne :
  /// JSON pour les notifications produites par FCM, ou un simple numéro de
  /// suivi pour les anciennes notifications locales.
  void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final data = <String, String>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        decoded.forEach((k, v) => data[k.toString()] = v.toString());
      } else {
        data['trackingNumber'] = payload;
      }
    } catch (_) {
      data['trackingNumber'] = payload;
    }
    NotificationNavigation.handle(data, _router);
  }

  /// En mode « Système », le thème doit suivre le réglage de l'appareil même
  /// quand il change pendant que l'application est ouverte.
  @override
  void didChangePlatformBrightness() {
    if (mounted && ref.read(themeModeProvider) == ThemeMode.system) {
      setState(() {});
    }
  }

  /// Au retour au premier plan, resynchronise le badge de l'icône avec le
  /// nombre réel de notifications non lues côté backend, et verrouille l'écran
  /// si l'absence a dépassé le délai d'inactivité toléré par l'API.
  ///
  /// Tout état autre que `resumed` compte comme un départ : sur iOS une simple
  /// interruption passe par `inactive` avant `paused`, et démarrer le compteur
  /// au plus tôt fait pencher l'erreur du côté prudent.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationBadgeService.refresh();
      ref.read(sessionLockProvider.notifier).evaluateOnResume();
      return;
    }
    ref.read(sessionLockProvider.notifier).markBackgrounded();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      authRefreshNotifier.notify();
      // Connexion / restauration de session : enregistre le token FCM et
      // resynchronise le badge des non-lus.
      final wasAuthenticated = prev?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuthenticated) {
        PushNotificationService.registerTokenWithBackend();
        NotificationBadgeService.refresh();
      } else if (!next.isAuthenticated && wasAuthenticated) {
        NotificationBadgeService.remove();
      }
    });

    // Lu ici, dans le `build` du Consumer : `ref.watch` depuis la closure
    // `builder` s'exécuterait pendant la construction d'un descendant.
    final locked = ref.watch(sessionLockProvider);

    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };

    // Les jetons `AppTheme.xxx` sont statiques : on fixe la luminosité avant
    // que les écrans ne se construisent.
    AppTheme.applyBrightness(brightness);

    return MaterialApp.router(
      title: 'SENDPROCOLIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(Brightness.light),
      darkTheme: AppTheme.themeFor(Brightness.dark),
      themeMode: themeMode,
      routerConfig: _router,
      // La plupart des écrans lisent les couleurs statiquement, sans dépendre
      // de `Theme.of` : changer la clé force la reconstruction complète de
      // l'arbre au changement de mode (les écrans sont reconstruits depuis
      // l'état du routeur, la page courante est conservée).
      // L'écran de verrouillage se superpose au lieu de remplacer la page :
      // l'arbre courant reste monté, donc la saisie en cours survit au
      // déverrouillage.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(brightness),
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (locked) const Positioned.fill(child: LockScreen()),
          ],
        ),
      ),
    );
  }
}
