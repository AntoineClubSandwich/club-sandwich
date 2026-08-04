import 'dart:convert';

import 'package:club_sandwich/features/notifications/data/workflow_notification_repository.dart';
import 'package:club_sandwich/features/notifications/domain/workflow_notification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('parse une notification non lue puis lue', () {
    final unread = WorkflowNotification.fromJson(_notificationJson());
    final read = WorkflowNotification.fromJson(
      _notificationJson(readAt: '2026-07-29T12:30:00.000Z'),
    );

    expect(unread.title, 'Votre rôle a changé');
    expect(unread.concertId, 'concert-id');
    expect(unread.isRead, isFalse);
    expect(read.isRead, isTrue);
  });

  test('charge les notifications et marque une ligne comme lue', () async {
    final requests = <Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return Response(
          jsonEncode([_notificationJson()]),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }
      return Response('', 204, request: request);
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final repository = WorkflowNotificationRepository(client);

    final notifications = await repository.fetchMine();
    await repository.markAsRead('notification-id');

    expect(notifications.single.type, 'role_changed');
    expect(requests.first.url.path, endsWith('/user_notifications'));
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.queryParameters['id'], 'eq.notification-id');
    expect(
      (jsonDecode(requests.last.body) as Map<String, dynamic>)['read_at'],
      isNotNull,
    );
  });
}

Map<String, dynamic> _notificationJson({String? readAt}) => {
  'id': 'notification-id',
  'concert_id': 'concert-id',
  'notification_type': 'role_changed',
  'title': 'Votre rôle a changé',
  'body': 'Consultez votre nouvelle fiche de mission.',
  'read_at': readAt,
  'created_at': '2026-07-29T12:00:00.000Z',
};
