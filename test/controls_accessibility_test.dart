import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/widgets/custom_button.dart';
import 'package:procolis/widgets/pc_components.dart';

void main() {
  testWidgets('les boutons restent lisibles avec de grands caractères', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: SizedBox(width: 240, child: Column(mainAxisSize: MainAxisSize.min, children: [
        PcButton('Confirmer la livraison', icon: Icons.check, onPressed: () {}),
        CustomButton(text: 'Envoyer mon colis', icon: Icons.add, onPressed: () {}),
      ])),
    ))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PcButton)).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(CustomButton)).height, greaterThanOrEqualTo(50));
  });

  testWidgets('le chargement garde un nom accessible et empêche les doubles actions', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PcButton(
      'Publier mon trajet', loading: true, onPressed: () => calls++,
    ))));
    expect(find.bySemanticsLabel('Publier mon trajet, chargement en cours'), findsOneWidget);
    await tester.tap(find.byType(PcButton));
    expect(calls, 0);
    semantics.dispose();
  });
  testWidgets('un lecteur d’écran peut activer le bouton nommé', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PcButton(
      'Envoyer un colis', onPressed: () => calls++,
    ))));
    final node = tester.getSemantics(find.bySemanticsLabel('Envoyer un colis'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(calls, 1);
    semantics.dispose();
  });

}
