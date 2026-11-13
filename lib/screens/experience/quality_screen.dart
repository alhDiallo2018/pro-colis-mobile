import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
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
        throw StateError('quality_unavailable');
      if (mounted)
        setState(() {
          _quality = Map<String, dynamic>.from(body['quality']);
          _error = null;
        });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context).qualityScreenError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = _quality;
    final metrics = q == null
        ? <String, dynamic>{}
        : {
            l.qualityParcelsCreated: q['created'],
            l.qualityParcelsDelivered: q['delivered'],
            l.qualityDeliveriesOverdue: q['overdue'],
            l.qualityPaymentsFailed: q['payments']['failed'] ?? 0,
            l.qualityCreationsStarted: q['creationAttempts']['started'],
            l.qualityCreationsAbandoned: q['creationAttempts']['abandoned'],
            l.qualityFirstResponse: q['firstResponse']['minutes'] == null
                ? l.qualityNotYetMeasured
                : l.qualityMinutes(
                    (q['firstResponse']['minutes'] as num).round()),
          };
    return Scaffold(
        appBar: AppBar(title: Text(l.qualityScreenTitle)),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(l.qualityScreenHeader),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                OutlinedButton(
                    onPressed: _loading ? null : _load,
                    child: Text(l.qualityScreenRefresh)),
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
                  Text(l.qualityFooter(
                      q['firstResponse']['sample'].toString())),
              ],
            )));
  }
}
