import 'package:flutter/material.dart';
import '../../services/api/client.dart';

class QualityScreen extends StatefulWidget {
  const QualityScreen({super.key});
  @override
  State<QualityScreen> createState() => _QualityScreenState();
}

class _QualityScreenState extends State<QualityScreen> {
  Map<String, dynamic>? _quality;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final client = ApiClient();
      final response = await client.dio.get('/quality');
      final body = client.handle(response);
      if (response.statusCode != 200 || body['success'] != true)
        throw StateError('Indicateurs indisponibles');
      if (mounted)
        setState(() {
          _quality = Map<String, dynamic>.from(body['quality']);
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Indicateurs temporairement indisponibles.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quality;
    final metrics = q == null
        ? <String, dynamic>{}
        : {
            'Colis créés': q['created'],
            'Colis livrés': q['delivered'],
            'Livraisons en retard': q['overdue'],
            'Paiements échoués': q['payments']['failed'] ?? 0,
            'Créations commencées': q['creationAttempts']['started'],
            'Abandons présumés après 24 h': q['creationAttempts']['abandoned'],
            'Première réponse du support': q['firstResponse']['minutes'] == null
                ? 'Pas encore de mesure'
                : '${(q['firstResponse']['minutes'] as num).round()} min',
          };
    return Scaffold(
        appBar: AppBar(title: const Text('Qualité de service')),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'Indicateurs sur les 30 derniers jours. Les retards utilisent les estimations de livraison enregistrées.'),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                OutlinedButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('Actualiser')),
                for (final entry in metrics.entries)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text('${entry.value}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                              ]))),
                if (q != null)
                  Text(
                      'Abandons présumés : formulaires instrumentés sans création confirmée après 24 h. Délai du support calculé sur ${q['firstResponse']['sample']} conversation(s) avec réponse enregistrée.'),
              ],
            )));
  }
}
