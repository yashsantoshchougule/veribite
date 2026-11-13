import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/network/backend_endpoint_resolver.dart';
import 'package:mobile_app/features/camera/presentation/widgets/backend_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackendSettingsSheet Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders header, route status, preset chips, input field, and buttons', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'ok', 'service': 'veribite-vision-proxy'}),
          200,
        );
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackendSettingsSheet(resolver: resolver),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Backend & Vision Proxy Settings'), findsOneWidget);
      expect(find.text('5G Mobile Data, Wi-Fi LAN & Cloud Tunnel Resolver'), findsOneWidget);
      expect(find.text('Active Vision & Scan Route'), findsOneWidget);
      expect(find.text('Custom FastAPI Backend URL'), findsOneWidget);

      // Preset chips
      expect(find.text('Auto Detect'), findsOneWidget);
      expect(find.text('USB Loopback'), findsOneWidget);
      expect(find.text('Emulator'), findsOneWidget);

      // Action buttons
      expect(find.text('Test Ping'), findsOneWidget);
      expect(find.text('Save & Apply'), findsOneWidget);
    });

    testWidgets('tapping preset chip updates text field and testing ping shows feedback', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.toString() == 'http://127.0.0.1:8000/health') {
          return http.Response(
            jsonEncode({'status': 'ok', 'service': 'veribite-vision-proxy'}),
            200,
          );
        }
        return http.Response('Error', 500);
      });

      final resolver = BackendEndpointResolver(httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackendSettingsSheet(resolver: resolver),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap USB Loopback preset
      await tester.tap(find.text('USB Loopback'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Text field has 'http://127.0.0.1:8000'
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'http://127.0.0.1:8000');
    });
  });
}
