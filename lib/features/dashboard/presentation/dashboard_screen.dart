import 'package:club_sandwich/design_system/components/ds_pressable.dart';
import 'package:club_sandwich/design_system/components/feedback/ds_empty_state.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_status_chip.dart';
import 'package:club_sandwich/design_system/components/navigation/ds_section_header.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_metric_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/illustrations/ds_illustration.dart';
import 'package:club_sandwich/design_system/tokens/ds_motion.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_shadows.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_list_section.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:club_sandwich/features/exports/presentation/maraude_export_dialog.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(maraudeOverviewProvider);
    final contextRole = ref.watch(currentUserContextProvider).value?.role;
    final invitationCampaigns = ref.watch(invitationCampaignsProvider);
    final invitations =
        invitationCampaigns.value ?? const <InvitationCampaign>[];
    final creditSummary = ref.watch(volunteerCreditSummaryProvider).value;
    final hasPendingDocuments =
        ref.watch(pendingVolunteerDocumentsProvider).value?.isNotEmpty == true;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overview.when(
        loading: () =>
            const AppLoadingState(label: 'Chargement du tableau de bord'),
        error: (_, _) => AppErrorState(
          message: 'Impossible de charger le tableau de bord.',
          onRetry: () => ref.invalidate(maraudeOverviewProvider),
        ),
        data: (items) => _DashboardContent(
          items: items,
          role:
              contextRole ??
              (items.any((item) => item.isAdmin)
                  ? AppUserRole.admin
                  : AppUserRole.volunteer),
          invitations: invitations,
          invitationsUnavailable: invitationCampaigns.hasError,
          onRetryInvitations: () => ref.invalidate(invitationCampaignsProvider),
          creditSummary: creditSummary,
          hasPendingDocuments: hasPendingDocuments,
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.items,
    required this.role,
    required this.invitations,
    required this.invitationsUnavailable,
    required this.onRetryInvitations,
    this.creditSummary,
    this.hasPendingDocuments = false,
  });

  final List<MaraudeOverview> items;
  final AppUserRole role;
  final List<InvitationCampaign> invitations;
  final bool invitationsUnavailable;
  final VoidCallback onRetryInvitations;
  final VolunteerCreditSummary? creditSummary;
  final bool hasPendingDocuments;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        if (role != AppUserRole.admin) ...[
          Text('Accueil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('Votre impact et vos prochaines actions.'),
          const SizedBox(height: 24),
          _AchievementSummary(
            role: role,
            items: items,
            invitations: invitations,
            creditSummary: creditSummary,
          ),
          const SizedBox(height: 28),
          Text(
            'À faire maintenant',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
        if (invitationsUnavailable) ...[
          const SizedBox(height: 16),
          _DashboardWarning(onRetry: onRetryInvitations),
        ],
        const SizedBox(height: 24),
        if (items.isEmpty &&
            invitations.isEmpty &&
            !(role == AppUserRole.admin && hasPendingDocuments))
          const _DashboardEmpty()
        else if (role == AppUserRole.admin)
          _AdminDashboard(items: items, invitations: invitations)
        else if (role == AppUserRole.promoter)
          _PromoterDashboard(items: items, invitations: invitations)
        else
          _VolunteerDashboard(items: items, invitations: invitations),
      ],
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({
    required this.role,
    required this.items,
    required this.invitations,
    this.creditSummary,
  });

  final AppUserRole role;
  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;
  final VolunteerCreditSummary? creditSummary;

  @override
  Widget build(BuildContext context) {
    final completed = items
        .where((item) => item.maraudeStatus == MaraudeStatus.completed)
        .toList(growable: false);
    final totalWeight = completed.fold<double>(
      0,
      (sum, item) => sum + (item.totalWeightKg ?? 0),
    );
    final metrics = role == AppUserRole.volunteer
        ? [
            ('Maraudes réalisées', '${completed.length}'),
            ('Impact collectif', '${_dashboardNumber(totalWeight)} kg'),
            (
              'Invitations obtenues',
              '${invitations.where((campaign) => campaign.ownApplication?.status == InvitationApplicationStatus.selected).length}',
            ),
            ('Crédits disponibles', '${creditSummary?.available ?? '—'}'),
          ]
        : [
            ('Maraudes réalisées', '${completed.length}'),
            ('Collecte accompagnée', '${_dashboardNumber(totalWeight)} kg'),
            ('Campagnes d’invitations', '${invitations.length}'),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          role == AppUserRole.volunteer
              ? 'Votre engagement'
              : 'Votre contribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: metrics.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return SizedBox(
                width: 200,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.$2,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(metric.$1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (role == AppUserRole.volunteer && creditSummary != null) ...[
          const SizedBox(height: 16),
          _CreditProgress(summary: creditSummary!),
        ],
      ],
    );
  }
}

class _CreditProgress extends StatelessWidget {
  const _CreditProgress({required this.summary});
  final VolunteerCreditSummary summary;

  static const _threshold = 3;

  @override
  Widget build(BuildContext context) {
    final eligible = summary.available >= _threshold;
    final progress = (summary.available / _threshold).clamp(0, 1).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eligible
                  ? 'Vous êtes éligible aux invitations'
                  : 'Progression vers les invitations',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: eligible ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              eligible
                  ? '${summary.available} crédits disponibles — vous pouvez candidater aux invitations.'
                  : '${summary.available}/$_threshold crédits pour pouvoir candidater aux invitations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardWarning extends StatelessWidget {
  const _DashboardWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Les invitations sont temporairement indisponibles.'),
            ),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _PromoterDashboard extends StatelessWidget {
  const _PromoterDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final upcoming =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final upcomingIds = upcoming.map((item) => item.concertId).toSet();
    final activeInvitations = invitations
        .where(
          (campaign) =>
              campaign.status == InvitationCampaignStatus.open ||
              campaign.status == InvitationCampaignStatus.draft,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/maraudes'),
              icon: const Icon(Icons.add),
              label: const Text('Ouvrir une maraude'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/invitations'),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Nouvelle campagne'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('open-export-dialog-button'),
              onPressed: () =>
                  showMaraudeExportDialog(context, AppUserRole.promoter),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Exporter les indicateurs'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        MaraudeListSection(
          title: 'Prochaines maraudes',
          items: upcoming.take(5).toList(),
          actionLabel: 'Voir la maraude',
        ),
        _InvitationDashboardSection(
          role: AppUserRole.promoter,
          campaigns: activeInvitations,
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Activité récente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final item
              in items
                  .where((item) => !upcomingIds.contains(item.concertId))
                  .take(3))
            MaraudeOverviewCard(maraude: item),
        ],
      ],
    );
  }
}

