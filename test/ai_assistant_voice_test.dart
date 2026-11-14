// Widget tests pour AiAssistantScreen — vérifie que l'UI vocale (micro,
// bouton d'envoi) est présente et que les l10n sont câblés. Les flux
// réseau (ask, transcribe) ne sont pas testés ici — ils nécessitent un
// mock Dio. Objectif : garantir que les états UI sont corrects.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/screens/shared/ai_assistant_screen.dart';
import 'package:procolis/theme/app_theme.dart';

Widget _scope() => MaterialApp(
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('fr'),
      home: const AiAssistantScreen(),
    );

void main() {
  testWidgets('affiche titre, hint, mic et bouton d\'envoi', (tester) async {
    await tester.pumpWidget(_scope());
    await tester.pumpAndSettle();

    expect(find.text('Assistant'), findsOneWidget);
    // Champ de saisie avec le hint français.
    expect(find.text('Décrivez votre expédition…'), findsOneWidget);
    // Icône micro présente (état idle).
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    // Message d'accueil affiché.
    expect(find.textContaining('Bonjour'), findsOneWidget);
  });

  testWidgets('tooltip micro en français', (tester) async {
    await tester.pumpWidget(_scope());
    await tester.pumpAndSettle();
    final tooltip = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.mic_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(tooltip.tooltip, 'Dicter');
  });
}
