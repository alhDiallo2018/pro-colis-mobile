import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/widgets/voice_recording_controls.dart';
import 'package:record/record.dart';

class _Recorder implements AudioRecorder {
  int pauses = 0;
  int resumes = 0;
  Completer<void>? pendingPause;
  bool failPause = false;

  @override
  Future<void> pause() async {
    pauses++;
    if (failPause) throw StateError('Microphone indisponible');
    await pendingPause?.future;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(WidgetTester tester, _Recorder recorder,
    {Future<void> Function()? finish, List<bool>? busy}) async {
  var paused = false;
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: StatefulBuilder(
    builder: (context, setState) => VoiceRecordingControls(
      recorder: recorder,
      seconds: 12,
      paused: paused,
      onPausedChanged: (value) => setState(() => paused = value),
      onBusyChanged: (value) => busy?.add(value),
      onFinish: finish ?? () async {},
    ),
  ))));
}

void main() {
  testWidgets('pause puis reprise du même enregistrement', (tester) async {
    final recorder = _Recorder();
    await _mount(tester, recorder);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('En pause · 00:12'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    await tester.pump();
    expect(recorder.pauses, 1);
    expect(recorder.resumes, 1);
    expect(find.text('Enregistrement · 00:12'), findsOneWidget);
  });

  testWidgets('termine directement une prise en pause et libère le parent',
      (tester) async {
    final recorder = _Recorder();
    final busy = <bool>[];
    var finished = 0;
    await _mount(tester, recorder, busy: busy, finish: () async {
      finished++;
    });
    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.tap(find.text('Terminer'));
    await tester.pump();
    expect(finished, 1);
    expect(recorder.resumes, 0);
    expect(busy, [true, false, true, false]);
  });

  testWidgets('ignore les appuis concurrents pendant la pause native',
      (tester) async {
    final recorder = _Recorder()..pendingPause = Completer<void>();
    var finished = 0;
    await _mount(tester, recorder, finish: () async {
      finished++;
    });
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Terminer'));
    expect(recorder.pauses, 1);
    expect(finished, 0);
    recorder.pendingPause!.complete();
    await tester.pump();
    expect(find.text('Reprendre'), findsOneWidget);
  });

  testWidgets('échec natif : conserve l’état et permet de réessayer',
      (tester) async {
    final recorder = _Recorder()..failPause = true;
    await _mount(tester, recorder);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Enregistrement · 00:12'), findsOneWidget);
    expect(find.text('Action impossible. Réessayez.'), findsOneWidget);
    recorder.failPause = false;
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('En pause · 00:12'), findsOneWidget);
  });

  testWidgets('contrôles lisibles à 280 pixels avec texte agrandi',
      (tester) async {
    tester.view.physicalSize = const Size(280, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: VoiceRecordingControls(
        recorder: _Recorder(),
        seconds: 123,
        paused: true,
        onPausedChanged: (_) {},
        onBusyChanged: (_) {},
        onFinish: () async {},
      ),
    ))));
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
