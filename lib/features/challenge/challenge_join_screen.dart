import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/codes/join_code.dart';
import '../../domain/models/challenge.dart';
import '../session/current_player_provider.dart';
import 'challenge_selection.dart';
import 'scoring_rules_screen.dart';

/// Keeps the field in the shape the store holds codes in, as it is typed.
///
/// People write a code down with a space or a dash in it and type it back in
/// lower case, so the field takes all of that and shows `ABCDEF`.
class JoinCodeInputFormatter extends TextInputFormatter {
  const JoinCodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = JoinCode.normalize(newValue.text);
    final capped = normalized.length > JoinCode.length
        ? normalized.substring(0, JoinCode.length)
        : normalized;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// Which part of joining the screen is showing.
enum _Stage {
  /// Waiting for a code.
  typing,

  /// The code matched nothing.
  notFound,

  /// The code matched a challenge the player is already in.
  alreadyMember,

  /// The code matched: here is what joining would get you.
  preview,
}

/// Joins a challenge with a code somebody read out.
///
/// The code is looked up first and shown as a preview, because a code is easy
/// to mistype into somebody else's challenge and joining is a thing other
/// people see.
class ChallengeJoinScreen extends ConsumerStatefulWidget {
  const ChallengeJoinScreen({super.key});

  @override
  ConsumerState<ChallengeJoinScreen> createState() =>
      _ChallengeJoinScreenState();
}

class _ChallengeJoinScreenState extends ConsumerState<ChallengeJoinScreen> {
  final TextEditingController _code = TextEditingController();

  _Stage _stage = _Stage.typing;
  Challenge? _found;
  bool _working = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _codeLooksLikeOne => JoinCode.isValid(_code.text);

  void _onTyped() {
    // Any edit throws the last answer away: it belonged to a different code.
    setState(() {
      _stage = _Stage.typing;
      _found = null;
    });
  }

  Future<void> _lookUp() async {
    final me = ref.read(currentPlayerProvider);
    if (me == null || !_codeLooksLikeOne) return;

    setState(() => _working = true);
    Challenge? found;
    try {
      found = await ref
          .read(challengeRepositoryProvider)
          .getByJoinCode(_code.text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _working = false;
      _found = found;
      _stage = switch (found) {
        null => _Stage.notFound,
        final Challenge challenge when challenge.isMember(me.id) =>
          _Stage.alreadyMember,
        _ => _Stage.preview,
      };
    });
  }

  Future<void> _join() async {
    final me = ref.read(currentPlayerProvider);
    final challenge = _found;
    if (me == null || challenge == null) return;

    setState(() => _working = true);
    try {
      await ref.read(challengeRepositoryProvider).joinByCode(
            code: _code.text,
            playerId: me.id,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.joinFailed)),
      );
      return;
    }

    // The store's stream reaches the providers on the next turn of the loop,
    // not inside the write. Letting it land before the tabs are pointed at the
    // new challenge means the screens that mount next read a member list that
    // already has this player in it.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() => _working = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.joinSucceeded)),
    );
    _openChallenge(challenge);
  }

  /// Points the tabs at [challenge] and goes there.
  void _openChallenge(Challenge challenge) {
    selectChallenge(ref, challenge.id);
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final found = _found;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.joinTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _code,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: const [JoinCodeInputFormatter()],
            style: const TextStyle(letterSpacing: 6, fontSize: 22),
            decoration: const InputDecoration(
              labelText: AppStrings.joinCodeLabel,
              hintText: AppStrings.joinCodeHint,
            ),
            onChanged: (_) => _onTyped(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _codeLooksLikeOne && !_working ? _lookUp : null,
            child: const Text(AppStrings.joinLookUp),
          ),
          if (_stage == _Stage.notFound) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.joinNotFound,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_stage == _Stage.alreadyMember && found != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              AppStrings.joinAlreadyMember,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => _openChallenge(found),
              child: const Text(AppStrings.joinOpenInstead),
            ),
          ],
          if (_stage == _Stage.preview && found != null)
            _Preview(
              challenge: found,
              onJoin: _working ? null : _join,
              onCancel: _working ? null : _onTyped,
            ),
        ],
      ),
    );
  }
}

/// What joining would get you, before it is done.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.challenge,
    required this.onJoin,
    required this.onCancel,
  });

  final Challenge challenge;
  final VoidCallback? onJoin;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.joinPreviewTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            challenge.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${AppDates.dateRange(challenge.startDate, challenge.endDate)} Â· '
            '${AppStrings.formatMembers(challenge.memberIds.length)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final rule in challenge.enabledRules)
            ScoringRuleTile(rule: rule),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onJoin,
            child: const Text(AppStrings.joinConfirm),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onCancel,
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }
}
