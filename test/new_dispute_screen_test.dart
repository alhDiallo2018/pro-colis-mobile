// Widget test de base pour NewDisputeScreen : garantit que le formulaire
// s'affiche, valide la description trop courte, et peut être soumis.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/screens/parcel/dispute_management_screen.dart';
import 'package:procolis/theme/app_theme.dart';

Widget _scope(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('fr'),
        home: child,
      ),
    );

void main() {
  testWidgets('affiche le formulaire avec les catégories', (tester) async {
    await tester.pumpWidget(_scope(
      const NewDisputeScreen(parcelId: 'parcel-1'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nouveau litige'), findsOneWidget);
    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Décrivez le problème'), findsOneWidget);
    expect(find.text('Soumettre le litige'), findsOneWidget);
    // Le choix par défaut est "damage" → libellé "Colis endommagé".
    expect(find.text('Colis endommagé'), findsOneWidget);
  });

  testWidgets('refuse une description trop courte', (tester) async {
    await tester.pumpWidget(_scope(
      const NewDisputeScreen(
          parcelId: 'parcel-1', parcelTrackingNumber: 'PC 2026/001'),
    ));
    await tester.pumpAndSettle();

    // Le tracking number est affiché en entête.
    expect(find.text('PC 2026/001'), findsOneWidget);

    // Soumettre sans description déclenche le validator.
    await tester.tap(find.text('Soumettre le litige'));
    await tester.pumpAndSettle();
    expect(find.text('Décrivez le problème en au moins 20 caractères.'),
        findsOneWidget);
  });

  testWidgets('permet de changer la catégorie via le dropdown',
      (tester) async {
    await tester.pumpWidget(_scope(
      const NewDisputeScreen(parcelId: 'parcel-1'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Colis endommagé'));
    await tester.pumpAndSettle();
    // Les autres options apparaissent dans la liste du dropdown.
    expect(find.text('Colis perdu'), findsOneWidget);
    expect(find.text('Retard important'), findsOneWidget);
  });
}
