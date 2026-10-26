import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/procolis_design_system.dart';

const items = [
  ProcolisTabItem(icon: Icons.home_rounded, label: 'Accueil'),
  ProcolisTabItem(
      icon: Icons.inventory_2_rounded, label: 'Mes colis', badge: 124),
  ProcolisTabItem(icon: Icons.qr_code_scanner_rounded, label: 'Suivi'),
  ProcolisTabItem(icon: Icons.sell_rounded, label: 'Annonces'),
  ProcolisTabItem(icon: Icons.person_rounded, label: 'Profil'),
];

void main() {
  tearDown(() => AppTheme.applyBrightness(Brightness.light));

  testWidgets('le haut du bouton central est cliquable et conserve son index',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
                bottomNavigationBar: ProcolisTabBar(
                  items: items,
                  currentIndex: selected,
                  onTap: (index) => setState(() => selected = index),
                ),
              )),
    ));
    final bar = tester.getRect(find.byType(ProcolisTabBar));
    await tester.tapAt(Offset(bar.center.dx, bar.top + 5));
    await tester.pumpAndSettle();
    expect(selected, 2);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(selected, 4);
    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('petit écran, texte agrandi et quatre onglets sans débordement',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final brightness in Brightness.values) {
      AppTheme.applyBrightness(brightness);
      for (final count in [4, 5]) {
        await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              padding: EdgeInsets.only(bottom: 24),
              disableAnimations: true,
            ),
            child: Scaffold(
                bottomNavigationBar: ProcolisTabBar(
              items: items.take(count).toList(),
              currentIndex: 2,
              onTap: (_) {},
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(InkWell), findsNWidgets(count));
      }
    }
  });
}
