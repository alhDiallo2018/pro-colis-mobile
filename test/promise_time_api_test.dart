import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api/promise_time_api.dart';

void main() {
  group('PromiseSlot.fromJson', () {
    test('parse un slot valide', () {
      final slot = PromiseSlot.fromJson({
        'id': 'morning-2026-11-12',
        'slotId': 'morning',
        'label': 'Matin',
        'dayOffset': 1,
        'startAt': '2026-11-12T08:00:00Z',
        'endAt': '2026-11-12T12:00:00Z',
      });
      expect(slot, isNotNull);
      expect(slot!.slotId, 'morning');
      expect(slot.dayOffset, 1);
    });

    test('retourne null si dates manquantes', () {
      expect(PromiseSlot.fromJson({'id': 'x', 'slotId': 'morning'}), isNull);
    });

    test('retourne null si payload non-Map', () {
      expect(PromiseSlot.fromJson(null), isNull);
      expect(PromiseSlot.fromJson('not a map'), isNull);
    });
  });

  group('PromiseSlot.humanDayLabel', () {
    PromiseSlot slot({int dayOffset = 0}) => PromiseSlot(
          id: 'x',
          slotId: 'morning',
          label: 'Matin',
          dayOffset: dayOffset,
          startAt: DateTime(2026, 11, 15, 8),
          endAt: DateTime(2026, 11, 15, 12),
        );

    test("dayOffset 0 → Aujourd'hui", () {
      expect(slot(dayOffset: 0).humanDayLabel(), "Aujourd'hui");
    });

    test('dayOffset 1 → Demain', () {
      expect(slot(dayOffset: 1).humanDayLabel(), 'Demain');
    });

    test('dayOffset 2 → DD/MM', () {
      expect(slot(dayOffset: 2).humanDayLabel(), '15/11');
    });
  });
}
