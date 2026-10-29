import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:procolis/widgets/voice_note_field.dart';
import 'package:record/record.dart';

class _Recorder implements AudioRecorder {
  bool permitted = true;
  String? path;
  int starts = 0;
  int pauses = 0;
  int resumes = 0;
  bool disposed = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => permitted;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = path;
    await File(path).writeAsBytes([1, 2, 3]);
  }

  @override
  Future<String?> stop() async => path;
  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Ce double sans IO garde le chronomètre dans l’horloge simulée du test.
class _MemoryRecorder extends _Recorder {
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    starts++;
    this.path = path;
  }
}

class _Player implements AudioPlayer {
  final completion = StreamController<void>.broadcast();
  Source? source;
  int pauses = 0;
  int resumes = 0;
  int plays = 0;
  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Stream<void> get onPlayerComplete => completion.stream;
  @override
  Future<void> play(Source source,
      {double? volume,
      double? balance,
      AudioContext? ctx,
      Duration? position,
      PlayerMode? mode}) async {
    plays++;
    this.source = source;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await completion.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Les lectures/effacements du fichier audio nécessitent la vraie boucle IO,
// contrairement aux animations et au chronomètre simulés par WidgetTester.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.runAsync(() async {
    await tester.tap(target);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la pause exclut sa durée et peut être finalisée sans reprise',
      (tester) async {
    final recorder = _MemoryRecorder();
    String? saved;
    String? uploadedPath;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceNoteField(
      recorder: recorder,
      onChanged: (value) => saved = value,
      onBusyChanged: (_) {},
      upload: (file) async {
        uploadedPath = file.path;
        return '/uploads/vocal.m4a';
      },
    ))));
    await tester.tap(find.text('Enregistrer une note vocale'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Enregistrement · 00:02'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(find.text('En pause · 00:02'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Enregistrement · 00:04'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await _tap(tester, find.text('Terminer'));
    expect(saved, '/uploads/vocal.m4a');
    expect(uploadedPath, recorder.path);
    expect(recorder.starts, 1);
    expect(recorder.resumes, 1);
  });

  testWidgets('micro refusé : message explicite sans bloquer le formulaire',
      (tester) async {
    final recorder = _Recorder()..permitted = false;
    var busy = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceNoteField(
      recorder: recorder,
      onChanged: (_) => fail('Aucune note ne doit être créée'),
      onBusyChanged: (value) => busy = value,
    ))));
    await _tap(tester, find.text('Enregistrer une note vocale'));
    expect(find.textContaining('Autorisez le microphone'), findsOneWidget);
    expect(recorder.starts, 0);
    expect(busy, false);
  });

  testWidgets('enregistre, met en pause, réessaie l’upload et écoute la note',
      (tester) async {
    final recorder = _Recorder();
    final player = _Player();
    String? value;
    var busy = false;
    var uploads = 0;
    final paths = <String>[];
    final payloads = <List<int>>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => VoiceNoteField(
        value: value,
        recorder: recorder,
        player: player,
        onChanged: (url) => setState(() => value = url),
        onBusyChanged: (value) => busy = value,
        upload: (XFile file) async {
          uploads++;
          paths.add(file.path);
          payloads.add(await file.readAsBytes());
          return uploads == 1 ? null : '/uploads/note-voyage.m4a';
        },
      ),
    ))));
    await _tap(tester, find.text('Enregistrer une note vocale'));
    expect(busy, true);
    await _tap(tester, find.text('Pause'));
    expect(recorder.pauses, 1);
    await _tap(tester, find.text('Reprendre'));
    expect(recorder.resumes, 1);
    await _tap(tester, find.text('Terminer'));
    expect(find.text('Réessayer'), findsOneWidget);
    expect(value, isNull);
    expect(busy, true, reason: 'une note non envoyée ne doit pas être publiée');
    await _tap(tester, find.text('Réessayer'));
    expect(value, '/uploads/note-voyage.m4a');
    expect(busy, false);
    expect(recorder.starts, 1);
    expect(paths[0], paths[1]);
    expect(payloads, [
      [1, 2, 3],
      [1, 2, 3]
    ]);
    expect(await tester.runAsync(() => File(paths[0]).exists()), false);
    await _tap(tester, find.text('Écouter'));
    expect(
        (player.source as UrlSource).url, endsWith('/uploads/note-voyage.m4a'));
    await _tap(tester, find.text('Pause'));
    expect(player.pauses, 1);
    await _tap(tester, find.text('Reprendre'));
    expect(player.resumes, 1);
    expect(player.plays, 1, reason: 'La reprise ne recharge pas le fichier');
    await _tap(tester, find.byTooltip('Supprimer la note vocale'));
    expect(value, isNull);
    expect(find.text('Enregistrer une note vocale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'annule une prise sans upload et libère le microphone à la fermeture',
      (tester) async {
    final recorder = _Recorder();
    var busy = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VoiceNoteField(
      recorder: recorder,
      onChanged: (url) => expect(url, isNull),
      onBusyChanged: (value) => busy = value,
      upload: (_) async => throw StateError('Ne doit pas téléverser'),
    ))));
    await _tap(tester, find.text('Enregistrer une note vocale'));
    await _tap(tester, find.byTooltip('Supprimer la note vocale'));
    expect(busy, false);
    expect(await tester.runAsync(() => File(recorder.path!).exists()), false);
    await _tap(tester, find.text('Enregistrer une note vocale'));
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
    expect(recorder.disposed, true);
    expect(await tester.runAsync(() => File(recorder.path!).exists()), false);
    expect(tester.takeException(), isNull);
  });
}
