import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('démarre à null (langue système)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(localeProvider), isNull);
  });

  test('restaure la langue persistée au démarrage', () async {
    SharedPreferences.setMockInitialValues({'app.locale': 'wo'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Le chargement passe par deux microtasks (getInstance + getString).
    // On attend jusqu'à ce que state change, avec un timeout court.
    for (var i = 0; i < 20; i++) {
      if (container.read(localeProvider) != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(localeProvider), const Locale('wo'));
  });

  test('set persiste la préférence', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(localeProvider.notifier).set(const Locale('en'));
    expect(container.read(localeProvider), const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app.locale'), 'en');
  });

  test('set(null) retire la préférence', () async {
    SharedPreferences.setMockInitialValues({'app.locale': 'fr'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    await container.read(localeProvider.notifier).set(null);
    expect(container.read(localeProvider), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app.locale'), isNull);
  });

  test('ignore une locale non supportée', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(localeProvider.notifier).set(const Locale('de'));
    expect(container.read(localeProvider), isNull);
  });
}
