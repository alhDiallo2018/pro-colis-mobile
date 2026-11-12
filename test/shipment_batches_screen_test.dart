// Widget test de l'écran liste des lots B2B (Phase 4).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:procolis/l10n/generated/app_localizations.dart';
import 'package:procolis/providers/shipment_batch_provider.dart';
import 'package:procolis/screens/shipper/shipment_batches_screen.dart';
import 'package:procolis/services/api/shipment_batch_api.dart';

Widget _wrap(Widget child, {required List<Override> overrides}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (c, s) => child),
      GoRoute(path: '/shipment-batches/:id',
          builder: (c, s) => const Scaffold(body: Text('detail'))),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  testWidgets('affiche la liste des lots', (tester) async {
    final batches = [
      ShipmentBatch(
        id: 'b1',
        creatorId: 'u1',
        label: 'Lot A',
        status: 'open',
        totalParcels: 3,
        totalWeightKg: 12.5,
      ),
      ShipmentBatch(
        id: 'b2',
        creatorId: 'u1',
        reference: 'REF-002',
        status: 'draft',
      ),
    ];
    await tester.pumpWidget(
      _wrap(
        const ShipmentBatchesScreen(),
        overrides: [
          shipmentBatchesListProvider.overrideWith((ref) async => batches),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mes lots d\'expédition'), findsOneWidget);
    expect(find.text('Lot A'), findsOneWidget);
    expect(find.text('REF-002'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ShipmentBatchesScreen(),
        overrides: [
          shipmentBatchesListProvider.overrideWith((ref) async => <ShipmentBatch>[]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun lot'), findsOneWidget);
  });

  testWidgets('loading state (Completer non résolu)', (tester) async {
    final pending = Completer<List<ShipmentBatch>>();
    await tester.pumpWidget(
      _wrap(
        const ShipmentBatchesScreen(),
        overrides: [
          shipmentBatchesListProvider.overrideWith((ref) => pending.future),
        ],
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('error state + retry', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ShipmentBatchesScreen(),
        overrides: [
          shipmentBatchesListProvider.overrideWith((ref) async {
            throw Exception('boom');
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
