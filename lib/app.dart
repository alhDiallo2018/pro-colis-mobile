import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'services/auth_notifier.dart';
import 'theme/app_theme.dart';

class ProColisApp extends ConsumerStatefulWidget {
  const ProColisApp({super.key});

  @override
  ConsumerState<ProColisApp> createState() => _ProColisAppState();
}

class _ProColisAppState extends ConsumerState<ProColisApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      authRefreshNotifier.notify();
    });

    return MaterialApp.router(
      title: 'PRO COLIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
