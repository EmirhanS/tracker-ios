import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/season.dart';
import '../../domain/templates/season_templates.dart';

/// Step two of season setup: pick the set of rules to start from.
class SeasonTemplateScreen extends ConsumerWidget {
  const SeasonTemplateScreen({super.key, required this.seasonId});

  final String seasonId;

  Future<void> _use(
    BuildContext context,
    WidgetRef ref,
    Season season,
    SeasonTemplate template,
  ) async {
    // Ids come from the repository, not a local counter: a counter scoped to
    // this call hands every season the same `rule_1..rule_5`.
    final repository = ref.read(seasonRepositoryProvider);
    final rules = template.buildRules(repository.nextRuleId);

    await repository.updateSeason(season.copyWith(rules: rules));

    if (!context.mounted) return;
    context.go(AppRoutes.seasonRules(seasonId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final season = ref.watch(seasonByIdProvider(seasonId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.seasonTemplateTitle)),
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                AppStrings.seasonTemplateBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final template in SeasonTemplates.all)
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
                                Expanded(child: Text(blueprint.name)),
                                Text(
                                  AppStrings.describeScoring(blueprint.scoring),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: () => _use(context, ref, season, template),
                          child: const Text(AppStrings.seasonTemplateUse),
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
