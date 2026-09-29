import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/activity_tile.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/activity.dart';
import '../challenge/challenge_switcher.dart';
import 'my_activities_provider.dart';

/// Everything the current player has logged this challenge, newest first.
///
/// Swiping a row left deletes it. Points are stored on the activity, so the
/// totals drop by themselves.
class MyActivitiesScreen extends ConsumerWidget {
  const MyActivitiesScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.activitiesDeleteTitle),
        content: const Text(AppStrings.activitiesDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Asks, deletes, and only then lets the row go.
  ///
  /// This is `confirmDismiss` rather than `onDismissed` because the row is not
  /// ours to remove: it leaves the list when the repository stream re-emits
  /// without it. Writing from `onDismissed` starts the delete *after* the
  /// dismiss animation has already finished, which leaves a dismissed
  /// `Dismissible` in the tree for as long as the write takes — Flutter throws
  /// on that — and gives a failed delete nowhere to go but a row that silently
  /// springs back under a "deleted" message.
  Future<bool> _deleteActivity(
    BuildContext context,
    WidgetRef ref,
    String activityId,
  ) async {
    if (!await _confirmDelete(context)) return false;
    if (!context.mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(activityRepositoryProvider).delete(activityId);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.activitiesDeleteFailed)),
      );
      return false;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.activitiesDeleted)),
    );
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider);
    final mine = ref.watch(myActivitiesProvider);
    final total = ref.watch(myChallengePointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.activitiesTitle),
        actions: [
          const ChallengeSwitcherButton(),
          // No number until there is one. A total summed from a stream that has
          // not arrived, or has failed, is not zero — and the body below is
          // already showing the spinner or the error, so the app bar only has
          // to keep quiet.
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                total.hasValue
                    ? '${total.requireValue} ${AppStrings.pointsShort}'
                    : '',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AsyncView<List<Activity>>(
        value: mine,
        builder: (context, activities) {
          if (activities.isEmpty) {
            return EmptyState(
              icon: Icons.list_alt,
              title: AppStrings.activitiesEmptyTitle,
              body: AppStrings.activitiesEmptyBody,
              actionLabel: AppStrings.dashboardLogActivity,
              onAction: () => context.go(AppRoutes.log),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.activitiesSwipeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final activity = activities[index];

                    return Dismissible(
                      key: ValueKey(activity.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        color: theme.colorScheme.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      confirmDismiss: (_) =>
                          _deleteActivity(context, ref, activity.id),
                      child: ActivityTile(
                        emoji: activity.ruleEmoji,
                        ruleName: activity.ruleName,
                        date: activity.date,
                        points: activity.points,
                        durationMinutes: activity.durationMinutes,
                        distanceKm: activity.distanceKm,
                        notes: activity.notes,
                        now: now,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
