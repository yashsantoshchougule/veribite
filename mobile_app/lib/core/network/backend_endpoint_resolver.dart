import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Active Vision Route description for UI display
enum VisionRouteType {
  directGeminiHttps,
  customBackendProxy,
  cloudBackendProxy,
  localUsbReverse,
  localEmulator,
  onDeviceOfflineOcr,
}

/// Dynamic Multi-Endpoint Backend Resolver
/// Eliminates hardcoded `http://10.0.2.2:8000` and dynamically resolves
/// Cloud, LAN, USB, and Emulator endpoints with fast 1000ms probes, session caching,
/// and instant loopback dead-marking on physical 5G/Wi-Fi devices.
class BackendEndpointResolver {
  static BackendEndpointResolver? _instance;
  static BackendEndpointResolver get instance => _instance ??= BackendEndpointResolver();

  static const String prefsCustomUrlKey = 'custom_backend_url';
  static const String _compileTimeBackendUrl = String.fromEnvironment('VERIBITE_BACKEND_URL');

  final http.Client _client;

  // Session cache: resolved healthy endpoint for zero-overhead repeat requests
  String? _cachedEndpoint;
  bool _loopbacksProbedAndUnavailable = false;
  VisionRouteType _activeRouteType = VisionRouteType.directGeminiHttps;

  BackendEndpointResolver({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  /// Visible active route type
  VisionRouteType get activeRouteType => _activeRouteType;

  /// Human-readable active route description
  String get activeRouteDescription {
    switch (_activeRouteType) {
      case VisionRouteType.directGeminiHttps:
        return 'Direct Gemini Multimodal (HTTPS)';
      case VisionRouteType.customBackendProxy:
        return 'Custom Developer Proxy (${_cachedEndpoint ?? "Configured"})';
      case VisionRouteType.cloudBackendProxy:
        return 'Cloud Vision Proxy (${_cachedEndpoint ?? "Cloud"})';
      case VisionRouteType.localUsbReverse:
        return 'USB Tethered Proxy (127.0.0.1:8000)';
      case VisionRouteType.localEmulator:
        return 'Android Emulator Proxy (10.0.2.2:8000)';
      case VisionRouteType.onDeviceOfflineOcr:
        return 'On-Device Vision Engine (Offline OCR)';
    }
  }

  /// Resolve the active backend base URL (without trailing slash)
  /// using the 4-tier priority chain.
  /// If no backend is reachable, returns `null` instantly without blocking.
  Future<String?> resolveActiveBackendUrl({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedEndpoint != null) {
      return _cachedEndpoint;
    }

    // Tier 1: User / Developer Custom Override in SharedPreferences
    final customUrl = await getCustomBackendUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      final normalized = _normalizeUrl(customUrl);
      final latency = await pingHealth(normalized);
      if (latency >= 0) {
        _cachedEndpoint = normalized;
        _activeRouteType = VisionRouteType.customBackendProxy;
        debugPrint('[BackendEndpointResolver] Resolved custom backend: $normalized ($latency ms)');
        return normalized;
      } else {
        debugPrint('[BackendEndpointResolver] Custom backend $normalized failed health check.');
      }
    }

    // Tier 2: Compile-Time Cloud / Production URL
    if (_compileTimeBackendUrl.isNotEmpty) {
      final normalized = _normalizeUrl(_compileTimeBackendUrl);
      final latency = await pingHealth(normalized);
      if (latency >= 0) {
        _cachedEndpoint = normalized;
        _activeRouteType = VisionRouteType.cloudBackendProxy;
        debugPrint('[BackendEndpointResolver] Resolved compile-time cloud backend: $normalized ($latency ms)');
        return normalized;
      }
    }

    // If loopbacks were already probed in this session and failed, skip instantly!
    // This guarantees physical phones on 5G NEVER wait on dead loopbacks!
    if (_loopbacksProbedAndUnavailable && !forceRefresh) {
      _activeRouteType = VisionRouteType.onDeviceOfflineOcr;
      return null;
    }

    // Tier 3: USB Reverse Tethering Loopback (http://127.0.0.1:8000)
    const usbLoopback = 'http://127.0.0.1:8000';
    final usbLatency = await pingHealth(usbLoopback);
    if (usbLatency >= 0) {
      _cachedEndpoint = usbLoopback;
      _activeRouteType = VisionRouteType.localUsbReverse;
      debugPrint('[BackendEndpointResolver] Resolved USB reverse proxy: $usbLoopback ($usbLatency ms)');
      return usbLoopback;
    }

    // Tier 4: Android Emulator Loopback (http://10.0.2.2:8000)
    const emulatorLoopback = 'http://10.0.2.2:8000';
    final emuLatency = await pingHealth(emulatorLoopback);
    if (emuLatency >= 0) {
      _cachedEndpoint = emulatorLoopback;
      _activeRouteType = VisionRouteType.localEmulator;
      debugPrint('[BackendEndpointResolver] Resolved Android emulator proxy: $emulatorLoopback ($emuLatency ms)');
      return emulatorLoopback;
    }

    // Neither USB nor Emulator loopback is reachable (standard physical phone on 5G/Wi-Fi)
    _loopbacksProbedAndUnavailable = true;
    _cachedEndpoint = null;
    _activeRouteType = VisionRouteType.onDeviceOfflineOcr;
    debugPrint('[BackendEndpointResolver] No local or cloud backend proxy reachable. Marked loopback unavailable.');
    return null;
  }

  /// Fast reachability probe: GET /health with a strict 1000ms timeout
  /// Returns response time in milliseconds, or -1 if unreachable or timed out.
  Future<int> pingHealth(String baseUrl) async {
    final cleanUrl = _normalizeUrl(baseUrl);
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$cleanUrl/health');
      final response = await _client.get(uri).timeout(const Duration(milliseconds: 1000));
      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {
      // Unreachable, socket timeout, or connection refused
    }
    return -1;
  }

  /// Test an arbitrary user-entered URL and return latency in ms, or -1 on error
  Future<int> testEndpoint(String url) async {
    return pingHealth(url);
  }

  /// Persist custom backend URL in SharedPreferences
  Future<void> setCustomBackendUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(prefsCustomUrlKey);
    } else {
      await prefs.setString(prefsCustomUrlKey, url.trim());
    }
    // Invalidate cached endpoint and reset loopback probe flag
    _cachedEndpoint = null;
    _loopbacksProbedAndUnavailable = false;
    await resolveActiveBackendUrl(forceRefresh: true);
  }

  /// Read custom backend URL from SharedPreferences
  Future<String?> getCustomBackendUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(prefsCustomUrlKey);
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Clear session cache (e.g. on network change or refresh)
  void clearSessionCache() {
    _cachedEndpoint = null;
    _loopbacksProbedAndUnavailable = false;
  }

  /// Strips trailing slashes
  String _normalizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