class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _day(DateTime.now());
    final todayMaraudes = items
        .where(
          (item) =>
              _day(item.date) == today &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final todayIds = todayMaraudes.map((item) => item.concertId).toSet();
    final confirmationsPending = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.pendingConfirmationCount > 0 &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final confirmationIds = confirmationsPending
        .map((item) => item.concertId)
        .toSet();
    final openWithApplications = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !confirmationIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.maraudeStatus == MaraudeStatus.open &&
              item.pendingApplicationCount > 0,
        )
        .toList();
    final applicationIds = openWithApplications
        .map((item) => item.concertId)
        .toSet();
    final teamNotValidated = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !applicationIds.contains(item.concertId) &&
              !confirmationIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.selectedCount == 0 &&
              (item.maraudeStatus == MaraudeStatus.draft ||
                  item.maraudeStatus == MaraudeStatus.open),
        )
        .toList();
    final teamNotValidatedIds = teamNotValidated
        .map((item) => item.concertId)
        .toSet();
    final upcoming =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  !todayIds.contains(item.concertId) &&
                  !applicationIds.contains(item.concertId) &&
                  !confirmationIds.contains(item.concertId) &&
                  !teamNotValidatedIds.contains(item.concertId) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final pastNotClosed = items
        .where(
          (item) =>
              item.date.isBefore(today) &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final creditsToValidate = items
        .where(
          (item) =>
              item.maraudeStatus == MaraudeStatus.completed &&
              item.pendingCreditValidationCount > 0,
        )
        .toList();
    final creditsToValidateIds = creditsToValidate
        .map((item) => item.concertId)
        .toSet();
    final history = items
        .where(
          (item) =>
              !creditsToValidateIds.contains(item.concertId) &&
              (item.maraudeStatus == MaraudeStatus.completed ||
                  item.maraudeStatus == MaraudeStatus.cancelled),
        )
        .take(5)
        .toList();

    final now = DateTime.now();
    final monthItems = items
        .where(
          (item) => item.date.year == now.year && item.date.month == now.month,
        )
        .toList();
    final monthCompleted = monthItems
        .where((item) => item.maraudeStatus == MaraudeStatus.completed)
        .length;
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthItems = items
        .where(
          (item) =>
              item.date.year == lastMonthDate.year &&
              item.date.month == lastMonthDate.month,
        )
        .toList();
    final mealsThisMonth = monthItems
        .where((item) => item.maraudeStatus == MaraudeStatus.completed)
        .fold<int>(0, (sum, item) => sum + (item.estimatedMeals ?? 0));
    final mealsLastMonth = lastMonthItems
        .where((item) => item.maraudeStatus == MaraudeStatus.completed)
        .fold<int>(0, (sum, item) => sum + (item.estimatedMeals ?? 0));

    final firstName = ref.watch(currentProfileProvider).value?.firstName;
    final organizationsCount =
        ref.watch(organizationsProvider).value?.length ?? 0;
    final volunteersCount =
        ref
            .watch(managedUsersProvider)
            .value
            ?.where((user) => user.role == AppUserRole.volunteer)
            .length ??
        0;

    return Theme(
      data: DsTheme.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FadeIn(
            child: _DashboardHero(
              firstName: firstName,
              todayCount: todayMaraudes.length,
            ),
          ),
          const SizedBox(height: DsSpacing.xxl),
          _InvitationDashboardSection(
            role: AppUserRole.admin,
            campaigns: invitations
                .where(
                  (campaign) =>
                      campaign.status == InvitationCampaignStatus.open ||
                      campaign.status == InvitationCampaignStatus.draft ||
                      campaign.awaitingConfirmationCount > 0,
                )
                .toList(growable: false),
          ),
          const _PendingDocumentsSection(),
          _FadeIn(
            child: _AdminKpiGrid(
              monthlyMaraudes: monthItems.length,
              monthlyMaraudesDelta: monthItems.length - lastMonthItems.length,
              volunteersCount: volunteersCount,
              invitationsCount: invitations.length,
              mealsSaved: mealsThisMonth,
              mealsSavedDelta: mealsThisMonth - mealsLastMonth,
              organizationsCount: organizationsCount,
            ),
          ),
          const SizedBox(height: DsSpacing.xxl),
          _FadeIn(
            child: _QuickActionsSection(
              onExport: () =>
                  showMaraudeExportDialog(context, AppUserRole.admin),
            ),
          ),
          const SizedBox(height: DsSpacing.xxl),
          _FadeIn(child: _ActivityTimeline(history: history)),
          const SizedBox(height: DsSpacing.xxl),
          _FadeIn(
            child: _MonthlyGoalCard(
              completed: monthCompleted,
              total: monthItems.length,
            ),
          ),
          const SizedBox(height: DsSpacing.xxl),
          _PremiumMaraudeSection(
            title: 'Prochaines maraudes',
            items: upcoming.take(5).toList(),
            actionLabel: 'Ouvrir la fiche opérationnelle',
          ),
          _PremiumMaraudeSection(
            title: 'Candidatures à examiner',
            items: openWithApplications,
            actionLabel: 'Constituer l’équipe',
          ),
          _PremiumMaraudeSection(
            title: 'Équipes non validées',
            items: teamNotValidated,
            actionLabel: 'Valider l’organisation retenue',
          ),
          _PremiumMaraudeSection(
            title: 'Confirmations bénévoles en attente',
            items: confirmationsPending,
            actionLabel: 'Suivre les confirmations',
          ),
          _PremiumMaraudeSection(
            title: 'Aujourd’hui',
            items: todayMaraudes,
            actionLabelFor: _adminTodayAction,
          ),
          _PremiumMaraudeSection(
            title: 'Maraudes passées non clôturées',
            items: pastNotClosed,
            actionLabel: 'Saisir le compte rendu',
          ),
          _PremiumMaraudeSection(
            title: 'Présences et crédits à valider',
            items: creditsToValidate,
            actionLabelFor: (item) =>
                '${item.pendingCreditValidationCount} '
                '${item.pendingCreditValidationCount == 1 ? 'crédit à valider' : 'crédits à valider'}',
          ),
        ],
      ),
    );
  }
}

