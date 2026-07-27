import 'dart:async';

import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final organization = Organization(
    id: 'organization-id',
    name: 'Club Sandwich',
    slug: 'club-sandwich',
    createdAt: DateTime(2026, 7, 25),
  );

  test('organizationsProvider expose chargement puis succès', () async {
    final completer = Completer<List<Organization>>();
    final container = ProviderContainer(
      overrides: [
        organizationsProvider.overrideWith((ref) => completer.future),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(organizationsProvider).isLoading, isTrue);

    completer.complete([organization]);
    final result = await container.read(organizationsProvider.future);

    expect(result.single.name, 'Club Sandwich');
    expect(container.read(organizationsProvider).hasValue, isTrue);
  });

  test('organizationsProvider expose les erreurs', () async {
    final container = ProviderContainer(
      overrides: [
        organizationsProvider.overrideWith(
          (ref) => Future.error(StateError('Erreur simulée')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(organizationsProvider.future),
      throwsStateError,
    );
    expect(container.read(organizationsProvider).hasError, isTrue);
  });

  test('organizationsProvider se recharge après invalidation', () async {
    var loadCount = 0;
    final container = ProviderContainer(
      overrides: [
        organizationsProvider.overrideWith((ref) async {
          loadCount++;
          return [organization];
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(organizationsProvider.future);
    container.invalidate(organizationsProvider);
    await container.read(organizationsProvider.future);

    expect(loadCount, 2);
  });
}
