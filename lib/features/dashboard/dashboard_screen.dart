import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/points_chip.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/challenge.dart';
import '../challenge/challenge_setup_providers.dart';
import '../challenge/challenge_switcher.dart';
import '../challenge/current_challenge_provider.dart';
import '../my_activities/my_activities_provider.dart';
import '../session/current_player_provider.dart';

/// How many recent activities the dashboard shows.
const int _recentCount = 5;

/// Challenge points, points this week, and the newest activities.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(currentPlayerProvider);
    final challenge = ref.watch(currentChallengeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
        actions: [
          const ChallengeSwitcherButton(),
          IconButton(
            tooltip: AppStrings.scoringRulesTitle,
            icon: const Icon(Icons.rule),
            onPressed: () => context.push(AppRoutes.scoringRules),
          ),
          IconButton(
            tooltip: AppStrings.welcomeChoosePlayer,
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                ref.read(currentPlayerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: AsyncView<Challenge?>(
        value: challenge,
        builder: (context, challenge) {
          if (challenge == null) return const _NoChallenge();
          return _Dashboard(challenge: challenge, playerName: player?.name ?? '');
        },
      ),
    );
  }
}

/// Shown when no challenge is running. The owner also gets a setup button.
class _NoChallenge extends ConsumerWidget {
  const _NoChallenge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);
    final setupRoute = ref.watch(challengeSetupRouteProvider);

    return EmptyState(
      icon: Icons.event_busy,
      title: AppStrings.dashboardNoChallengeTitle,
      body: isOwner
          ? AppStrings.dashboardNoChallengeOwnerBody
          : AppStrings.dashboardNoChallengeBody,
      actionLabel: isOwner ? AppStrings.dashboardSetUpChallenge : null,
      onAction: isOwner ? () => context.push(setupRoute) : null,
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.challenge, required this.playerName});

  final Challenge challenge;
  final String playerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider);
    final challengePoints = ref.watch(myChallengePointsProvider);
    final weekPoints = ref.watch(myWeekPointsProvider);
    final mine = ref.watch(myActivitiesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Text(
          playerName.isEmpty ? challenge.name : 'Hi $playerName',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${challenge.name} · ${AppDates.dateRange(challenge.startDate, challenge.endDate)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _PointsTile(
                label: AppStrings.dashboardChallengePoints,
                points: challengePoints,
                icon: Icons.emoji_events_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _PointsTile(
                label: AppStrings.dashboardWeekPoints,
                points: weekPoints,
                icon: Icons.date_range_outlined,
              ),
            ),
          ],
        ),
        SectionHeader(
          title: AppStrings.dashboardRecentActivities,
          trailing: TextButton(
            onPressed: () => context.go(AppRoutes.activities),
            child: const Text(AppStrings.dashboardSeeAll),
          ),
        ),
        AsyncView<List<Activity>>(
          value: mine,
          builder: (context, activities) {
            if (activities.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: EmptyState(
                  icon: Icons.directions_run,
                  title: AppStrings.dashboardNoActivitiesTitle,
                  body: AppStrings.dashboardNoActivitiesBody,
                  actionLabel: AppStrings.dashboardLogActivity,
                  onAction: () => context.go(AppRoutes.log),
                ),
              );
            }

            final recent = activities.take(_recentCount).toList(growable: false);
            return Card(
              child: Column(
                children: [
                  for (final activity in recent)
                    ActivityTile(
                      emoji: activity.ruleEmoji,
                      ruleName: activity.ruleName,
                      date: activity.date,
                      points: activity.points,
                      durationMinutes: activity.durationMinutes,
                      distanceKm: activity.distanceKm,
                      notes: activity.notes,
                      now: now,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A [StatTile] that waits for its number rather than guessing at zero.
///
/// The totals are summed from a stream. Until the first batch lands there is no
/// number to show, and if the read fails there never will be — both have to
/// look different from a real zero, or the tiles quietly claim the player has
/// lost everything they logged.
class _PointsTile extends StatelessWidget {
  const _PointsTile({
    required this.label,
    required this.points,
    required this.icon,
  });

  final String label;
  final AsyncValue<int> points;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AsyncView<int>(
      value: points,
      builder: (context, value) => StatTile(
        label: label,
        value: '$value',
        icon: icon,
      ),
    );
  }
}
