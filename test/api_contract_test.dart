import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/config/app_config.dart';
import 'package:procolis/services/api/client.dart';

void main() {
  group('configuration API partagée', () {
    test('construit un lien de suivi valide et encodé', () {
      expect(
        AppConfig.trackingUrl('PC 2026/001'),
        '${AppConfig.publicAppUrl}/track/PC%202026%2F001',
      );
    });

    test('résout les médias depuis la même origine que l’API', () {
      expect(
        AppConfig.resolveMediaUrl('/uploads/proof.jpg'),
        '${AppConfig.mediaBaseUrl}/uploads/proof.jpg',
      );
      expect(
        AppConfig.resolveMediaUrl('https://cdn.example/proof.jpg'),
        'https://cdn.example/proof.jpg',
      );
    });

    test('ne double pas les intercepteurs d’un Dio déjà configuré', () {
      final dio = Dio();
      final interceptorCount = dio.interceptors.length;

      ApiClient(dioOverride: dio);

      expect(dio.interceptors.length, interceptorCount);
    });
  });
}
