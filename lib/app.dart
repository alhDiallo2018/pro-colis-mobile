import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class ProColisApp extends ConsumerWidget {
  const ProColisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return MaterialApp.router(
      title: 'PRO COLIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.router(authState),
    );
  }
}
