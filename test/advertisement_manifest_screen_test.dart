// Widget test de l'écran manifeste navette (SCP-012).
//
// On stub le manifestProvider via `overrideWith` pour contrôler l'état
// AsyncValue (data/loading/error). Le screen doit afficher :
//  - un indicateur de chargement en loading,
//  - les arrêts avec picked/dropOffs en data,
//  - un message d'erreur + bouton réessayer en error.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/providers/manifest_provider.dart';
import 'package:procolis/screens/driver/advertisement_manifest_screen.dart';
import 'package:procolis/services/api/manifest_api.dart';

Widget _wrap(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  const adId = 'test-ad-id';

  AdvertisementManifest buildManifest({int total = 2}) {
    return AdvertisementManifest(
      advertisementId: adId,
      transitLineId: 'line-1',
      totalOffers: total,
      stops: [
        ManifestStop(
          order: 0,
          label: 'Dakar',
          zoneId: 'zone-0',
          picked: [
            const ManifestOfferSummary(id: 'o1', trackingNumber: 'TR001', receiverName: 'Fatou', price: 2500),
            const ManifestOfferSummary(id: 'o2', trackingNumber: 'TR002', receiverName: 'Moussa', price: 3000),
          ],
          dropOffs: const [],
        ),
        const ManifestStop(
          order: 1,
          label: 'Thiès',
          zoneId: 'zone-1',
          picked: [],
          dropOffs: [
            ManifestOfferSummary(id: 'o1', trackingNumber: 'TR001', receiverName: 'Fatou', price: 2500),
          ],
        ),
      ],
    );
  }

  testWidgets('affiche loading initialement', (tester) async {
    // Completer non résolu : garde le provider en état loading sans timer.
    final pending = Completer<AdvertisementManifest>();
    await tester.pumpWidget(
      _wrap(
        const AdvertisementManifestScreen(advertisementId: adId),
        overrides: [
          manifestProvider(adId).overrideWith((ref) => pending.future),
        ],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Résout pour libérer proprement le future avant teardown.
    pending.complete(buildManifest());
    await tester.pumpAndSettle();
  });

  testWidgets('rend les arrêts avec titres et compteurs', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementManifestScreen(advertisementId: adId),
        overrides: [
          manifestProvider(adId).overrideWith((ref) => buildManifest()),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manifeste navette'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Thiès'), findsOneWidget);
    // Chaque arrêt rend aussi ses détails (ExpansionTile ouvert par défaut).
    expect(find.text('TR001'), findsWidgets);
    expect(find.text('Fatou'), findsWidgets);
  });

  testWidgets('affiche message d\'erreur + bouton réessayer', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementManifestScreen(advertisementId: adId),
        overrides: [
          manifestProvider(adId).overrideWith((ref) async {
            throw Exception('boom');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('message « aucun colis » si stops et unassigned vides', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementManifestScreen(advertisementId: adId),
        overrides: [
          manifestProvider(adId).overrideWith((ref) async =>
              const AdvertisementManifest(advertisementId: adId)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun colis'), findsOneWidget);
  });
}
