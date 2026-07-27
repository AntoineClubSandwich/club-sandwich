import 'package:club_sandwich/features/organizations/domain/membership.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembershipRepository {
  const MembershipRepository(this._client);

  final SupabaseClient _client;

  Future<List<Membership>> fetchForOrganization(String organizationId) async {
    final rows = await _client
        .from('memberships')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at');
    return rows.map(Membership.fromJson).toList(growable: false);
  }
}
