import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/challenge.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/validation/rule_validator.dart';

/// Step three of challenge setup: switch rules on or off, edit them, add new ones.
class ChallengeRulesScreen extends ConsumerWidget {
  const ChallengeRulesScreen({super.key, required this.challengeId});

  final String challengeId;

  /// Switches [rule] on or off.
  ///
  /// This works on a running challenge too. The owner keeps the rules in their
  /// hands for the whole challenge, and nobody's points move when a rule
  /// changes, because `Activity` froze its own points at log time.
  Future<void> _setEnabled(
    WidgetRef ref,
    Challenge challenge,
    ScoringRule rule,
    bool isEnabled,
  ) async {
    final rules = [
      for (final other in challenge.rules)
        other.id == rule.id ? other.copyWith(isEnabled: isEnabled) : other,
    ];
    await ref
        .read(challengeRepositoryProvider)
        .updateChallenge(challenge.copyWith(rules: rules));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = ref.watch(challengeByIdProvider(challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.challengeRulesTitle)),
      body: AsyncView<Challenge?>(
        value: challenge,
        builder: (context, challenge) {
          if (challenge == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: AppStrings.errorNotFound,
              body: AppStrings.challengeNewTitle,
            );
          }

          final enabledCount = challenge.enabledRules.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.challengeRulesBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Editing the rules of a challenge people are already
                    // scoring in is allowed, and the one thing the owner has to
                    // know about it is that it does not rewrite history.
                    if (challenge.isActive) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.challengeRulesLiveNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: challenge.rules.isEmpty
                    ? const EmptyState(
                        icon: Icons.rule,
                        title: AppStrings.scoringRulesEmptyTitle,
                        body: AppStrings.challengeRulesBody,
                      )
                    : ListView(
                        children: [
                          for (final rule in challenge.rules)
                            _RuleRow(
                              rule: rule,
                              otherRules: challenge.rules,
                              onToggle: (value) =>
                                  _setEnabled(ref, challenge, rule, value),
                              onTap: () => context.push(
                                AppRoutes.challengeRule(challengeId, rule.id),
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
                            AppStrings.challengeRulesNoneEnabled,
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
                                AppRoutes.challengeNewRule(challengeId),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text(AppStrings.challengeRulesAdd),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            // A running challenge has nothing left to review:
                            // the edits are already live, so the only thing
                            // left to do is leave.
                            child: challenge.isActive
                                ? FilledButton(
                                    onPressed: () => context.pop(),
                                    child: const Text(AppStrings.done),
                                  )
                                : FilledButton(
                                    onPressed: enabledCount == 0
                                        ? null
                                        : () => context.push(
                                              AppRoutes.challengeReview(
                                                challengeId,
                                              ),
                                            ),
                                    child: const Text(
                                      AppStrings.challengeRulesReview,
                                    ),
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
      title: Text(rule.name.trim().isEmpty ? AppStrings.challengeRuleName : rule.name),
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
