import 'dart:collection';

class RateLimitResult {
  final bool isAllowed;
  final int remainingAttempts;
  final Duration resetIn;

  RateLimitResult({
    required this.isAllowed,
    required this.remainingAttempts,
    required this.resetIn,
  });
}

/// Centralized Firebase App Check & Client-Side Abuse Protection Service.
/// Implements sliding-window rate limiters to prevent brute-force and resource exhaustion.
class AppCheckService {
  final Map<String, Queue<DateTime>> _requestLogs = {};

  /// Checks if an action is within rate limits.
  /// [key]: Unique action identifier (e.g. "pin_attempt_user1", "invitation_create_user1")
  /// [maxRequests]: Allowed attempts in the window
  /// [window]: Time duration window
  RateLimitResult checkRateLimit({
    required String key,
    int maxRequests = 5,
    Duration window = const Duration(minutes: 15),
  }) {
    final now = DateTime.now();
    final queue = _requestLogs.putIfAbsent(key, () => Queue<DateTime>());

    // Evict timestamps outside the sliding window
    while (queue.isNotEmpty && now.difference(queue.first) > window) {
      queue.removeFirst();
    }

    if (queue.length >= maxRequests) {
      final oldestInWindow = queue.first;
      final resetIn = window - now.difference(oldestInWindow);
      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        resetIn: resetIn.isNegative ? Duration.zero : resetIn,
      );
    }

    // Record attempt
    queue.addLast(now);
    final remaining = maxRequests - queue.length;
    return RateLimitResult(
      isAllowed: true,
      remainingAttempts: remaining,
      resetIn: window,
    );
  }

  /// Resets a rate limit counter upon successful authenticated action.
  void resetRateLimit(String key) {
    _requestLogs.remove(key);
  }
}
