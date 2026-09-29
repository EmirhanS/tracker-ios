import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/season.dart';
import '../../domain/validation/season_validator.dart';
import 'scoring_rules_screen.dart';

/// The last step of season setup: check everything, then start the season.
///
/// Starting locks the rules, so it asks first.
class SeasonReviewScreen extends ConsumerStatefulWidget {
  const SeasonReviewScreen({super.key, required this.seasonId});

  final String seasonId;

  @override
  ConsumerState<SeasonReviewScreen> createState() => _SeasonReviewScreenState();
}

class _SeasonReviewScreenState extends ConsumerState<SeasonReviewScreen> {
  bool _starting = false;

  Future<void> _start(Season season) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.seasonReviewConfirmTitle),
        content: const Text(AppStrings.seasonReviewConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.seasonReviewConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _starting = true);
    try {
      await ref.read(seasonRepositoryProvider).startSeason(season.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.seasonStarted)),
      );
      context.go(AppRoutes.dashboard);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final season = ref.watch(seasonByIdProvider(widget.seasonId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.seasonReviewTitle)),
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

          final problems = SeasonValidator.validateForStart(season);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            season.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppDates.dateRange(
                              season.startDate,
                              season.endDate,
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Text(
                        AppStrings.seasonReviewRules,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final rule in season.enabledRules)
                      ScoringRuleTile(rule: rule),
                    if (problems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final problem in problems)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                child: Text(
                                  AppStrings.seasonStartError(problem),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    onPressed: problems.isEmpty && !_starting
                        ? () => _start(season)
                        : null,
                    child: const Text(AppStrings.seasonReviewStart),
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
