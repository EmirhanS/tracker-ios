import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/models/challenge.dart';
import '../../domain/models/scoring_rule.dart';
import '../session/current_player_provider.dart';
import 'current_challenge_provider.dart';

/// The rules of the challenge the tabs are on, read only.
///
/// Every member can open this. Its owner gets an edit action through to the
/// rules editor, because a running challenge keeps its rules in the owner's
/// hands — points already earned never move when a rule changes.
class ScoringRulesScreen extends ConsumerWidget {
  const ScoringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(currentChallengeProvider);
    final me = ref.watch(currentPlayerProvider);
    final owned = challenge.value;
    final isOwner = owned != null && me != null && owned.ownerId == me.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.scoringRulesTitle),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: AppStrings.scoringRulesEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(AppRoutes.challengeRules(owned.id)),
            ),
        ],
      ),
      body: AsyncView<Challenge?>(
        value: challenge,
        builder: (context, challenge) {
          if (challenge == null) {
            return const EmptyState(
              icon: Icons.event_busy,
              title: AppStrings.dashboardNoChallengeTitle,
              body: AppStrings.dashboardNoChallengeBody,
            );
          }
          if (challenge.rules.isEmpty) {
            return const EmptyState(
              icon: Icons.rule,
              title: AppStrings.scoringRulesEmptyTitle,
              body: AppStrings.scoringRulesEmptyBody,
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  '${challenge.name} · '
                  '${AppDates.dateRange(challenge.startDate, challenge.endDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final rule in challenge.rules) ScoringRuleTile(rule: rule),
            ],
          );
        },
      ),
    );
  }
}

/// One rule shown as name, emoji and a plain description of how it scores.
class ScoringRuleTile extends StatelessWidget {
  const ScoringRuleTile({super.key, required this.rule, this.onTap});

  final ScoringRule rule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emoji = rule.emoji;

    return ListTile(
      onTap: onTap,
      enabled: onTap != null || rule.isEnabled,
      leading: CircleAvatar(
        backgroundColor: rule.isEnabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: emoji == null
            ? const Icon(Icons.fitness_center)
            : Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(rule.name, overflow: TextOverflow.ellipsis),
          ),
          if (!rule.isEnabled) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppStrings.scoringRulesDisabled,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(AppStrings.describeScoring(rule.scoring)),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}
