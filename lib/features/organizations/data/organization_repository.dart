import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationRepository {
  const OrganizationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Organization>> fetchOrganizations() async {
    final rows = await _client.from('organizations').select().order('name');
    return rows.map(Organization.fromJson).toList(growable: false);
  }

  Future<Organization?> fetchOrganization(String id) async {
    final row = await _client
        .from('organizations')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Organization.fromJson(row);
  }
}
