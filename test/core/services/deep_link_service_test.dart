import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/services/deep_link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeepLinkService URL Builders', () {
    test('buildTobaccoShareUrl genera URL HTTPS oficial para web y mensajería', () {
      const tobaccoId = 'tobacco-uuid-1234';
      final url = DeepLinkService.buildTobaccoShareUrl(tobaccoId);

      expect(url, 'https://hookahub.manutech.duckdns.org/share/tobacco?id=tobacco-uuid-1234');
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'hookahub.manutech.duckdns.org');
      expect(uri.pathSegments, contains('tobacco'));
      expect(uri.queryParameters['id'], tobaccoId);
    });

    test('buildMixShareUrl genera URL HTTPS oficial para web y mensajería', () {
      const mixId = 'mix-uuid-5678';
      final url = DeepLinkService.buildMixShareUrl(mixId);

      expect(url, 'https://hookahub.manutech.duckdns.org/share/mix?id=mix-uuid-5678');
      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'hookahub.manutech.duckdns.org');
      expect(uri.pathSegments, contains('mix'));
      expect(uri.queryParameters['id'], mixId);
    });

    test('buildNativeTobaccoUri y buildNativeMixUri generan esquemas nativos hookahub://', () {
      expect(
        DeepLinkService.buildNativeTobaccoUri('123'),
        'hookahub://share/tobacco?id=123',
      );
      expect(
        DeepLinkService.buildNativeMixUri('456'),
        'hookahub://share/mix?id=456',
      );
    });
  });

  group('DeepLinkService URI Handling Validation', () {
    test('handleUri ignora dominios y esquemas no autorizados', () async {
      final service = DeepLinkService.instance;
      // No debe lanzar excepciones ni procesar
      await service.handleUri(Uri.parse('https://external-domain.com/share/mix?id=123'));
      await service.handleUri(Uri.parse('io.supabase.flutter://login-callback'));
    });

    test('handleUri acepta dominio web oficial hookahub.manutech.duckdns.org y esquema nativo', () async {
      final service = DeepLinkService.instance;
      // Valida y descarta adecuadamente si no hay ID sin lanzar excepciones
      await service.handleUri(Uri.parse('https://hookahub.manutech.duckdns.org/share/tobacco?id='));
      await service.handleUri(Uri.parse('hookahub://share/mix?id='));
    });

    test('handleUri ignora deep links con ID ausente o vacío', () async {
      final service = DeepLinkService.instance;
      // No debe lanzar excepciones
      await service.handleUri(Uri.parse('hookahub://share/tobacco'));
      await service.handleUri(Uri.parse('https://hookahub.manutech.duckdns.org/share/mix'));
      await service.handleUri(Uri.parse('hookahub://share/unknown?id=123'));
    });
  });
}
