// Widget test de l'écran « Arrêts atteints » (Phase 1).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/providers/reached_stops_provider.dart';
import 'package:procolis/screens/driver/advertisement_reached_stops_screen.dart';
import 'package:procolis/services/api/advertisement_extra_api.dart';

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
  const adId = 'test-ad';

  testWidgets('affiche la liste des arrêts atteints', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementReachedStopsScreen(advertisementId: adId),
        overrides: [
          reachedStopsProvider(adId).overrideWith((ref) async =>
              ReachedStopsResult(
                advertisementId: adId,
                transitLineId: 'line',
                reachedStops: [
                  ReachedStopEvent(
                    stopOrder: 0,
                    stopLabel: 'Dakar',
                    distanceMeters: 50,
                    radiusMeters: 300,
                    reachedAt: DateTime(2026, 11, 11, 10, 15),
                  ),
                  const ReachedStopEvent(
                    stopOrder: 1,
                    stopLabel: 'Thiès',
                    distanceMeters: 120,
                    radiusMeters: 300,
                  ),
                ],
              )),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arrêts atteints'), findsOneWidget);
    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Thiès'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
  });

  testWidgets('empty state quand aucun arrêt', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementReachedStopsScreen(advertisementId: adId),
        overrides: [
          reachedStopsProvider(adId).overrideWith(
              (ref) async => const ReachedStopsResult(advertisementId: adId)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun arrêt'), findsOneWidget);
  });

  testWidgets('error state + retry', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AdvertisementReachedStopsScreen(advertisementId: adId),
        overrides: [
          reachedStopsProvider(adId).overrideWith((ref) async {
            throw Exception('boom');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chargement impossible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('loading via Completer non résolu', (tester) async {
    final pending = Completer<ReachedStopsResult>();
    await tester.pumpWidget(
      _wrap(
        const AdvertisementReachedStopsScreen(advertisementId: adId),
        overrides: [
          reachedStopsProvider(adId).overrideWith((ref) => pending.future),
        ],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const ReachedStopsResult(advertisementId: adId));
    await tester.pumpAndSettle();
  });
}
