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
import '../../domain/models/player.dart';
import '../session/current_player_provider.dart';
import 'current_challenge_provider.dart';

/// Who is in a challenge.
///
/// The owner can take somebody out. Everybody else can take themselves out. The
/// owner cannot leave their own challenge, so they are not offered it.
class ChallengeMembersScreen extends ConsumerStatefulWidget {
  const ChallengeMembersScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeMembersScreen> createState() =>
      _ChallengeMembersScreenState();
}

class _ChallengeMembersScreenState
    extends ConsumerState<ChallengeMembersScreen> {
  bool _working = false;

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Asks, writes, and only then lets the row go.
  ///
  /// The list is the repository's stream, so the row leaves when the write has
  /// landed — never before it. A refused write leaves the member where they
  /// were and says so.
  Future<void> _remove(Challenge challenge, Player member) async {
    if (!await _confirm(
      title: AppStrings.membersRemoveTitle,
      body: AppStrings.membersRemoveBody,
      action: AppStrings.membersRemove,
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _working = true);
    try {
      await ref.read(challengeRepositoryProvider).removeMember(
            challengeId: challenge.id,
            ownerId: challenge.ownerId,
            playerId: member.id,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.membersRemoveFailed)),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _leave(Challenge challenge, Player me) async {
    if (!await _confirm(
      title: AppStrings.membersLeaveTitle,
      body: AppStrings.membersLeaveBody,
      action: AppStrings.membersLeaveAction,
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _working = true);
    try {
      await ref.read(challengeRepositoryProvider).leaveChallenge(
            challengeId: challenge.id,
            playerId: me.id,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.membersLeaveFailed)),
      );
      return;
    }
    if (!mounted) return;

    setState(() => _working = false);
    // The tabs cannot stay pointed at a challenge this player left.
    ref.read(selectedChallengeIdProvider.notifier).clear();
    context.go(AppRoutes.challenges);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(challengeByIdProvider(widget.challengeId));
    final players = ref.watch(playersProvider);
    final me = ref.watch(currentPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.membersTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.inviteTitle,
            icon: const Icon(Icons.person_add_alt),
            onPressed: () =>
                context.push(AppRoutes.challengeInvite(widget.challengeId)),
          ),
        ],
      ),
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

          final isOwner = me != null && challenge.ownerId == me.id;

          return AsyncView<List<Player>>(
            value: players,
            builder: (context, roster) {
              final members = [
                for (final id in challenge.memberIds)
                  _memberOf(roster, id),
              ];

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        for (final member in members)
                          ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(member.name),
                            subtitle: member.id == challenge.ownerId
                                ? const Text(AppStrings.challengesOwnerMark)
                                : null,
                            trailing: isOwner && member.id != challenge.ownerId
                                ? IconButton(
                                    tooltip: AppStrings.membersRemove,
                                    icon: const Icon(Icons.person_remove_outlined),
                                    onPressed: _working
                                        ? null
                                        : () => _remove(challenge, member),
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                  // The owner is never offered this: the repository refuses it,
                  // because a challenge with no owner has nobody to set rules.
                  if (me != null && !isOwner && challenge.isMember(me.id))
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: OutlinedButton.icon(
                          onPressed: _working ? null : () => _leave(challenge, me),
                          icon: const Icon(Icons.logout),
                          label: const Text(AppStrings.membersLeave),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// The roster entry for [id], or a placeholder when the roster has no such
  /// player — a member id outliving its player is the store's problem, not a
  /// reason to drop a row and make the member count disagree with the list.
  Player _memberOf(List<Player> roster, String id) {
    for (final player in roster) {
      if (player.id == id) return player;
    }
    return Player(id: id, name: AppStrings.membersUnknownPlayer);
  }
}
