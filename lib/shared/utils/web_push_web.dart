import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:club_sandwich/shared/utils/web_push_types.dart';
import 'package:web/web.dart' as web;

/// Registers the push service worker (idempotent: re-registering an
/// already-registered scope just returns the existing registration),
/// requests notification permission, and subscribes to push. Throws a
/// [WebPushException] with a French, user-facing message on any failure
/// (unsupported browser, permission denied, etc.).
Future<WebPushSubscription> subscribeToWebPush(String vapidPublicKey) async {
  try {
    final registration = await web.window.navigator.serviceWorker
        .register('/push_worker.js'.toJS)
        .toDart;

    final permission = await web.Notification.requestPermission().toDart;
    if (permission.toDart != 'granted') {
      throw const WebPushException(
        'Autorisez les notifications dans votre navigateur pour activer '
        'cette fonctionnalité.',
      );
    }

    final subscription = await registration.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlToBytes(vapidPublicKey).toJS,
          ),
        )
        .toDart;

    final p256dhKey = subscription.getKey('p256dh');
    final authKey = subscription.getKey('auth');
    if (p256dhKey == null || authKey == null) {
      throw const WebPushException(
        'Impossible de récupérer les clés de chiffrement de cet appareil.',
      );
    }

    return WebPushSubscription(
      endpoint: subscription.endpoint,
      p256dh: _base64UrlEncode(p256dhKey.toDart.asUint8List()),
      auth: _base64UrlEncode(authKey.toDart.asUint8List()),
    );
  } on WebPushException {
    rethrow;
  } catch (_) {
    throw const WebPushException(
      'Les notifications ne sont pas prises en charge sur cet appareil ou '
      'ce navigateur.',
    );
  }
}

/// Returns the endpoint of the current subscription for this device, or
/// null if this device was never subscribed.
Future<String?> currentWebPushEndpoint() async {
  try {
    final registration = await web.window.navigator.serviceWorker.ready
        .toDart;
    final subscription = await registration.pushManager.getSubscription().toDart;
    return subscription?.endpoint;
  } catch (_) {
    return null;
  }
}

/// Unsubscribes the current device from push, if it was subscribed.
Future<void> unsubscribeFromWebPush() async {
  try {
    final registration = await web.window.navigator.serviceWorker.ready
        .toDart;
    final subscription = await registration.pushManager.getSubscription().toDart;
    await subscription?.unsubscribe().toDart;
  } catch (_) {
    // Nothing to clean up locally if the browser has no active
    // subscription; the caller still removes the row server-side.
  }
}

String _base64UrlEncode(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _base64UrlToBytes(String value) {
  final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
  final padded = normalized.padRight(
    (normalized.length + 3) ~/ 4 * 4,
    '=',
  );
  return base64.decode(padded);
}
