import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/app_dates.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/models/season.dart';

/// The rules of the running season, read only.
///
/// Every player can open this. Only the captain can change the rules, and only
/// before the season starts.
class ScoringRulesScreen extends ConsumerWidget {
  const ScoringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(activeSeasonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.scoringRulesTitle)),
      body: AsyncView<Season?>(
        value: season,
        builder: (context, season) {
          if (season == null) {
            return const EmptyState(
              icon: Icons.event_busy,
              title: AppStrings.dashboardNoSeasonTitle,
              body: AppStrings.dashboardNoSeasonBody,
            );
          }
          if (season.rules.isEmpty) {
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
                  '${season.name} · '
                  '${AppDates.dateRange(season.startDate, season.endDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final rule in season.rules) ScoringRuleTile(rule: rule),
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
