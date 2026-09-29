import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/exceptions.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/models/season.dart';
import '../../domain/validation/rule_validator.dart';

/// Step three of season setup: switch rules on or off, edit them, add new ones.
class SeasonRulesScreen extends ConsumerWidget {
  const SeasonRulesScreen({super.key, required this.seasonId});

  final String seasonId;

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    Season season,
    ScoringRule rule,
    bool isEnabled,
  ) async {
    final rules = [
      for (final other in season.rules)
        other.id == rule.id ? other.copyWith(isEnabled: isEnabled) : other,
    ];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(seasonRepositoryProvider)
          .updateSeason(season.copyWith(rules: rules));
    } on SeasonLockedException {
      // The season started while this screen was open. Say so rather than
      // letting the exception escape into the framework.
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.seasonLocked)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final season = ref.watch(seasonByIdProvider(seasonId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.seasonRulesTitle)),
      body: AsyncView<Season?>(
        value: season,
        builder: (context, season) {
          if (season == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: AppStrings.errorNotFound,
              body: AppStrings.seasonNewTitle,
            );
          }

          final enabledCount = season.enabledRules.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  AppStrings.seasonRulesBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: season.rules.isEmpty
                    ? const EmptyState(
                        icon: Icons.rule,
                        title: AppStrings.scoringRulesEmptyTitle,
                        body: AppStrings.seasonRulesBody,
                      )
                    : ListView(
                        children: [
                          for (final rule in season.rules)
                            _RuleRow(
                              rule: rule,
                              otherRules: season.rules,
                              onToggle: (value) =>
                                  _setEnabled(context, ref, season, rule, value),
                              onTap: () => context.push(
                                AppRoutes.seasonRule(seasonId, rule.id),
                              ),
                            ),
                        ],
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      if (enabledCount == 0)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            AppStrings.seasonRulesNoneEnabled,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                AppRoutes.seasonNewRule(seasonId),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text(AppStrings.seasonRulesAdd),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: enabledCount == 0
                                  ? null
                                  : () => context.push(
                                        AppRoutes.seasonReview(seasonId),
                                      ),
                              child: const Text(AppStrings.seasonRulesReview),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.otherRules,
    required this.onToggle,
    required this.onTap,
  });

  final ScoringRule rule;
  final List<ScoringRule> otherRules;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problems = RuleValidator.validate(rule, otherRules: otherRules);
    final emoji = rule.emoji;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: rule.isEnabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: emoji == null
            ? const Icon(Icons.fitness_center)
            : Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(rule.name.trim().isEmpty ? AppStrings.seasonRuleName : rule.name),
      subtitle: Text(
        problems.isEmpty
            ? AppStrings.describeScoring(rule.scoring)
            : AppStrings.ruleError(problems.first),
        style: problems.isEmpty
            ? null
            : theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
      ),
      trailing: Switch(value: rule.isEnabled, onChanged: onToggle),
    );
  }
}
