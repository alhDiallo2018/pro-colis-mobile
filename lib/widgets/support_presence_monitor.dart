import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

const supportAgentRoles = [
  'support',
  'support_technique',
  'support_commercial',
  'super_admin'
];
final supportAvailabilityProvider = StateProvider<bool>((ref) {
  final role = ref.watch(authProvider.select((state) => state.user?.role));
  return role?.value.startsWith('support') ?? false;
});

/// Presence par appareil : une app en arriere-plan ne retient pas les demandes.
/// Le TTL serveur couvre aussi les fermetures brutales sans callback Flutter.
class SupportPresenceMonitor extends ConsumerStatefulWidget {
  const SupportPresenceMonitor({super.key, required this.child, this.api});
  final Widget child;
  final ApiService? api;
  @override
  ConsumerState<SupportPresenceMonitor> createState() =>
      _SupportPresenceMonitorState();
}

class _SupportPresenceMonitorState extends ConsumerState<SupportPresenceMonitor>
    with WidgetsBindingObserver {
  final _connectionId = const Uuid().v4();
  late final _api = widget.api ?? ApiService();
  Timer? _timer;
  bool _foreground = true;
  Future<void> _queue = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _publish());
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  void _publish() {
    if (!mounted) return;
    final user = ref.read(authProvider).user;
    if (user == null || !supportAgentRoles.contains(user.role.value)) return;
    final available = _foreground && ref.read(supportAvailabilityProvider);
    // Une file preserve l'ordre disponible/absent lorsque le reseau ralentit.
    _queue = _queue.then((_) async {
      if (!mounted || ref.read(authProvider).user?.id != user.id) return;
      try {
        await _api.supportChatRequest('/presence', data: {
          'connectionId': _connectionId,
          'available': available,
        });
      } catch (error, stack) {
        debugPrint('[SupportPresence] Presence non confirmee : $error\n$stack');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _publish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
        authProvider.select((state) => state.user?.id), (_, __) => _publish());
    ref.listen(supportAvailabilityProvider, (_, __) => _publish());
    return widget.child;
  }
}
