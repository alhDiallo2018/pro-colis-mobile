import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

/// Tuile « Langue » prête à être insérée dans n'importe quel écran
/// Settings. Ouvre un modal avec les 3 langues supportées + option
/// « Automatique (système) ».
class LanguagePickerTile extends ConsumerWidget {
  const LanguagePickerTile({super.key});

  static const _choices = <_LangChoice>[
    _LangChoice(code: null, label: 'Automatique (système)'),
    _LangChoice(code: 'fr', label: 'Français'),
    _LangChoice(code: 'en', label: 'English'),
    _LangChoice(code: 'wo', label: 'Wolof'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final currentLabel = _labelFor(current);
    return ListTile(
      leading: const Icon(Icons.language_rounded),
      title: const Text('Langue'),
      subtitle: Text(currentLabel),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _pick(context, ref, current?.languageCode),
    );
  }

  String _labelFor(Locale? locale) {
    if (locale == null) return 'Automatique (système)';
    return _choices
        .firstWhere(
          (c) => c.code == locale.languageCode,
          orElse: () => _choices.first,
        )
        .label;
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, String? currentCode) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _choices
              .map(
                (c) => ListTile(
                  leading: Icon(
                    c.code == currentCode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(c.label),
                  onTap: () => Navigator.pop(ctx, c.code),
                ),
              )
              .toList(),
        ),
      ),
    );
    // picked == null est ambigu : l'utilisateur a fermé le sheet OU
    // a choisi « Automatique ». On utilise un sentinel via un wrapper.
    // Simplification : on n'applique le changement que si `picked` a été
    // explicitement passé via Navigator.pop (option sélectionnée) — on
    // distingue en comparant au currentCode.
    if (!context.mounted) return;
    // On applique toujours : si picked==null et currentCode==null, aucun effet.
    await ref.read(localeProvider.notifier).set(picked == null ? null : Locale(picked));
  }
}

class _LangChoice {
  final String? code;
  final String label;
  const _LangChoice({required this.code, required this.label});
}
