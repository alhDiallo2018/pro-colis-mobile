import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import '../../models/public_config.dart';
import '../../services/api/client.dart';

class HelpGuides extends StatefulWidget {
  const HelpGuides({super.key, required this.guides});
  final List<HelpGuide> guides;
  @override
  State<HelpGuides> createState() => _HelpGuidesState();
}

class _HelpGuidesState extends State<HelpGuides> {
  final _audio = AudioPlayer();
  String _language = 'fr';
  String? _error;
  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guides = widget.guides.where((g) => g.language == _language).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
          initialValue: _language,
          decoration: const InputDecoration(labelText: 'Langue des consignes'),
          items: const [
            DropdownMenuItem(value: 'fr', child: Text('Français')),
            DropdownMenuItem(value: 'wo', child: Text('Wolof'))
          ],
          onChanged: (value) {
            _audio.stop();
            setState(() {
              _language = value!;
              _error = null;
            });
          }),
      for (final guide in guides)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(guide.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(guide.text),
                      if (guide.audioUrl != null)
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              icon: const Icon(Icons.volume_up_outlined),
                              label: const Text('Écouter'),
                              onPressed: () async {
                                try {
                                  await _audio.stop();
                                  await _audio.play(UrlSource(
                                      ApiClient.resolveMediaUrl(
                                          guide.audioUrl!)));
                                  if (mounted) setState(() => _error = null);
                                } catch (_) {
                                  if (mounted)
                                    setState(() => _error =
                                        'Lecture indisponible. Le texte reste accessible.');
                                }
                              }),
                          TextButton(
                              onPressed: () => _audio.stop(),
                              child: const Text('Arrêter'))
                        ]),
                    ]))),
      if (guides.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                'Les consignes ${_language == 'wo' ? 'en wolof' : 'en français'} ne sont pas encore disponibles.')),
      if (_error != null) Text(_error!),
      if (guides.isEmpty)
        TextButton(
            onPressed: () => context.push('/support'),
            child: const Text('Demander de l’aide au support')),
      const SizedBox(height: 16),
    ]);
  }
}
