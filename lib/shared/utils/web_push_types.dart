class WebPushSubscription {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

class WebPushException implements Exception {
  const WebPushException(this.message);
  final String message;

  @override
  String toString() => message;
}
