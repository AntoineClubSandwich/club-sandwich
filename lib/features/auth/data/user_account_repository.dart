import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserAccountRepository {
  const UserAccountRepository(this._client);

  final SupabaseClient _client;

  Future<CurrentUserContext?> fetchCurrentContext() async {
    if (_client.auth.currentUser == null) return null;
    final rows = await _client.rpc<List<dynamic>>('get_current_user_context');
    if (rows.isEmpty) return null;
    return CurrentUserContext.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<List<ManagedUser>> fetchManagedUsers() async {
    final rows = await _client.rpc<List<dynamic>>('get_admin_users');
    return rows
        .map((row) => ManagedUser.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> activateCurrentUser({
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    await _client.rpc<void>(
      'activate_current_user',
      params: {
        'requested_first_name': firstName.trim(),
        'requested_last_name': lastName.trim(),
        'requested_phone': phone?.trim(),
      },
    );
  }

  Future<UserInvitationDelivery> inviteUser(
    UserInvitationDraft draft, {
    required String redirectTo,
  }) async {
    final data = await _invokeAdminUsers({
      'action': 'invite',
      'firstName': draft.firstName,
      'lastName': draft.lastName,
      'email': draft.email,
      'role': draft.role.jsonValue,
      'organizationId': draft.organizationId,
      'redirectTo': redirectTo,
    });
    return UserInvitationDelivery(
      emailSent: data['emailSent'] as bool? ?? true,
      activationUrl: data['activationUrl'] as String?,
    );
  }

  Future<void> resendInvitation(
    String profileId, {
    required String redirectTo,
  }) async {
    await _invokeAdminUsers({
      'action': 'resend',
      'profileId': profileId,
      'redirectTo': redirectTo,
    });
  }

  Future<void> updateUser({
    required String profileId,
    required AppUserRole role,
    String? organizationId,
  }) async {
    await _invokeAdminUsers({
      'action': 'update',
      'profileId': profileId,
      'role': role.jsonValue,
      'organizationId': organizationId,
    });
  }

  Future<void> setDisabled(String profileId, {required bool disabled}) async {
    await _invokeAdminUsers({
      'action': disabled ? 'disable' : 'reactivate',
      'profileId': profileId,
    });
  }

  Future<Map<String, dynamic>> _invokeAdminUsers(
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke('admin-users', body: body);
    if (response.status < 200 || response.status >= 300) {
      throw FunctionException(
        status: response.status,
        details: response.data,
        reasonPhrase: 'Action utilisateur impossible',
      );
    }
    return response.data as Map<String, dynamic>? ?? const {};
  }
}

class UserInvitationDelivery {
  const UserInvitationDelivery({required this.emailSent, this.activationUrl});

  final bool emailSent;
  final String? activationUrl;
}
