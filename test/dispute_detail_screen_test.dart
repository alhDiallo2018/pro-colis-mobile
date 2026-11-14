// Widget tests pour DisputeDetailScreen : vérifie le rendu d'un litige
// ouvert (zone de commentaire visible) vs. résolu (zone cachée, note de
// résolution affichée).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/screens/parcel/dispute_management_screen.dart';
import 'package:procolis/services/api/disputes_api.dart';
import 'package:procolis/theme/app_theme.dart';

Widget _scope(Widget child, {Dispute? dispute, String id = 'd-1'}) {
  return ProviderScope(
    overrides: [
      disputeDetailProvider(id).overrideWith((_) async => dispute),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('fr'),
      home: child,
    ),
  );
}

Dispute _openDispute({String id = 'd-1'}) => Dispute(
      id: id,
      parcelId: 'p-1',
      parcelTrackingNumber: 'PC 2026/042',
      status: 'open',
      category: 'damage',
      subject: 'Carton éventré à la réception',
      description: 'Le carton est arrivé déformé avec un coin percé.',
      claimedAmount: 15000,
      currency: 'XOF',
      createdAt: DateTime(2026, 1, 15),
    );

Dispute _resolvedDispute() => Dispute(
      id: 'd-2',
      parcelId: 'p-1',
      status: 'resolved',
      category: 'damage',
      subject: 'Carton éventré',
      description: 'Enquête close.',
      resolutionNote: 'Remboursement 15000 XOF effectué.',
    );

void main() {
  testWidgets('litige ouvert → affiche champ de commentaire', (tester) async {
    await tester.pumpWidget(_scope(
      const DisputeDetailScreen(disputeId: 'd-1'),
      dispute: _openDispute(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Détail du litige'), findsOneWidget);
    expect(find.text('Carton éventré à la réception'), findsOneWidget);
    expect(find.text('Ouvert'), findsOneWidget);
    // Zone de commentaire présente quand le litige est ouvert.
    expect(find.text('Ajouter un commentaire'), findsOneWidget);
  });

  testWidgets('litige résolu → affiche la note, pas de commentaire',
      (tester) async {
    await tester.pumpWidget(_scope(
      const DisputeDetailScreen(disputeId: 'd-1'),
      dispute: _resolvedDispute(),
      id: 'd-1',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Résolu'), findsOneWidget);
    expect(find.text('Note de résolution'), findsOneWidget);
    expect(find.text('Remboursement 15000 XOF effectué.'), findsOneWidget);
    // Pas de zone de commentaire une fois résolu.
    expect(find.text('Ajouter un commentaire'), findsNothing);
  });

  testWidgets('litige null → message vide', (tester) async {
    await tester.pumpWidget(_scope(
      const DisputeDetailScreen(disputeId: 'd-1'),
      dispute: null,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aucun litige en cours.'), findsOneWidget);
  });
}
