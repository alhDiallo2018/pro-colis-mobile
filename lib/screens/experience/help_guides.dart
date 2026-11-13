import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/generated/app_localizations.dart';
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
    final l = AppLocalizations.of(context);
    final guides = widget.guides.where((g) => g.language == _language).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
          initialValue: _language,
          decoration: InputDecoration(labelText: l.helpGuideLanguageLabel),
          items: [
            DropdownMenuItem(value: 'fr', child: Text(l.helpGuideLangFr)),
            DropdownMenuItem(value: 'wo', child: Text(l.helpGuideLangWo))
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
                              label: Text(l.helpGuidePlay),
                              onPressed: () async {
                                try {
                                  await _audio.stop();
                                  await _audio.play(UrlSource(
                                      ApiClient.resolveMediaUrl(
                                          guide.audioUrl!)));
                                  if (mounted) setState(() => _error = null);
                                } catch (_) {
                                  if (!mounted) return;
                                  setState(() => _error = l.helpGuideAudioError);
                                }
                              }),
                          TextButton(
                              onPressed: () => _audio.stop(),
                              child: Text(l.helpGuideStop))
                        ]),
                    ]))),
      if (guides.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_language == 'wo'
                ? l.helpGuideNoneAvailableWo
                : l.helpGuideNoneAvailableFr)),
      if (_error != null) Text(_error!),
      if (guides.isEmpty)
        TextButton(
            onPressed: () => context.push('/support'),
            child: Text(l.helpGuideContactSupport)),
      const SizedBox(height: 16),
    ]);
  }
}
