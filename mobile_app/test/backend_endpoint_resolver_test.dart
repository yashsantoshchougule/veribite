import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/network/backend_endpoint_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackendEndpointResolver Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('resolves custom backend URL when saved in SharedPreferences and healthy', () async {
      SharedPreferences.setMockInitialValues({
        BackendEndpointResolver.prefsCustomUrlKey: 'http://192.168.1.55:8000',
      });

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'http://192.168.1.55:8000/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'veribite-vision-proxy'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      final resolved = await resolver.resolveActiveBackendUrl(forceRefresh: true);

      expect(resolved, 'http://192.168.1.55:8000');
      expect(resolver.activeRouteType, VisionRouteType.customBackendProxy);
      expect(resolver.activeRouteDescription, contains('192.168.1.55:8000'));
    });

    test('falls back to USB 127.0.0.1:8000 when custom URL is not configured and USB is healthy', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'http://127.0.0.1:8000/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'veribite-vision-proxy'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Connection Refused', 500);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      final resolved = await resolver.resolveActiveBackendUrl(forceRefresh: true);

      expect(resolved, 'http://127.0.0.1:8000');
      expect(resolver.activeRouteType, VisionRouteType.localUsbReverse);
      expect(resolver.activeRouteDescription, contains('127.0.0.1:8000'));
    });

    test('falls back to Android emulator 10.0.2.2:8000 when USB is dead but emulator is healthy', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'http://10.0.2.2:8000/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'veribite-vision-proxy'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Connection Refused', 500);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      final resolved = await resolver.resolveActiveBackendUrl(forceRefresh: true);

      expect(resolved, 'http://10.0.2.2:8000');
      expect(resolver.activeRouteType, VisionRouteType.localEmulator);
      expect(resolver.activeRouteDescription, contains('10.0.2.2:8000'));
    });

    test('marks loopback unavailable and returns null without hanging when all endpoints fail probe', () async {
      SharedPreferences.setMockInitialValues({});

      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable (untethered 5G physical phone)');
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      final resolved = await resolver.resolveActiveBackendUrl(forceRefresh: true);

      expect(resolved, isNull);
      expect(resolver.activeRouteType, VisionRouteType.onDeviceOfflineOcr);
      expect(resolver.activeRouteDescription, contains('Offline OCR'));

      // Subsequent call without forceRefresh returns null instantly without probing network again
      final cached = await resolver.resolveActiveBackendUrl(forceRefresh: false);
      expect(cached, isNull);
    });

    test('testEndpoint measures positive latency on 200 OK and returns -1 on error', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response('{"status": "ok"}', 200);
        }
        return http.Response('Error', 500);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      final latency = await resolver.testEndpoint('http://custom-host:8000');
      expect(latency, greaterThanOrEqualTo(0));

      final badLatency = await resolver.testEndpoint('http://bad-host:8000/error');
      expect(badLatency, -1);
    });

    test('setCustomBackendUrl saves to SharedPreferences and refreshes active endpoint', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"status": "ok"}', 200);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);
      await resolver.setCustomBackendUrl('http://192.168.0.120:8000');

      final saved = await resolver.getCustomBackendUrl();
      expect(saved, 'http://192.168.0.120:8000');

      // Clear custom URL
      await resolver.setCustomBackendUrl(null);
      final cleared = await resolver.getCustomBackendUrl();
      expect(cleared, isNull);
    });
  });
}
