import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'messages_screen.dart';

/// Le serveur choisit l'agent ; aucun identifiant de compte support n'est embarque.
class SupportChatScreen extends StatefulWidget {
  final String? ticketId;
  const SupportChatScreen({super.key, this.ticketId});
  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _resumeExisting();
  }

  Future<void> _resumeExisting() async {
    try {
      final result = await ApiService().supportChatRequest('/mine');
      if (mounted && result['conversation'] != null) {
        await _showChat(result['conversation'] as Map);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Historique indisponible : $error');
    }
  }

  Future<void> _showChat(Map chat) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessagesScreen(
          initialPeerId: chat['userId'] as String,
          initialPeerName: 'Support SENDPROCOLIS',
          supportConversationId: chat['id'] as String,
          supportTicketId: widget.ticketId,
        ),
      ));

  Future<void> _open(String department) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ApiService().supportChatRequest('/conversations',
          data: {'department': department});
      if (!mounted) return;
      final chat = result['conversation'] as Map;
      await _showChat(chat);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Contacter le support')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text(
              'Un agent disponible prendra votre demande en charge. Votre historique est conservé si un autre agent prend le relais.'),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _busy ? null : () => _open('commercial'),
              child: const Text('Aide commerciale')),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _busy ? null : () => _open('technique'),
              child: const Text('Aide technique')),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      );
}
