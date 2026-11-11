import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/l10n/generated/app_localizations.dart';

/// Vérifie que l'infrastructure l10n est fonctionnelle : AppLocalizations
/// expose bien les clés dans les 3 locales (fr/en/wo) sans crash. On
/// utilise Localizations.override directement pour isoler AppLocalizations
/// des delegates système — plus simple et sans warning "MaterialLocalizations
/// non trouvées" sur wo (qui n'est pas couvert par GlobalMaterialLocalizations).
void main() {
  Future<void> pumpWithLocale(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: locale,
          delegates: const [
            AppLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Builder(
            builder: (ctx) => Column(
              children: [
                Text(AppLocalizations.of(ctx).brandName, key: const Key('brand')),
                Text(AppLocalizations.of(ctx).navSend, key: const Key('send')),
                Text(AppLocalizations.of(ctx).ocrScanLabel, key: const Key('ocr')),
                Text(AppLocalizations.of(ctx).trackingEtaArriving, key: const Key('eta')),
                Text(
                  AppLocalizations.of(ctx).trackingEtaLive(15, 12, 18),
                  key: const Key('eta-live'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('expose les strings en français', (tester) async {
    await pumpWithLocale(tester, const Locale('fr'));
    expect(find.byKey(const Key('send')), findsOneWidget);
    expect(find.text('Envoyer'), findsOneWidget);
    expect(find.text('Scanner une étiquette'), findsOneWidget);
    expect(find.text('Arrivée imminente'), findsOneWidget);
  });

  testWidgets('expose les strings en anglais', (tester) async {
    await pumpWithLocale(tester, const Locale('en'));
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Scan a label'), findsOneWidget);
    expect(find.text('Arriving soon'), findsOneWidget);
  });

  testWidgets('expose les strings en wolof', (tester) async {
    await pumpWithLocale(tester, const Locale('wo'));
    expect(find.text('Yónnee'), findsOneWidget);
    expect(find.text('Scanne palanka bi'), findsOneWidget);
  });

  testWidgets('interpole les placeholders (ETA live)', (tester) async {
    await pumpWithLocale(tester, const Locale('fr'));
    expect(find.text('Arrive dans ~15 min (12–18)'), findsOneWidget);
  });

  test('AppLocalizations.supportedLocales inclut fr/en/wo', () {
    final codes = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll({'fr', 'en', 'wo'}));
  });
}
