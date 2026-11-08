import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/network/client_rate_limiter.dart';

void main() {
  group('ClientRateLimiter Tests', () {
    late ClientRateLimiter limiter;

    setUp(() {
      limiter = ClientRateLimiter(
        maxRequestsPerMinute: 3,
        minimumInterval: const Duration(milliseconds: 500),
      );
      limiter.reset();
    });

    test('default instance sets maxRequestsPerMinute to 4 for AI advisor safety', () {
      final defaultLimiter = ClientRateLimiter();
      expect(defaultLimiter.maxRequestsPerMinute, equals(4));
    });

    test('allows requests within limit and minimum interval', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(limiter.canSendRequest(t0), isTrue);
      expect(limiter.recordRequest(t0), isTrue);

      // Attempt immediate duplicate request within 500ms
      final tRapid = t0.add(const Duration(milliseconds: 100));
      expect(limiter.canSendRequest(tRapid), isFalse);
      expect(limiter.recordRequest(tRapid), isFalse);

      // Attempt after minimum interval elapsed
      final tAllowed = t0.add(const Duration(milliseconds: 600));
      expect(limiter.canSendRequest(tAllowed), isTrue);
      expect(limiter.recordRequest(tAllowed), isTrue);
    });

    test('blocks when max requests per minute quota is reached', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Consume all 3 tokens
      expect(limiter.recordRequest(t0), isTrue);
      expect(limiter.recordRequest(t0.add(const Duration(milliseconds: 600))), isTrue);
      expect(limiter.recordRequest(t0.add(const Duration(milliseconds: 1200))), isTrue);

      // 4th request within 1 minute should be rejected
      final tBlocked = t0.add(const Duration(seconds: 10));
      expect(limiter.canSendRequest(tBlocked), isFalse);
      expect(limiter.recordRequest(tBlocked), isFalse);
      expect(limiter.getRemainingCooldownSeconds(tBlocked), greaterThan(0));

      // After 61 seconds from t0, first token expires and request is allowed
      final tExpired = t0.add(const Duration(seconds: 61));
      expect(limiter.canSendRequest(tExpired), isTrue);
      expect(limiter.recordRequest(tExpired), isTrue);
    });

    test('honors server 429 Retry-After duration', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      expect(limiter.canSendRequest(t0), isTrue);

      // Simulate server returning 429 with 30s retry after
      limiter.recordServer429(30, t0);

      // 5 seconds later: still blocked
      final t5 = t0.add(const Duration(seconds: 5));
      expect(limiter.canSendRequest(t5), isFalse);
      expect(limiter.getRemainingCooldownSeconds(t5), equals(25));

      // 31 seconds later: unblocked
      final t31 = t0.add(const Duration(seconds: 31));
      expect(limiter.canSendRequest(t31), isTrue);
    });

    test('reset clears all state', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      limiter.recordServer429(60, t0);
      expect(limiter.canSendRequest(t0), isFalse);

      limiter.reset();
      expect(limiter.canSendRequest(t0), isTrue);
    });
  });
}

