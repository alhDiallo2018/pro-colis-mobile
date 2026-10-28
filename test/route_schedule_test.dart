import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/models/route_schedule.dart';
import 'package:procolis/services/route_schedule_store.dart';

void main() {
  test('50 départs reprennent les arrêts côté serveur et alternent les sens',
      () {
    final first = DateTime.utc(2027, 1, 2, 6);
    final plans = buildRouteDepartures(
        first: first,
        count: 50,
        intervalMinutes: 10,
        durationMinutes: 10,
        alternate: true);
    expect(plans.length, 50);
    expect(plans[0]['reverse'], false);
    expect(plans[1]['reverse'], true);
    expect(plans.last['departureAt'],
        first.add(const Duration(minutes: 490)).toIso8601String());
    expect(plans.every((p) => !p.containsKey('stops')), true);
  });
  test(
      'le premier trajet peut être un retour et les horaires ne se chevauchent pas',
      () {
    final plans = buildRouteDepartures(
        first: DateTime.utc(2027),
        count: 2,
        intervalMinutes: 60,
        durationMinutes: 60,
        reverseFirst: true,
        alternate: true);
    expect(plans.map((p) => p['reverse']).toList(), [true, false]);
    expect(
        () => buildRouteDepartures(
            first: DateTime.utc(2027),
            count: 50,
            intervalMinutes: 5,
            durationMinutes: 10),
        throwsFormatException);
    expect(
        () => buildRouteDepartures(
            first: DateTime.utc(2027),
            count: 101,
            intervalMinutes: 10,
            durationMinutes: 10),
        throwsFormatException);
  });
  test(
      'la demande conserve son identifiant après réouverture et reste isolée par compte',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = RouteScheduleStore('driver-a');
    final pending = {
      'template': {'id': 'route'},
      'payload': {
        'requestId': 'stable-request',
        'departures': [
          {'departureAt': '2027-01-02T06:00:00Z', 'reverse': false}
        ]
      }
    };
    await store.save(pending);
    expect(await RouteScheduleStore('driver-a').load(), pending);
    expect(await RouteScheduleStore('driver-b').load(), isNull);
    await store.clear();
    expect(await store.load(), isNull);
  });
}
