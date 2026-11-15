import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Ajoute `X-App-Version`, `X-App-Build` et `X-App-Platform` à chaque requête
/// sortante. Le serveur peut ainsi refuser une version obsolète (défense en
/// profondeur : la gate client reste la première ligne).
class AppVersionInterceptor extends Interceptor {
  AppVersionInterceptor({Future<PackageInfo> Function()? loadPackageInfo})
      : _loadPackageInfo = loadPackageInfo ?? PackageInfo.fromPlatform;

  final Future<PackageInfo> Function() _loadPackageInfo;
  Future<_AppIdentity>? _cached;

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final identity = await (_cached ??= _resolve());
      options.headers.putIfAbsent('X-App-Version', () => identity.version);
      options.headers.putIfAbsent('X-App-Build', () => identity.build);
      options.headers.putIfAbsent('X-App-Platform', () => identity.platform);
    } catch (_) {
      // L'absence d'infos ne doit jamais bloquer une requête fonctionnelle.
    }
    handler.next(options);
  }

  Future<_AppIdentity> _resolve() async {
    final info = await _loadPackageInfo();
    return _AppIdentity(
      version: info.version,
      build: info.buildNumber,
      platform: _platformLabel(),
    );
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }
}

class _AppIdentity {
  const _AppIdentity(
      {required this.version, required this.build, required this.platform});
  final String version;
  final String build;
  final String platform;
}
