import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/parcel_provider.dart';
import '../services/offline_access.dart';

/// Bandeau persistant, au-dessus du navigateur et sous le verrou biométrique.
/// Il ne disparaît pas sur un simple ping réussi : les données restées en
/// cache continuent d'être identifiées jusqu'à leur actualisation.
class OfflineNotice extends ConsumerStatefulWidget {
  const OfflineNotice({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<OfflineNotice> createState() => _OfflineNoticeState();
}

class _OfflineNoticeState extends ConsumerState<OfflineNotice> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await ref.read(authProvider.notifier).reconnect() || !mounted)
        return;
      final user = ref.read(authProvider).user;
      final parcels = ref.read(parcelProvider.notifier);
      if (user?.isClient == true) await parcels.loadClientParcels(user!);
      if (user?.isDriver == true) await parcels.loadDriverParcels();
    } catch (error, stack) {
      debugPrint(
          '[OfflineNotice] Actualisation impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticated =
        ref.watch(authProvider.select((s) => s.isAuthenticated));
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineAccess.instance,
      builder: (context, status, _) => Column(
        children: [
          if (authenticated && status.showNotice)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            '${status.disconnected ? 'Mode hors ligne · consultation uniquement' : 'Connexion rétablie · actualisez les écrans consultés'}\n'
                            '${status.savedAt == null ? 'Seules les informations déjà enregistrées sont disponibles.' : 'Données enregistrées le ${DateFormat('dd/MM à HH:mm').format(status.savedAt!.toLocal())}. Elles peuvent avoir changé.'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _retry,
                        child: Text(_busy ? 'Vérification…' : 'Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
