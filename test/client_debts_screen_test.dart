import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/client/client_debts_screen.dart';
import 'package:procolis/services/api_service.dart';

class _Api extends ApiService {
  bool fail = false;
  double total = 400;
  String status = 'partially_paid';
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getClientDebts({int page = 1}) async {
    calls++;
    if (fail) throw Exception('hors ligne');
    return {
      'success': true,
      'summary': {'totalDebt': total, 'canCreateParcel': true},
      'pagination': {'totalPages': 1},
      'debts': [
        {
          'id': 'debt-1',
          'reference': 'PD-001',
          'amount': 1000,
          'remaining': total,
          'status': status,
          'trackingNumber': 'PC-001',
        }
      ],
    };
  }
}

void main() {
  testWidgets(
      'montre le reliquat, ouvre le paiement et actualise après règlement',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(MaterialApp(home: ClientDebtsScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('400 FCFA'), findsOneWidget);
    expect(find.text('400 FCFA restants'), findsOneWidget);
    expect(find.text('Partiellement réglée'), findsOneWidget);
    await tester.tap(find.text('Régler cette dette'));
    await tester.pumpAndSettle();
    expect(find.text('Référence : PD-001'), findsOneWidget);
    expect(find.text('Payer avec PayDunya'), findsOneWidget);
    Navigator.of(tester.element(find.text('Payer avec PayDunya'))).pop();
    await tester.pumpAndSettle();
    api.total = 0;
    api.status = 'paid';
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();
    expect(find.text('Vous êtes à jour.'), findsOneWidget);
    expect(find.text('Réglée'), findsOneWidget);
    expect(find.text('Régler cette dette'), findsNothing);
    expect(api.calls, 2);
  });

  testWidgets('une erreur ne devient pas zéro dette et peut être réessayée',
      (tester) async {
    final api = _Api()..fail = true;
    await tester.pumpWidget(MaterialApp(home: ClientDebtsScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('0 FCFA'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('400 FCFA'), findsOneWidget);
  });
}
