import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/points_chip.dart';
import '../challenge/challenge_switcher.dart';
import '../challenge/current_challenge_provider.dart';
import '../session/current_player_provider.dart';
import 'leaderboard_provider.dart';

/// The team ranked by points in the running challenge.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);
    final challenge = ref.watch(currentChallengeProvider).value;
    final me = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.leaderboardTitle),
        // The switcher already names the challenge this table belongs to, so
        // the old subtitle under the title would only say it twice.
        actions: [
          const ChallengeSwitcherButton(),
          if (challenge != null)
            IconButton(
              tooltip: AppStrings.membersTitle,
              icon: const Icon(Icons.group_outlined),
              onPressed: () =>
                  context.push(AppRoutes.challengeMembers(challenge.id)),
            ),
        ],
      ),
      body: AsyncView<List<LeaderboardEntry>>(
        value: entries,
        builder: (context, entries) {
          if (challenge == null) {
            return const EmptyState(
              icon: Icons.event_busy,
              title: AppStrings.dashboardNoChallengeTitle,
              body: AppStrings.dashboardNoChallengeBody,
            );
          }
          if (entries.every((entry) => entry.points == 0)) {
            return const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: AppStrings.leaderboardEmptyTitle,
              body: AppStrings.leaderboardEmptyBody,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) => _LeaderboardRow(
              entry: entries[index],
              isMe: entries[index].player.id == me?.id,
              isOwner: entries[index].player.id == challenge.ownerId,
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.isOwner,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      selected: isMe,
      leading: _RankBadge(rank: entry.rank),
      title: Row(
        children: [
          Flexible(
            child: Text(
              entry.player.name,
              overflow: TextOverflow.ellipsis,
              style: isMe
                  ? const TextStyle(fontWeight: FontWeight.w700)
                  : null,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: AppSpacing.sm),
            _Tag(label: AppStrings.leaderboardYou),
          ],
          if (isOwner) ...[
            const SizedBox(width: AppSpacing.sm),
            _Tag(label: AppStrings.leaderboardOwner),
          ],
        ],
      ),
      subtitle: Text(
        entry.activityCount == 1
            ? '1 activity'
            : '${entry.activityCount} activities',
        style: theme.textTheme.bodySmall,
      ),
      trailing: PointsChip(
        points: entry.points,
        emphasis: entry.rank == 1 && entry.points > 0
            ? PointsChipEmphasis.strong
            : PointsChipEmphasis.normal,
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPodium = rank <= 3;

    return CircleAvatar(
      backgroundColor: isPodium
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isPodium
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
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
