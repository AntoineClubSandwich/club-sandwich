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

  Future<OrganizationDetails?> fetchDetails(String id) async {
    final organization = await fetchOrganization(id);
    if (organization == null) return null;
    final results = await Future.wait([
      _client
          .from('organization_contacts')
          .select()
          .eq('organization_id', id)
          .order('last_name'),
      _client
          .from('organization_documents')
          .select()
          .eq('organization_id', id)
          .order('created_at', ascending: false),
      _client
          .from('concerts')
          .select(
            'id, maraude_status, '
            'operational_report:maraude_operational_reports(total_weight_kg)',
          )
          .eq('promoter_organization_id', id),
    ]);
    final contacts = (results[0] as List<dynamic>)
        .map((row) => OrganizationContact.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
    final documents = (results[1] as List<dynamic>)
        .map(
          (row) => OrganizationDocument.fromJson(row as Map<String, dynamic>),
        )
        .toList(growable: false);
    final concerts = results[2] as List<dynamic>;
    var completed = 0;
    var totalWeight = 0.0;
    for (final item in concerts) {
      final row = item as Map<String, dynamic>;
      if (row['maraude_status'] == 'completed') completed++;
      final relation = row['operational_report'];
      final report = relation is List && relation.isNotEmpty
          ? relation.first as Map<String, dynamic>
          : relation is Map<String, dynamic>
          ? relation
          : null;
      totalWeight += (report?['total_weight_kg'] as num?)?.toDouble() ?? 0;
    }
    return OrganizationDetails(
      organization: organization,
      contacts: contacts,
      documents: documents,
      concertCount: concerts.length,
      completedMaraudeCount: completed,
      totalWeightKg: totalWeight,
    );
  }

  Future<Organization> create(OrganizationDraft draft) async {
    final row = await _client
        .from('organizations')
        .insert(draft.toJson())
        .select()
        .single();
    return Organization.fromJson(row);
  }

  Future<Organization> update(String id, OrganizationDraft draft) async {
    final row = await _client
        .from('organizations')
        .update(draft.toJson())
        .eq('id', id)
        .select()
        .single();
    return Organization.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('organizations').delete().eq('id', id);
  }

  Future<void> addContact(
    String organizationId, {
    required String firstName,
    required String lastName,
    String? jobTitle,
    String? email,
    String? phone,
  }) async {
    await _client.from('organization_contacts').insert({
      'organization_id': organizationId,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'job_title': jobTitle,
      'email': email,
      'phone': phone,
    });
  }

  Future<void> addDocument(
    String organizationId, {
    required String name,
    required String url,
  }) async {
    await _client.from('organization_documents').insert({
      'organization_id': organizationId,
      'name': name.trim(),
      'url': url.trim(),
    });
  }
}
