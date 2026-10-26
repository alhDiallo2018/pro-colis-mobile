import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/support_presence_monitor.dart';
import 'messages_screen.dart';

class SupportInboxScreen extends ConsumerStatefulWidget {
  const SupportInboxScreen({super.key});
  @override
  ConsumerState<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends ConsumerState<SupportInboxScreen> {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _poll;
  Timer? _debounce;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _people = [];
  bool _loading = false;
  String? _error;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final result = await _api.supportChatRequest('/conversations');
      if (mounted)
        setState(() {
          _chats =
              List<Map<String, dynamic>>.from(result['conversations'] as List);
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _loading = false;
    }
  }

  void _searchUsers(String term) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = term.trim().isEmpty
            ? <String, dynamic>{'users': []}
            : await _api.supportChatRequest(
                '/users?search=${Uri.encodeQueryComponent(term.trim())}');
        // Une reponse lente ne remplace pas une recherche plus recente.
        if (mounted && generation == _searchGeneration)
          setState(() => _people =
              List<Map<String, dynamic>>.from(result['users'] as List));
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
      }
    });
  }

  Future<void> _open(Map<String, dynamic> chat) async {
    final id = chat['id'] as String;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MessagesScreen(
              initialPeerId: chat['userId'] as String,
              initialPeerName: chat['user']['fullName'] as String,
              supportConversationId: id,
            )));
    if (mounted) await _load();
  }

  Future<void> _action(String id, String action) async {
    try {
      await _api.supportChatRequest('/conversations/$id/$action', data: {});
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _contact(Map<String, dynamic> user) async {
    try {
      final result = await _api
          .supportChatRequest('/conversations', data: {'userId': user['id']});
      if (!mounted) return;
      _search.clear();
      setState(() => _people = []);
      await _open(Map<String, dynamic>.from(result['conversation'] as Map));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id;
    final available = ref.watch(supportAvailabilityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Boîte support partagée')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            SwitchListTile(
                title: const Text('Disponible sur cet appareil'),
                value: available,
                onChanged: (value) => ref
                    .read(supportAvailabilityProvider.notifier)
                    .state = value),
            const Text(
                'Les demandes sont réaffectées lorsque vous êtes indisponible. L’historique reste partagé.'),
            const SizedBox(height: 12),
            TextField(
                controller: _search,
                onChanged: _searchUsers,
                decoration: const InputDecoration(
                    labelText: 'Contacter un utilisateur',
                    hintText: 'Nom, email ou téléphone',
                    prefixIcon: Icon(Icons.search))),
            for (final person in _people)
              ListTile(
                  title: Text(person['fullName'] as String),
                  subtitle: Text([person['email'], person['phone']]
                      .whereType<String>()
                      .join(' · ')),
                  onTap: () => _contact(person)),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_chats.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucune demande pour le moment.')),
            for (final chat in _chats)
              Card(
                  child: Column(children: [
                ListTile(
                    title: Text(chat['user']['fullName'] as String),
                    subtitle: Text(
                        '${chat['status'] == 'closed' ? 'Clôturée' : chat['assignedTo'] == null ? 'En attente' : 'Avec ${chat['assignedTo']['fullName']}'}\n${chat['lastMessage']?['body'] ?? ''}'),
                    trailing: Text('${chat['unreadCount'] ?? 0} non lu(s)'),
                    onTap: () => _open(chat)),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (chat['assignedTo'] == null || chat['status'] == 'closed')
                    TextButton(
                        onPressed: available
                            ? () => _action(chat['id'] as String, 'claim')
                            : null,
                        child: const Text('Prendre en charge')),
                  if (chat['assignedTo']?['id'] == userId &&
                      chat['status'] == 'open')
                    TextButton(
                        onPressed: () => _action(chat['id'] as String, 'close'),
                        child: const Text('Clôturer')),
                ]),
              ])),
          ])),
    );
  }
}
