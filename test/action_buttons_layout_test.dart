import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/pc_components.dart';

void main() {
  setUpAll(() async {
    for (final name in ['PlusJakartaSans', 'Manrope']) {
      final loader = FontLoader(name)
        ..addFont(rootBundle.load('fonts/$name/$name-Variable.ttf'));
      await loader.load();
    }
  });
  for (final width in [240.0, 320.0, 360.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('actions complètes à ${width}px, texte ×$scale',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                    width: width,
                    child: PcActionButtons(children: [
                      PcButton('Refuser',
                          variant: PcButtonVariant.danger,
                          size: PcButtonSize.sm,
                          onPressed: () {}),
                      PcButton('Contre-proposer',
                          variant: PcButtonVariant.secondary,
                          size: PcButtonSize.sm,
                          onPressed: () {}),
                      PcButton('Accepter',
                          icon: Icons.check,
                          size: PcButtonSize.sm,
                          onPressed: () {}),
                    ])),
              ),
            )));
        expect(tester.takeException(), isNull);
        for (final label in ['Refuser', 'Contre-proposer', 'Accepter']) {
          final paragraph =
              tester.renderObject<RenderParagraph>(find.text(label));
          expect(paragraph.didExceedMaxLines, false, reason: label);
          expect(
              paragraph
                  .getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: label.length))
                  .map((box) => box.top)
                  .toSet()
                  .length,
              1,
              reason: label);
        }
      });
    }
  }
}
