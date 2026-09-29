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
import '../../domain/templates/challenge_templates.dart';

/// Step two of challenge setup: pick the set of rules to start from.
class ChallengeTemplateScreen extends ConsumerWidget {
  const ChallengeTemplateScreen({super.key, required this.challengeId});

  final String challengeId;

  Future<void> _use(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
    ChallengeTemplate template,
  ) async {
    // Ids come from the repository, not a local counter: a counter scoped to
    // this call hands every challenge the same `rule_1..rule_5`.
    final repository = ref.read(challengeRepositoryProvider);
    final rules = template.buildRules(repository.nextRuleId);

    await repository.updateChallenge(challenge.copyWith(rules: rules));

    if (!context.mounted) return;
    context.go(AppRoutes.challengeRules(challengeId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = ref.watch(challengeByIdProvider(challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.challengeTemplateTitle)),
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                AppStrings.challengeTemplateBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final template in ChallengeTemplates.all)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          template.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        for (final blueprint in template.blueprints)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                Text(blueprint.emoji ?? '•'),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(flex: 2, child: Text(blueprint.name)),
                                const SizedBox(width: AppSpacing.sm),
                                // Both sides have to give: a five-tier ladder
                                // like the Runner run rule is wider than the
                                // whole row on a phone, so it wraps rather
                                // than overflowing.
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    AppStrings.describeScoring(
                                      blueprint.scoring,
                                    ),
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: () => _use(context, ref, challenge, template),
                          child: const Text(AppStrings.challengeTemplateUse),
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
