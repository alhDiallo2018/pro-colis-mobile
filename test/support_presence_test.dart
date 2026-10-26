import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/notification_navigation.dart';
import 'package:procolis/widgets/support_presence_monitor.dart';

class _PresenceApi extends ApiService {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> supportChatRequest(String path,
      {Map<String, dynamic>? data}) async {
    calls.add(Map.of(data!));
    return {'success': true};
  }
}

class _Auth extends AuthNotifier {
  void connect(UserRole role) => state = AuthState.authenticated(User(
      id: 'support-test',
      email: '',
      phone: '',
      fullName: 'Support test',
      role: role,
      createdAt: DateTime(2026)));
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<(_Auth, _PresenceApi, ProviderContainer)> mount(
      WidgetTester tester, UserRole role) async {
    final auth = _Auth();
    final api = _PresenceApi();
    final container = ProviderContainer(
        overrides: [authProvider.overrideWith((ref) => auth)]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: SupportPresenceMonitor(api: api, child: const SizedBox()))));
    await tester.pumpAndSettle();
    auth.connect(role);
    await tester.pumpAndSettle();
    addTearDown(container.dispose);
    return (auth, api, container);
  }

  testWidgets(
      'un support spécialisé publie puis libère sa présence en arrière-plan',
      (tester) async {
    final (_, api, _) = await mount(tester, UserRole.supportTechnique);
    expect(api.calls.last['available'], true);
    final connection = api.calls.last['connectionId'];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(api.calls.last, {'connectionId': connection, 'available': false});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.calls.last['available'], true);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('le choix indisponible est conservé pendant les renouvellements',
      (tester) async {
    final (_, api, container) = await mount(tester, UserRole.supportCommercial);
    container.read(supportAvailabilityProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(api.calls.last['available'], false);
    await tester.pump(const Duration(seconds: 21));
    expect(api.calls.last['available'], false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('un client ne se déclare jamais agent disponible',
      (tester) async {
    final (_, api, _) = await mount(tester, UserRole.client);
    await tester.pump(const Duration(seconds: 21));
    expect(api.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('les notifications de reprise ouvrent le support', () {
    expect(NotificationNavigation.routeFor('support_chat', null, null),
        '/support');
  });
}
