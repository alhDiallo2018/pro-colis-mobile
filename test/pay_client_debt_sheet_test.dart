// test/pay_client_debt_sheet_test.dart
//
// Tests de la feuille de règlement d'une dette de pénalité client.
// Vérifie l'affichage (référence, montant, bouton), l'absence de tout wallet
// chauffeur, et la désactivation du bouton pendant la création du paiement.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/cancellation.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/widgets/pay_client_debt_sheet.dart';
import 'package:procolis/widgets/pc_components.dart';

class _BlockingApi extends ApiService {
  final Completer<Map<String, dynamic>> completer =
      Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> createPenaltyDebtPayment({
    required String debtId,
    double? amount,
  }) {
    return completer.future;
  }
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('affiche référence, montant et bouton Payer (sans wallet)', (tester) async {
    await tester.pumpWidget(_wrap(
      PayClientDebtSheetContent(
        debt: const CancellationClientDebt(
          id: 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e',
          amount: 1500,
          reference: 'PD-PC-1',
        ),
        onRefresh: () async {},
      ),
    ));

    expect(find.textContaining('Régler la pénalité'), findsOneWidget);
    expect(find.text('Référence : PD-PC-1'), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.text('Payer avec PayDunya'), findsOneWidget);

    // 13. Aucune trace du wallet chauffeur / commission / points.
    expect(find.textContaining('wallet'), findsNothing);
    expect(find.textContaining('Wallet'), findsNothing);
    expect(find.textContaining('commission'), findsNothing);
    expect(find.textContaining('Commission'), findsNothing);
    expect(find.textContaining('solde'), findsNothing);
  });

  testWidgets('9. bouton désactivé pendant la création du paiement', (tester) async {
    final api = _BlockingApi();
    await tester.pumpWidget(_wrap(
      PayClientDebtSheetContent(
        debt: const CancellationClientDebt(
          id: 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e',
          amount: 1500,
          reference: 'PD-PC-1',
        ),
        onRefresh: () async {},
        api: api,
      ),
    ));

    final buttonFinder = find.byType(PcButton);
    final payButtonText = find.text('Payer avec PayDunya');
    expect(payButtonText, findsOneWidget);
    expect(tester.widget<PcButton>(buttonFinder).onPressed, isNotNull);

    await tester.ensureVisible(payButtonText);
    await tester.tap(payButtonText);
    await tester.pump();

    // Pendant la requête, le bouton est désactivé et affiche un spinner.
    expect(tester.widget<PcButton>(buttonFinder).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
