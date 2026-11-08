import 'dart:math';

/// Client-side rate limiter and debounce coordinator for mobile network requests.
///
/// Prevents UI double-submission, flood spamming, and respects server-enforced
/// HTTP 429 Retry-After durations.
class ClientRateLimiter {
  final int maxRequestsPerMinute;
  final Duration minimumInterval;

  final List<DateTime> _requestTimestamps = [];
  DateTime? _serverThrottledUntil;

  ClientRateLimiter({
    this.maxRequestsPerMinute = 4,
    this.minimumInterval = Duration.zero,
  });

  static final ClientRateLimiter _instance = ClientRateLimiter();
  static ClientRateLimiter get instance => _instance;

  /// Check whether an outgoing request is currently permitted.
  bool canSendRequest([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();

    // 1. Check if active server 429 cooldown is still in effect
    if (_serverThrottledUntil != null && now.isBefore(_serverThrottledUntil!)) {
      return false;
    }

    // 2. Check minimum interval between requests (anti-double-tap)
    if (_requestTimestamps.isNotEmpty) {
      final elapsed = now.difference(_requestTimestamps.last);
      if (elapsed < minimumInterval) {
        return false;
      }
    }

    // 3. Check sliding-window minute quota
    final windowStart = now.subtract(const Duration(minutes: 1));
    _pruneOldTimestamps(windowStart);

    return _requestTimestamps.length < maxRequestsPerMinute;
  }

  /// Record an outgoing request timestamp. Returns false if blocked.
  bool recordRequest([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    if (!canSendRequest(now)) {
      return false;
    }
    _requestTimestamps.add(now);
    return true;
  }

  /// Enforce server-directed 429 Retry-After duration.
  void recordServer429(int retryAfterSeconds, [DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    final effectiveSeconds = max(1, retryAfterSeconds);
    _serverThrottledUntil = now.add(Duration(seconds: effectiveSeconds));
  }

  /// Seconds remaining until requests are unblocked.
  int getRemainingCooldownSeconds([DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();

    // Check server throttle
    if (_serverThrottledUntil != null && now.isBefore(_serverThrottledUntil!)) {
      return max(1, _serverThrottledUntil!.difference(now).inSeconds);
    }

    // Check minimum interval
    if (_requestTimestamps.isNotEmpty) {
      final elapsed = now.difference(_requestTimestamps.last);
      if (elapsed < minimumInterval) {
        return 1;
      }
    }

    // Check window limit
    final windowStart = now.subtract(const Duration(minutes: 1));
    _pruneOldTimestamps(windowStart);
    if (_requestTimestamps.length >= maxRequestsPerMinute) {
      final oldestInWindow = _requestTimestamps.first;
      final resetAt = oldestInWindow.add(const Duration(minutes: 1));
      return max(1, resetAt.difference(now).inSeconds);
    }

    return 0;
  }

  void _pruneOldTimestamps(DateTime cutoff) {
    _requestTimestamps.removeWhere((ts) => ts.isBefore(cutoff));
  }

  /// Reset all stored timestamps and throttle state.
  void reset() {
    _requestTimestamps.clear();
    _serverThrottledUntil = null;
  }
}
