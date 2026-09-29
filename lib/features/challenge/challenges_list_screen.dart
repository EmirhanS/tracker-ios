import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/points_chip.dart';
import '../../data/providers.dart';
import '../../domain/models/challenge.dart';
import '../session/current_player_provider.dart';
import 'challenge_selection.dart';
import 'current_challenge_provider.dart';

/// Every challenge the signed-in player belongs to.
///
/// This is the way in to everything else: create one, join one with a code, or
/// tap a row to point the tabs at it.
class ChallengesListScreen extends ConsumerWidget {
  const ChallengesListScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, Challenge challenge) {
    selectChallenge(ref, challenge.id);
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(myChallengesProvider);
    final activities = ref.watch(allActivitiesProvider);
    final me = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.challengesTitle)),
      body: AsyncView<List<Challenge>>(
        value: challenges,
        builder: (context, challenges) {
          if (challenges.isEmpty) return const _NoChallenges();

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: _Actions(),
              ),
              for (final challenge in challenges)
                _ChallengeRow(
                  challenge: challenge,
                  isOwner: challenge.ownerId == me?.id,
                  // Still an AsyncValue at the row: a total summed from
                  // activities that have not arrived is a confident zero, and
                  // a player reads that as points they have lost.
                  points: me == null
                      ? const AsyncValue.data(0)
                      : activities.whenData(
                          (all) => pointsInChallenge(
                            all,
                            challengeId: challenge.id,
                            playerId: me.id,
                          ),
                        ),
                  onTap: () => _open(context, ref, challenge),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The two ways into a challenge, side by side.
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.challengeNew),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.challengesCreate),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.challengeJoin),
          icon: const Icon(Icons.key_outlined),
          label: const Text(AppStrings.challengesJoin),
        ),
      ],
    );
  }
}

/// Shown when the player belongs to nothing yet. Both ways in are still here.
class _NoChallenges extends StatelessWidget {
  const _NoChallenges();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.challengesEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.challengesEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Actions(),
          ],
        ),
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({
    required this.challenge,
    required this.isOwner,
    required this.points,
    required this.onTap,
  });

  final Challenge challenge;
  final bool isOwner;
  final AsyncValue<int> points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Flexible(
            child: Text(challenge.name, overflow: TextOverflow.ellipsis),
          ),
          if (isOwner) ...[
            const SizedBox(width: AppSpacing.sm),
            const _Tag(label: AppStrings.challengesOwnerMark),
          ],
          if (challenge.isDraft) ...[
            const SizedBox(width: AppSpacing.sm),
            const _Tag(label: AppStrings.challengesDraftMark),
          ],
        ],
      ),
      subtitle: Text(
        '${AppDates.dateRange(challenge.startDate, challenge.endDate)} Â· '
        '${AppStrings.formatMembers(challenge.memberIds.length)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: _MyPoints(points: points),
    );
  }
}

/// The player's points in one challenge, or a spinner while they load.
///
/// Never a `0` that has not been counted yet: the row would be telling the
/// player they have scored nothing in a challenge they may well lead.
class _MyPoints extends StatelessWidget {
  const _MyPoints({required this.points});

  final AsyncValue<int> points;

  @override
  Widget build(BuildContext context) {
    return switch (points) {
      AsyncData(:final value) => PointsChip(points: value),
      AsyncError() => Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      _ => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
    };
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
