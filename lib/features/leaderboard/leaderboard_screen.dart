import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/points_chip.dart';
import '../../data/providers.dart';
import '../session/current_player_provider.dart';
import 'leaderboard_provider.dart';

/// The team ranked by points in the running season.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(leaderboardProvider);
    final season = ref.watch(activeSeasonProvider).value;
    final me = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.leaderboardTitle),
        bottom: season == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      season.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
      ),
      body: AsyncView<List<LeaderboardEntry>>(
        value: entries,
        builder: (context, entries) {
          if (season == null) {
            return const EmptyState(
              icon: Icons.event_busy,
              title: AppStrings.dashboardNoSeasonTitle,
              body: AppStrings.dashboardNoSeasonBody,
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
              isCaptain: entries[index].player.id == season.captainId,
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
    required this.isCaptain,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final bool isCaptain;

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
          if (isCaptain) ...[
            const SizedBox(width: AppSpacing.sm),
            _Tag(label: AppStrings.leaderboardCaptain),
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
