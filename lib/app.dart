import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/auth_notifier.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// En mode « Système », le thème doit suivre le réglage de l'appareil même
  /// quand il change pendant que l'application est ouverte.
  @override
  void didChangePlatformBrightness() {
    if (mounted && ref.read(themeModeProvider) == ThemeMode.system) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      authRefreshNotifier.notify();
    });

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
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(brightness),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
