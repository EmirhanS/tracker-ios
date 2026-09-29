import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/challenge.dart';
import '../session/current_player_provider.dart';

/// The join code of one challenge, big enough to read out across a room.
///
/// This is where the create flow lands, and where the owner comes back to when
/// somebody asks for the code again.
class ChallengeInviteScreen extends ConsumerStatefulWidget {
  const ChallengeInviteScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeInviteScreen> createState() =>
      _ChallengeInviteScreenState();
}

class _ChallengeInviteScreenState extends ConsumerState<ChallengeInviteScreen> {
  bool _working = false;

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.inviteCopied)),
    );
  }

  /// Replaces the code, after saying what that costs.
  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.inviteNewCodeTitle),
        content: const Text(AppStrings.inviteNewCodeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.inviteNewCodeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await ref
          .read(challengeRepositoryProvider)
          .regenerateJoinCode(widget.challengeId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = ref.watch(challengeByIdProvider(widget.challengeId));
    final me = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.inviteTitle)),
      body: AsyncView<Challenge?>(
        value: challenge,
        builder: (context, challenge) {
          if (challenge == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: AppStrings.errorNotFound,
              body: AppStrings.challengesTitle,
            );
          }

          final isOwner = challenge.ownerId == me?.id;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                challenge.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FittedBox(
                  child: Text(
                    AppStrings.groupJoinCode(challenge.joinCode),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.inviteBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _copy(challenge.joinCode),
                icon: const Icon(Icons.copy),
                label: const Text(AppStrings.inviteCopy),
              ),
              if (isOwner) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _working ? null : _regenerate,
                  icon: const Icon(Icons.autorenew),
                  label: const Text(AppStrings.inviteNewCode),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text(AppStrings.inviteDone),
              ),
            ],
          );
        },
      ),
    );
  }
}
