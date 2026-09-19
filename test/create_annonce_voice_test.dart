import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:procolis/providers/advertisement_provider.dart';
import 'package:procolis/screens/driver/create_annonce_sheet.dart';
import 'package:procolis/services/form_draft_store.dart';
import 'package:procolis/widgets/voice_note_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/mock_http.dart';

class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Advertisements extends AdvertisementNotifier {
  final creates = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  bool succeeds = true;

  @override
  Future<Map<String, dynamic>> createAdvertisement(
      Map<String, dynamic> data) async {
    creates.add(data);
    return {'success': succeeds, 'message': 'Publication refusée'};
  }

  @override
  Future<Map<String, dynamic>> updateAdvertisement(
      String id, Map<String, dynamic> data) async {
    updates.add(data);
    return {'success': true};
  }
}

Future<void> _open(WidgetTester tester, _Advertisements notifier,
    {Map<String, dynamic>? existing}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [advertisementProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () {
                        if (existing == null) {
                          showCreateAnnonceSheet(context);
                        } else {
                          showEditAnnonceSheet(context, existing);
                        }
                      },
                      child: const Text('ouvrir')),
                ))),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides? previousHttp;
  late PathProviderPlatform previousPaths;
  late Directory testDocuments;
  setUpAll(() {
    previousPaths = PathProviderPlatform.instance;
    testDocuments = Directory.systemTemp.createTempSync('procolis-voice-test-');
    PathProviderPlatform.instance = _Paths(testDocuments.path);
    previousHttp = HttpOverrides.current;
    HttpOverrides.global = MockHttpOverrides();
  });
  tearDownAll(() {
    HttpOverrides.global = previousHttp;
    PathProviderPlatform.instance = previousPaths;
    testDocuments.deleteSync(recursive: true);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('fermer sans reprendre préserve le brouillon proposé',
      (tester) async {
    await FormDraftStore(slot: 'annonce')
        .save({'step': 1, 'audioUrl': '/uploads/en-attente.m4a'});
    await _open(tester, _Advertisements());
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect((await FormDraftStore(slot: 'annonce').load())!.data['audioUrl'],
        '/uploads/en-attente.m4a');
  });

  testWidgets('conserve une note dans le brouillon puis la reprend',
      (tester) async {
    await FormDraftStore(slot: 'annonce')
        .save({'step': 1, 'description': 'Voyage'});
    await _open(tester, _Advertisements());
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    expect(find.text('Note vocale (optionnel)'), findsOneWidget);
    // La capture/upload est couverte par voice_note_field_test ; ici on vérifie
    // que le formulaire conserve bien l'URL rendue par ce composant.
    tester
        .widget<VoiceNoteField>(find.byType(VoiceNoteField))
        .onChanged('/uploads/voyage.m4a');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garder le brouillon'));
    await tester.pumpAndSettle();
    expect((await FormDraftStore(slot: 'annonce').load())!.data['audioUrl'],
        '/uploads/voyage.m4a');
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    expect(tester.widget<VoiceNoteField>(find.byType(VoiceNoteField)).value,
        '/uploads/voyage.m4a');
  });

  testWidgets(
      'publie audioUrl, bloque une prise en cours et conserve la note après refus',
      (tester) async {
    await FormDraftStore(slot: 'annonce').save({
      'step': 1,
      'departureZoneId': 'dakar',
      'arrivalZoneId': 'thies',
      'audioUrl': '/uploads/voyage.m4a',
    });
    final notifier = _Advertisements()..succeeds = false;
    await _open(tester, notifier);
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    final field = tester.widget<VoiceNoteField>(find.byType(VoiceNoteField));
    field.onBusyChanged(true);
    await tester.pump();
    await tester.tap(find.text('Publier l’annonce'));
    await tester.pumpAndSettle();
    expect(notifier.creates, isEmpty);
    field.onBusyChanged(false);
    await tester.pump();
    await tester.tap(find.text('Publier l’annonce'));
    await tester.pumpAndSettle();
    expect(notifier.creates.single['audioUrl'], '/uploads/voyage.m4a');
    expect(tester.widget<VoiceNoteField>(find.byType(VoiceNoteField)).value,
        '/uploads/voyage.m4a');
    notifier.succeeds = true;
    await tester.tap(find.text('Publier l’annonce'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceNoteField), findsNothing);
    expect(await FormDraftStore(slot: 'annonce').load(), isNull);
  });

  testWidgets('retirer la note d’une annonce existante envoie audioUrl null',
      (tester) async {
    final notifier = _Advertisements();
    await _open(tester, notifier, existing: {
      'id': 'voyage-1',
      'departureZoneId': 'dakar',
      'arrivalZoneId': 'thies',
      'audioUrl': '/uploads/existant.m4a',
    });
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(tester.widget<VoiceNoteField>(find.byType(VoiceNoteField)).value,
        '/uploads/existant.m4a');
    await tester.ensureVisible(find.byTooltip('Supprimer la note vocale'));
    await tester.tap(find.byTooltip('Supprimer la note vocale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(notifier.updates.single, {'audioUrl': null});
  });

  testWidgets('supprimer la seule note efface aussi son brouillon',
      (tester) async {
    await FormDraftStore(slot: 'annonce')
        .save({'step': 1, 'audioUrl': '/uploads/seule.m4a'});
    await _open(tester, _Advertisements());
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Supprimer la note vocale'));
    await tester.tap(find.byTooltip('Supprimer la note vocale'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceNoteField), findsNothing);
    expect(await FormDraftStore(slot: 'annonce').load(), isNull);
  });
}