/// Fades new dashboard sections in on first build — the only entrance
/// micro-interaction requested, no gadget animations.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: DsMotion.standard,
      curve: DsMotion.curve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.firstName, required this.todayCount});

  final String? firstName;
  final int todayCount;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final name = firstName?.trim();
    final greeting = (name == null || name.isEmpty)
        ? 'Bonjour'
        : 'Bonjour $name';
    final summary = todayCount == 0
        ? 'Aucune maraude aujourd’hui'
        : '$todayCount maraude${todayCount > 1 ? 's' : ''} prévue'
              '${todayCount > 1 ? 's' : ''} aujourd’hui';

    return Container(
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.xlRadius,
        border: Border.all(color: colors.border),
        boxShadow: DsShadows.ambient(colors.textPrimary),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting.toUpperCase(),
                style: DsTypography.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: DsSpacing.sm),
              Text(
                '🥪 $summary',
                style: DsTypography.body.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
          const badge = _AdminHeroBadge();
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.topRight, child: badge),
                const SizedBox(height: DsSpacing.lg),
                text,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: text),
              const SizedBox(width: DsSpacing.xl),
              badge,
            ],
          );
        },
      ),
    );
  }
}

/// The "ADMIN" role pill in the dashboard hero — a soft purple-tinted
/// pill, per design-system/CLAUDE.md.
class _AdminHeroBadge extends StatelessWidget {
  const _AdminHeroBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primarySelectedBg,
        borderRadius: DsRadius.pillRadius,
      ),
      child: Text(
        'ADMIN',
        style: DsTypography.caption.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _KpiDelta {
  const _KpiDelta(this.text, this.trend);
  final String text;
  final DsMetricTrend trend;
}

class _KpiData {
  const _KpiData(this.icon, this.label, this.value, this.delta);
  final IconData icon;
  final String label;
  final String value;
  final _KpiDelta? delta;
}

_KpiDelta? _monthDelta(int diff) {
  if (diff == 0) return null;
  return _KpiDelta(
    diff > 0 ? '+$diff' : '$diff',
    diff > 0 ? DsMetricTrend.up : DsMetricTrend.down,
  );
}

class _AdminKpiGrid extends StatelessWidget {
  const _AdminKpiGrid({
    required this.monthlyMaraudes,
    required this.monthlyMaraudesDelta,
    required this.volunteersCount,
    required this.invitationsCount,
    required this.mealsSaved,
    required this.mealsSavedDelta,
    required this.organizationsCount,
  });

  final int monthlyMaraudes;
  final int monthlyMaraudesDelta;
  final int volunteersCount;
  final int invitationsCount;
  final int mealsSaved;
  final int mealsSavedDelta;
  final int organizationsCount;

  @override
  Widget build(BuildContext context) {
    final metrics = <_KpiData>[
      _KpiData(
        DsIcons.calendar,
        'Maraudes ce mois',
        '$monthlyMaraudes',
        _monthDelta(monthlyMaraudesDelta),
      ),
      _KpiData(DsIcons.users, 'Bénévoles actifs', '$volunteersCount', null),
      _KpiData(DsIcons.mail, 'Invitations', '$invitationsCount', null),
      _KpiData(
        DsIcons.utensils,
        'Repas sauvés ce mois',
        '$mealsSaved',
        _monthDelta(mealsSavedDelta),
      ),
      _KpiData(DsIcons.building, 'Organisations', '$organizationsCount', null),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - DsSpacing.lg * (columns - 1)) / columns;
        return Wrap(
          spacing: DsSpacing.lg,
          runSpacing: DsSpacing.lg,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: DsMetricCard(
                  icon: metric.icon,
                  label: metric.label,
                  value: metric.value,
                  delta: metric.delta?.text,
                  trend: metric.delta?.trend ?? DsMetricTrend.neutral,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    if (!isPrimary) {
      return DsCard(
        onTap: onTap,
        borderRadius: DsRadius.lgRadius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: colors.textPrimary),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(
                label,
                style: DsTypography.body.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DsPressable(
      onTap: onTap,
      builder: (context, state) {
        final shadow = DsShadows.accent(colors.primary);
        return DsPressScale(
          pressed: state.pressed,
          child: AnimatedContainer(
            duration: DsMotion.standard,
            curve: DsMotion.curve,
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.lg,
              vertical: DsSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: DsRadius.lgRadius,
              boxShadow: state.pressed ? const [] : shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: colors.textOnColor),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: colors.textOnColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DsSectionHeader(title: 'Actions rapides'),
        const SizedBox(height: DsSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - DsSpacing.lg * (columns - 1)) / columns;
            final actions = <Widget>[
              SizedBox(
                width: width,
                child: _QuickActionTile(
                  icon: DsIcons.plus,
                  label: 'Nouvelle maraude',
                  isPrimary: true,
                  onTap: () => context.go('/maraudes'),
                ),
              ),
              SizedBox(
                width: width,
                child: _QuickActionTile(
                  icon: DsIcons.users,
                  label: 'Inviter des bénévoles',
                  onTap: () => context.go('/administration'),
                ),
              ),
              SizedBox(
                width: width,
                child: _QuickActionTile(
                  icon: DsIcons.building,
                  label: 'Nouvelle organisation',
                  onTap: () => context.go('/organizations'),
                ),
              ),
              SizedBox(
                width: width,
                child: _QuickActionTile(
                  key: const ValueKey('open-export-dialog-button'),
                  icon: DsIcons.download,
                  label: 'Exporter',
                  onTap: onExport,
                ),
              ),
            ];
            return Wrap(
              spacing: DsSpacing.lg,
              runSpacing: DsSpacing.lg,
              children: actions,
            );
          },
        ),
      ],
    );
  }
}

class _MonthlyGoalCard extends StatelessWidget {
  const _MonthlyGoalCard({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final progress = total == 0
        ? 0.0
        : (completed / total).clamp(0, 1).toDouble();
    final monthLabel = _frenchMonth(DateTime.now());

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsSectionHeader(
            title: 'Objectif du mois',
            subtitle: total == 0
                ? 'Aucune maraude prévue en $monthLabel pour le moment.'
                : '$completed maraude${completed > 1 ? 's' : ''} clôturée'
                      '${completed > 1 ? 's' : ''} sur $total en $monthLabel.',
          ),
          const SizedBox(height: DsSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: DsMotion.standard,
              curve: DsMotion.curve,
              builder: (context, value, _) => Stack(
                children: [
                  Container(height: 10, color: colors.border),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(height: 10, color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            '${(progress * 100).round()} %',
            style: DsTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.history});

  final List<MaraudeOverview> history;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const DsSectionHeader(title: 'Activité récente'),
          const SizedBox(height: DsSpacing.lg),
          if (history.isEmpty)
            const DsEmptyState(
              illustration: DsEmptyBoxIllustration(),
              title: 'Aucune activité récente',
              message: 'Les maraudes clôturées apparaîtront ici.',
            )
          else
            for (var i = 0; i < history.length; i++) ...[
              if (i > 0) ...[
                const SizedBox(height: DsSpacing.md),
                Divider(height: 1, color: colors.borderSubtle),
                const SizedBox(height: DsSpacing.md),
              ],
              _ActivityRow(item: history[i]),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final MaraudeOverview item;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final cancelled = item.maraudeStatus == MaraudeStatus.cancelled;
    final iconColor = cancelled ? colors.error : colors.success;
    final iconBg = cancelled ? colors.errorBg : colors.successBg;

    return GestureDetector(
      onTap: () => context.go('/maraudes/${item.concertId}'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: DsRadius.smRadius,
              ),
              child: Icon(
                cancelled ? DsIcons.circleX : DsIcons.circleCheck,
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.artist,
                          style: DsTypography.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primarySelectedBg,
                          borderRadius: DsRadius.smRadius,
                        ),
                        child: Text(
                          formatLongFrenchDate(item.date),
                          style: DsTypography.caption.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cancelled
                        ? 'Maraude annulée · ${item.venueName}'
                        : 'Maraude clôturée · ${item.venueName}',
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: DsSpacing.md,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${item.selectedCount} bénévole'
                        '${item.selectedCount > 1 ? 's' : ''}',
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        item.totalWeightKg == null
                            ? 'Poids : —'
                            : '${_dashboardNumber(item.totalWeightKg!)} kg',
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (item.cateringName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catering : ${item.cateringName}',
                      style: DsTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

DsChipStatus _mapMaraudeChipStatus(MaraudeStatus status) => switch (status) {
  MaraudeStatus.draft => DsChipStatus.draft,
  MaraudeStatus.open ||
  MaraudeStatus.teamReady ||
  MaraudeStatus.inProgress => DsChipStatus.active,
  MaraudeStatus.completed => DsChipStatus.completed,
  MaraudeStatus.cancelled => DsChipStatus.cancelled,
};

class _PremiumMaraudeSection extends StatelessWidget {
  const _PremiumMaraudeSection({
    required this.title,
    required this.items,
    this.actionLabel,
    this.actionLabelFor,
  });

  final String title;
  final List<MaraudeOverview> items;
  final String? actionLabel;
  final String Function(MaraudeOverview)? actionLabelFor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader(title: title),
          const SizedBox(height: DsSpacing.lg),
          for (var i = 0; i < items.length; i++) ...[
            _PremiumMaraudeCard(
              maraude: items[i],
              actionLabel: actionLabelFor?.call(items[i]) ?? actionLabel,
            ),
            if (i < items.length - 1) const SizedBox(height: DsSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _PremiumMaraudeCard extends StatelessWidget {
  const _PremiumMaraudeCard({required this.maraude, this.actionLabel});

  final MaraudeOverview maraude;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsCard(
      onTap: () => context.go('/maraudes/${maraude.concertId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  maraude.artist,
                  style: DsTypography.h3.copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              DsStatusChip(
                label: maraude.maraudeStatus.label,
                status: _mapMaraudeChipStatus(maraude.maraudeStatus),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(DsIcons.calendar, size: 14, color: colors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${formatLongFrenchDate(maraude.date)} · ${maraude.venueName}'
                  '${maraude.time == null ? '' : ' · ${formatDatabaseTime(maraude.time!)}'}',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (maraude.venueAddress != null) ...[
            const SizedBox(height: 6),
            Text(
              maraude.venueAddress!,
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (maraude.cateringName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Catering : ${maraude.cateringName}',
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (maraude.ownTeamRole != null) ...[
            const SizedBox(height: 6),
            Text(
              'Rôle : ${maraude.ownTeamRole!.label}',
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (maraude.cateringClosesAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Arrivée recommandée : ${_hm(maraude.recommendedArrival)}',
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (maraude.isAdmin &&
              maraude.maraudeStatus != MaraudeStatus.completed &&
              maraude.maraudeStatus != MaraudeStatus.cancelled) ...[
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              spacing: DsSpacing.md,
              runSpacing: 6,
              children: [
                Text(
                  maraude.selectedCount == 0
                      ? 'Équipe non constituée'
                      : '${maraude.selectedCount} bénévole'
                            '${maraude.selectedCount > 1 ? 's' : ''} '
                            'sélectionné'
                            '${maraude.selectedCount > 1 ? 's' : ''}',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (maraude.pendingApplicationCount > 0)
                  Text(
                    '${maraude.pendingApplicationCount} candidature'
                    '${maraude.pendingApplicationCount > 1 ? 's' : ''} '
                    'à examiner',
                    style: DsTypography.caption.copyWith(
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (maraude.pendingConfirmationCount > 0)
                  Text(
                    '${maraude.pendingConfirmationCount} confirmation'
                    '${maraude.pendingConfirmationCount > 1 ? 's' : ''} '
                    'attendue'
                    '${maraude.pendingConfirmationCount > 1 ? 's' : ''}',
                    style: DsTypography.caption.copyWith(
                      color: colors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
          if (maraude.maraudeStatus == MaraudeStatus.completed ||
              maraude.maraudeStatus == MaraudeStatus.cancelled) ...[
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              spacing: DsSpacing.md,
              runSpacing: 6,
              children: [
                Text(
                  '${maraude.selectedCount} bénévole'
                  '${maraude.selectedCount > 1 ? 's' : ''}',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  maraude.totalWeightKg == null
                      ? 'Poids : —'
                      : '${_dashboardNumber(maraude.totalWeightKg!)} kg',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: DsSpacing.md),
            Text(
              actionLabel!,
              style: DsTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _frenchMonth(DateTime date) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return months[date.month - 1];
}

String _hm(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _PendingDocumentsSection extends ConsumerWidget {
  const _PendingDocumentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingVolunteerDocumentsProvider);
    final items = pending.value ?? const <PendingVolunteerDocument>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Documents en attente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final document in items)
            _PendingDocumentCard(document: document),
        ],
      ),
    );
  }
}

class _PendingDocumentCard extends ConsumerStatefulWidget {
  const _PendingDocumentCard({required this.document});
  final PendingVolunteerDocument document;

  @override
  ConsumerState<_PendingDocumentCard> createState() =>
      _PendingDocumentCardState();
}

class _PendingDocumentCardState extends ConsumerState<_PendingDocumentCard> {
  bool _busy = false;

  Future<void> _openFile() async {
    try {
      final url = await ref
          .read(volunteerDocumentRepositoryProvider)
          .signedUrl(widget.document.storagePath);
      await launchUrl(Uri.parse(url));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’ouvrir ce document.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _review(VolunteerDocumentStatus status) async {
    String? reason;
    if (status == VolunteerDocumentStatus.rejected) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Refuser ce document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Motif du refus'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Refuser'),
            ),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
      if (reason == null || reason.trim().isEmpty || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(volunteerDocumentRepositoryProvider)
          .reviewDocument(
            documentId: widget.document.id,
            status: status,
            rejectionReason: reason?.trim(),
          );
      ref.invalidate(pendingVolunteerDocumentsProvider);
      ref.invalidate(volunteerDocumentsProvider(widget.document.userId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible de valider.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(widget.document.displayLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _openFile,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir le document'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _review(VolunteerDocumentStatus.approved),
                  icon: const Icon(Icons.check),
                  label: const Text('Valider'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _review(VolunteerDocumentStatus.rejected),
                  icon: const Icon(Icons.close),
                  label: const Text('Refuser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VolunteerDashboard extends StatelessWidget {
  const _VolunteerDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final open = items.where((item) => item.isOpenForApplication).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final confirmationPending =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.ownStatus == ConcertVolunteerStatus.selected &&
                  item.ownConfirmationStatus !=
                      VolunteerConfirmationStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final selected =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.ownStatus == ConcertVolunteerStatus.selected &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled &&
                  item.ownConfirmationStatus ==
                      VolunteerConfirmationStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final pending = items
        .where(
          (item) =>
              !item.date.isBefore(today) &&
              item.ownStatus == ConcertVolunteerStatus.pending,
        )
        .toList();

    return Column(
      children: [
        MaraudeListSection(
          title: 'Maraudes ouvertes',
          items: open,
          actionLabel: 'Je me propose',
        ),
        MaraudeListSection(
          title: 'Participation à confirmer',
          items: confirmationPending,
          actionLabel: 'Confirmer ma participation',
        ),
        MaraudeListSection(
          title: 'Prochaine mission',
          items: selected.take(1).toList(),
          actionLabel: 'Voir les informations pratiques',
        ),
        MaraudeListSection(
          title: 'Disponibilités en attente',
          items: pending,
          actionLabel: 'En attente de sélection',
        ),
        _InvitationDashboardSection(
          role: AppUserRole.volunteer,
          campaigns: invitations,
        ),
      ],
    );
  }
}

class _InvitationDashboardSection extends StatelessWidget {
  const _InvitationDashboardSection({
    required this.role,
    required this.campaigns,
  });

  final AppUserRole role;
  final List<InvitationCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    final visible = campaigns.where(_requiresInvitationAttention).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invitations nécessitant votre attention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final campaign in visible.take(5))
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go('/invitations'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              campaign.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Chip(label: Text(_invitationStatus(campaign))),
                        ],
                      ),
                      if (campaign.organizationName != null)
                        Text(campaign.organizationName!),
                      const SizedBox(height: 6),
                      Text(_invitationSummary(campaign)),
                      const SizedBox(height: 10),
                      Text(
                        _invitationAction(campaign),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _requiresInvitationAttention(InvitationCampaign campaign) {
    if (role != AppUserRole.volunteer) {
      return campaign.status == InvitationCampaignStatus.open ||
          campaign.status == InvitationCampaignStatus.draft ||
          campaign.awaitingConfirmationCount > 0;
    }
    return campaign.status == InvitationCampaignStatus.open ||
        campaign.ownApplication?.status ==
            InvitationApplicationStatus.selected ||
        campaign.ownApplication?.status == InvitationApplicationStatus.pending;
  }

  String _invitationStatus(InvitationCampaign campaign) {
    if (role == AppUserRole.volunteer && campaign.ownApplication != null) {
      return campaign.ownApplication!.status.label;
    }
    return campaign.status.label;
  }

  String _invitationSummary(InvitationCampaign campaign) {
    if (role == AppUserRole.volunteer) {
      final application = campaign.ownApplication;
      if (application?.status == InvitationApplicationStatus.selected) {
        return 'Une place vous a été attribuée.';
      }
      if (application?.status == InvitationApplicationStatus.pending) {
        return 'Votre candidature attend une décision.';
      }
      return '${campaign.remainingPlaces} '
          '${campaign.remainingPlaces == 1 ? 'place proposée' : 'places proposées'}.';
    }

    final remaining = campaign.remainingPlaces;
    final summary =
        '${campaign.pendingCount} '
        '${campaign.pendingCount == 1 ? 'décision restante' : 'décisions restantes'}'
        ' · $remaining '
        '${remaining == 1 ? 'place restante' : 'places restantes'}';
    if (campaign.awaitingConfirmationCount == 0) return summary;
    return '$summary · ${campaign.awaitingConfirmationCount} '
        '${campaign.awaitingConfirmationCount == 1 ? 'invitation en attente de confirmation' : 'invitations en attente de confirmation'}';
  }

  String _invitationAction(InvitationCampaign campaign) {
    if (role == AppUserRole.admin) {
      if (campaign.pendingCount > 0) return 'Décider des attributions';
      if (campaign.awaitingConfirmationCount > 0) {
        return 'Suivre les confirmations bénévoles';
      }
      return 'Vérifier et clôturer la campagne';
    }
    if (role == AppUserRole.promoter) return 'Suivre la campagne';

    return switch (campaign.ownApplication?.status) {
      InvitationApplicationStatus.selected =>
        'Voir les informations de l’invitation',
      InvitationApplicationStatus.pending => 'Suivre ma candidature',
      _ => 'Candidater',
    };
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Aucune action en attente.'),
      ),
    );
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _dashboardNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _adminTodayAction(MaraudeOverview item) {
  if (item.pendingConfirmationCount > 0) return 'Suivre les confirmations';
  return switch (item.maraudeStatus) {
    MaraudeStatus.draft || MaraudeStatus.open =>
      item.selectedCount == 0
          ? 'Constituer l’équipe'
          : 'Vérifier l’équipe et démarrer',
    MaraudeStatus.teamReady => 'Démarrer la maraude',
    MaraudeStatus.inProgress => 'Poursuivre la maraude',
    MaraudeStatus.completed => 'Consulter le bilan',
    MaraudeStatus.cancelled => 'Consulter la maraude annulée',
  };
}
