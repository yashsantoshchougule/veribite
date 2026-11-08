import 'dart:math';

/// Client-side rate limiter and debounce coordinator for mobile network requests.
///
/// Partitions quotas per [userId] to ensure that multiple users (or switching accounts)
/// receive their own isolated quota of requests per minute, while preventing UI flood
/// spamming and respecting server-enforced HTTP 429 Retry-After durations.
class ClientRateLimiter {
  final int maxRequestsPerMinute;
  final Duration minimumInterval;

  final Map<String, List<DateTime>> _userTimestamps = {};
  final Map<String, DateTime> _serverThrottledUntil = {};

  ClientRateLimiter({
    this.maxRequestsPerMinute = 4,
    this.minimumInterval = Duration.zero,
  });

  static final ClientRateLimiter _instance = ClientRateLimiter();
  static ClientRateLimiter get instance => _instance;

  /// Check whether an outgoing request is currently permitted for [userId].
  bool canSendRequest([DateTime? currentTime, String userId = 'anonymous']) {
    final now = currentTime ?? DateTime.now();

    // 1. Check if active server 429 cooldown is still in effect for this user
    final throttledUntil = _serverThrottledUntil[userId];
    if (throttledUntil != null && now.isBefore(throttledUntil)) {
      return false;
    }

    // 2. Check minimum interval between requests for this user (anti-double-tap)
    final timestamps = _userTimestamps[userId];
    if (timestamps != null && timestamps.isNotEmpty) {
      final elapsed = now.difference(timestamps.last);
      if (elapsed < minimumInterval) {
        return false;
      }
    }

    // 3. Check sliding-window minute quota for this user
    final windowStart = now.subtract(const Duration(minutes: 1));
    _pruneOldTimestamps(userId, windowStart);

    final activeCount = _userTimestamps[userId]?.length ?? 0;
    return activeCount < maxRequestsPerMinute;
  }

  /// Record an outgoing request timestamp for [userId]. Returns false if blocked.
  bool recordRequest([DateTime? currentTime, String userId = 'anonymous']) {
    final now = currentTime ?? DateTime.now();
    if (!canSendRequest(now, userId)) {
      return false;
    }
    _userTimestamps.putIfAbsent(userId, () => []).add(now);
    return true;
  }

  /// Enforce server-directed 429 Retry-After duration for [userId].
  void recordServer429(int retryAfterSeconds, [DateTime? currentTime, String userId = 'anonymous']) {
    final now = currentTime ?? DateTime.now();
    final effectiveSeconds = max(1, retryAfterSeconds);
    _serverThrottledUntil[userId] = now.add(Duration(seconds: effectiveSeconds));
  }

  /// Seconds remaining until requests are unblocked for [userId].
  int getRemainingCooldownSeconds([DateTime? currentTime, String userId = 'anonymous']) {
    final now = currentTime ?? DateTime.now();

    // Check server throttle for this user
    final throttledUntil = _serverThrottledUntil[userId];
    if (throttledUntil != null && now.isBefore(throttledUntil)) {
      return max(1, throttledUntil.difference(now).inSeconds);
    }

    // Check minimum interval for this user
    final timestamps = _userTimestamps[userId];
    if (timestamps != null && timestamps.isNotEmpty) {
      final elapsed = now.difference(timestamps.last);
      if (elapsed < minimumInterval) {
        return 1;
      }
    }

    // Check window limit for this user
    final windowStart = now.subtract(const Duration(minutes: 1));
    _pruneOldTimestamps(userId, windowStart);
    final userList = _userTimestamps[userId];
    if (userList != null && userList.length >= maxRequestsPerMinute) {
      final oldestInWindow = userList.first;
      final resetAt = oldestInWindow.add(const Duration(minutes: 1));
      return max(1, resetAt.difference(now).inSeconds);
    }

    return 0;
  }

  void _pruneOldTimestamps(String userId, DateTime cutoff) {
    final list = _userTimestamps[userId];
    if (list != null) {
      list.removeWhere((ts) => ts.isBefore(cutoff));
      if (list.isEmpty) {
        _userTimestamps.remove(userId);
      }
    }
  }

  /// Reset stored timestamps and throttle state (for all users, or a specific [userId]).
  void reset([String? userId]) {
    if (userId != null) {
      _userTimestamps.remove(userId);
      _serverThrottledUntil.remove(userId);
    } else {
      _userTimestamps.clear();
      _serverThrottledUntil.clear();
    }
  }
}
