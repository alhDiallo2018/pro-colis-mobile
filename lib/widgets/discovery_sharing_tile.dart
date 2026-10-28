import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/driver_discovery_service.dart';

class DiscoverySharingTile extends ConsumerStatefulWidget {
  const DiscoverySharingTile({super.key});
  @override
  ConsumerState<DiscoverySharingTile> createState() =>
      _DiscoverySharingTileState();
}

class _DiscoverySharingTileState extends ConsumerState<DiscoverySharingTile> {
  bool _busy = false;
  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      final sharing = DriverDiscoveryService.instance;
      if (enabled) {
        await sharing.start();
      } else {
        await sharing.stop();
      }
    } catch (error) {
      // Le message français fourni par le service est affiché sous le bouton.
      debugPrint(
          '[DiscoverySharing] Activation impossible (${error.runtimeType})');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(authProvider).user?.isDriverAvailable == true;
    return ValueListenableBuilder<bool>(
      valueListenable: DriverDiscoveryService.instance,
      builder: (context, enabled, _) => SwitchListTile.adaptive(
        value: enabled,
        onChanged: _busy || (!available && !enabled) ? null : _toggle,
        secondary: const Icon(Icons.near_me_outlined),
        title: Text(_busy ? 'Localisation…' : 'Être visible à proximité'),
        subtitle: Text(DriverDiscoveryService.instance.error ??
            (available
                ? 'Partagez votre distance approximative avec les clients. Le partage s’arrête quand l’application passe en arrière-plan.'
                : 'Passez disponible pour partager votre position avec les clients.')),
      ),
    );
  }
}
