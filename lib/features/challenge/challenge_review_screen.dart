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
import '../../domain/models/challenge.dart';
import '../../domain/validation/challenge_validator.dart';
import 'challenge_selection.dart';
import 'scoring_rules_screen.dart';

/// The last step of challenge setup: check everything, then start the challenge.
///
/// Starting locks the rules, so it asks first.
class ChallengeReviewScreen extends ConsumerStatefulWidget {
  const ChallengeReviewScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeReviewScreen> createState() => _ChallengeReviewScreenState();
}

class _ChallengeReviewScreenState extends ConsumerState<ChallengeReviewScreen> {
  bool _starting = false;

  Future<void> _start(Challenge challenge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.challengeReviewConfirmTitle),
        content: const Text(AppStrings.challengeReviewConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.challengeReviewConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _starting = true);
    try {
      await ref.read(challengeRepositoryProvider).startChallenge(challenge.id);
      // The store's stream reaches the providers on the next turn of the loop,
      // not inside the write. Letting it land here means the screens that come
      // after this already see a challenge that is running.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.challengeStarted)),
      );
      // The tabs follow the challenge that was just started, not whichever one
      // the player happened to be looking at before setup. A challenge with
      // one member in it is not much of a challenge either, so the last step
      // of setup is the code to hand round.
      selectChallenge(ref, challenge.id);
      context.go(AppRoutes.challengeInvite(challenge.id));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = ref.watch(challengeByIdProvider(widget.challengeId));

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.challengeReviewTitle)),
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

          final problems = ChallengeValidator.validateForStart(challenge);

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
                            challenge.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppDates.dateRange(
                              challenge.startDate,
                              challenge.endDate,
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
                        AppStrings.challengeReviewRules,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final rule in challenge.enabledRules)
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
                                  AppStrings.challengeStartError(problem),
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
                        ? () => _start(challenge)
                        : null,
                    child: const Text(AppStrings.challengeReviewStart),
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
