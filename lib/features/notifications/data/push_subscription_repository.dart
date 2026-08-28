import 'package:club_sandwich/shared/utils/web_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSubscriptionRepository {
  const PushSubscriptionRepository(this._client);
  final SupabaseClient _client;

  Future<bool> isSubscribedOnThisDevice() async {
    final endpoint = await currentWebPushEndpoint();
    return endpoint != null;
  }

  Future<void> enableOnThisDevice(String vapidPublicKey) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Utilisateur non connecté.');
    final subscription = await subscribeToWebPush(vapidPublicKey);
    await _client.from('push_subscriptions').upsert(
      {
        'user_id': userId,
        'endpoint': subscription.endpoint,
        'p256dh': subscription.p256dh,
        'auth_key': subscription.auth,
      },
      onConflict: 'user_id,endpoint',
    );
  }

  Future<void> disableOnThisDevice() async {
    final endpoint = await currentWebPushEndpoint();
    await unsubscribeFromWebPush();
    if (endpoint != null) {
      await _client.from('push_subscriptions').delete().eq(
        'endpoint',
        endpoint,
      );
    }
  }
}
