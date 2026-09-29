import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/challenge.dart';
import 'current_challenge_provider.dart';

/// The challenge switcher, in the app bar of every screen of the main shell.
///
/// It names the challenge the tabs are scoped to and opens a picker of the
/// player's own challenges, plus a way through to the whole list.
class ChallengeSwitcherButton extends ConsumerWidget {
  const ChallengeSwitcherButton({super.key});

  /// The most this may take out of the app bar, so the screen title survives.
  static const double _maxWidth = 150;

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _ChallengePicker(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = ref.watch(currentChallengeProvider);

    // No name until there is one. Drawing "No challenge" over a list that is
    // still loading says the player is in none, which is a different thing.
    final label = switch (challenge) {
      AsyncData(:final value) =>
        value?.name ?? AppStrings.challengesNoneChosen,
      AsyncError() => AppStrings.errorGeneric,
      _ => '',
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: TextButton(
        onPressed: () => _open(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The sheet the switcher opens.
class _ChallengePicker extends ConsumerWidget {
  const _ChallengePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenges = ref.watch(myChallengesProvider).value ?? const [];
    final current = ref.watch(currentChallengeProvider).value;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.challengesPick,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final challenge in challenges.where(
            (challenge) => challenge.isActive,
          ))
            _PickerRow(challenge: challenge, isCurrent: challenge.id == current?.id),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.format_list_bulleted),
            title: const Text(AppStrings.challengesAll),
            // Pushed, not gone to: the list is somewhere you come back from,
            // and leaving the tabs on the stack keeps everything they are
            // showing subscribed while you are away.
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.challenges);
            },
          ),
        ],
      ),
    );
  }
}

class _PickerRow extends ConsumerWidget {
  const _PickerRow({required this.challenge, required this.isCurrent});

  final Challenge challenge;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: isCurrent,
      leading: Icon(
        isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(challenge.name),
      subtitle: Text(
        AppDates.dateRange(challenge.startDate, challenge.endDate),
      ),
      // The sheet closes onto the tab that is already there, so this one does
      // not have to wait for the frame the way the screens that navigate do.
      onTap: () {
        ref.read(selectedChallengeIdProvider.notifier).select(challenge.id);
        Navigator.of(context).pop();
      },
    );
  }
}
