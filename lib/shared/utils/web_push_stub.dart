import 'package:club_sandwich/shared/utils/web_push_types.dart';

// Non-web fallback (e.g. VM-run widget tests, which can't compile
// dart:js_interop). The app only ever ships to web, so these are never
// actually invoked outside of tests exercising unrelated code paths that
// happen to reach this file's barrel import.

Future<WebPushSubscription> subscribeToWebPush(String vapidPublicKey) {
  throw const WebPushException(
    'Les notifications ne sont disponibles que sur le web.',
  );
}

Future<String?> currentWebPushEndpoint() async => null;

Future<void> unsubscribeFromWebPush() async {}
