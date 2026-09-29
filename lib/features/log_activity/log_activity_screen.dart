import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/providers.dart';
import '../../domain/models/activity.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/models/challenge.dart';
import '../../domain/points/points_engine.dart';
import '../challenge/challenge_setup_providers.dart';
import '../challenge/challenge_switcher.dart';
import '../challenge/current_challenge_provider.dart';
import '../session/current_player_provider.dart';

/// Logs one activity against a rule of the running challenge.
///
/// The form shows only the inputs the chosen rule needs, and works the points
/// out live with the same [PointsEngine] the repository uses when it saves.
class LogActivityScreen extends ConsumerWidget {
  const LogActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(currentChallengeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.logTitle),
        actions: const [ChallengeSwitcherButton()],
      ),
      body: AsyncView<Challenge?>(
        value: challenge,
        builder: (context, challenge) {
          if (challenge == null) return const _NoChallenge();
          if (challenge.enabledRules.isEmpty) return const _NoRules();

          // A new key per challenge resets the form if the challenge changes.
          return _LogForm(challenge: challenge, key: ValueKey(challenge.id));
        },
      ),
    );
  }
}

class _NoChallenge extends ConsumerWidget {
  const _NoChallenge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);
    final setupRoute = ref.watch(challengeSetupRouteProvider);

    return EmptyState(
      icon: Icons.event_busy,
      title: AppStrings.dashboardNoChallengeTitle,
      body: isOwner
          ? AppStrings.dashboardNoChallengeOwnerBody
          : AppStrings.dashboardNoChallengeBody,
      actionLabel: isOwner ? AppStrings.dashboardSetUpChallenge : null,
      onAction: isOwner ? () => context.push(setupRoute) : null,
    );
  }
}

class _NoRules extends StatelessWidget {
  const _NoRules();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.rule,
      title: AppStrings.scoringRulesEmptyTitle,
      body: AppStrings.logNoRules,
    );
  }
}

class _LogForm extends ConsumerStatefulWidget {
  const _LogForm({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends ConsumerState<_LogForm> {
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _distance = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  ScoringRule? _rule;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = AppDates.dayOf(ref.read(clockProvider)());
    final rules = widget.challenge.enabledRules;
    _rule = rules.isEmpty ? null : rules.first;
  }

  @override
  void dispose() {
    _duration.dispose();
    _distance.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// What the player typed, as far as it parses.
  ActivityInput get _input => ActivityInput(
        durationMinutes: int.tryParse(_duration.text.trim()),
        distanceKm: double.tryParse(_distance.text.trim().replaceAll(',', '.')),
      );

  /// The text the fields could not read, if any.
  String? get _parseError {
    final rule = _rule;
    if (rule == null) return null;

    if (rule.scoring.requiresDuration &&
        _duration.text.trim().isNotEmpty &&
        int.tryParse(_duration.text.trim()) == null) {
      return AppStrings.logDurationNotANumber;
    }
    if (rule.scoring.requiresDistance &&
        _distance.text.trim().isNotEmpty &&
        double.tryParse(_distance.text.trim().replaceAll(',', '.')) == null) {
      return AppStrings.logDistanceNotANumber;
    }
    return null;
  }

  /// Why the date is not allowed, if it is not.
  String? get _dateError {
    final today = AppDates.dayOf(ref.read(clockProvider)());
    if (_date.isAfter(today)) return AppStrings.logDateInFuture;
    if (!widget.challenge.containsDate(_date)) {
      return AppStrings.logDateOutsideChallenge;
    }
    return null;
  }

  PointsResult? get _result {
    final rule = _rule;
    if (rule == null) return null;
    return PointsEngine.calculate(rule, _input);
  }

  bool get _canSubmit =>
      !_saving &&
      _rule != null &&
      _parseError == null &&
      _dateError == null &&
      _result is PointsSuccess;

  Future<void> _pickDate() async {
    final today = AppDates.dayOf(ref.read(clockProvider)());
    final challenge = widget.challenge;
    final first = AppDates.dayOf(challenge.startDate);
    final last = today.isBefore(challenge.endDate)
        ? today
        : AppDates.dayOf(challenge.endDate);

    // A challenge that has not begun yet leaves no day that can be picked. The
    // date field already says the date is outside the challenge, so stop here
    // rather than hand showDatePicker a range it asserts on.
    if (last.isBefore(first)) return;

    final picked = await showDatePicker(
      context: context,
      // _date is today, which is outside the range for a challenge that has
      // already ended.
      initialDate: _date.isBefore(first)
          ? first
          : (_date.isAfter(last) ? last : _date),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = AppDates.dayOf(picked));
  }

  Future<void> _submit() async {
    final rule = _rule;
    final player = ref.read(currentPlayerProvider);
    if (rule == null || player == null || !_canSubmit) return;

    setState(() => _saving = true);
    try {
      await ref.read(activityRepositoryProvider).log(
            playerId: player.id,
            challengeId: widget.challenge.id,
            rule: rule,
            date: _date,
            input: _input,
            notes: _notes.text,
          );
    } catch (_) {
      // The repository refused the write, or the store behind it could not be
      // reached. Saying nothing would leave the player thinking it was logged.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _duration.clear();
      _distance.clear();
      _notes.clear();
      _date = AppDates.dayOf(ref.read(clockProvider)());
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.logSaved)),
    );
    context.go(AppRoutes.activities);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = widget.challenge.enabledRules;
    final rule = _rule;
    final now = ref.watch(nowProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        DropdownButtonFormField<String>(
          initialValue: rule?.id,
          decoration: const InputDecoration(
            labelText: AppStrings.logRule,
            hintText: AppStrings.logRuleHint,
          ),
          items: [
            for (final option in rules)
              DropdownMenuItem<String>(
                value: option.id,
                child: Text(
                  option.emoji == null
                      ? option.name
                      : '${option.emoji}  ${option.name}',
                ),
              ),
          ],
          onChanged: (id) {
            setState(() {
              _rule = rules.firstWhere((option) => option.id == id);
              _duration.clear();
              _distance.clear();
            });
          },
        ),
        if (rule != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.describeScoring(rule.scoring),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        InputDecorator(
          decoration: InputDecoration(
            labelText: AppStrings.logDate,
            errorText: _dateError,
          ),
          child: InkWell(
            onTap: _pickDate,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppDates.relativeDay(_date, now: now)} · '
                  '${AppDates.fullDate(_date)}',
                ),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
        if (rule != null && rule.scoring.requiresDuration) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: AppStrings.logDuration,
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        if (rule != null && rule.scoring.requiresDistance) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: AppStrings.logDistance,
              prefixIcon: Icon(Icons.route_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _notes,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: AppStrings.logNotes,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Preview(parseError: _parseError, result: _result),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_saving ? AppStrings.save : AppStrings.logSubmit),
        ),
      ],
    );
  }
}

/// Shows what the activity will score, or why it will not.
class _Preview extends StatelessWidget {
  const _Preview({required this.parseError, required this.result});

  final String? parseError;
  final PointsResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;

    final (String text, bool isError) = switch ((parseError, result)) {
      (final String error, _) => (error, true),
      (_, PointsSuccess(:final points)) => (
          '${AppStrings.logPreview} ${AppStrings.formatPoints(points)}',
          false,
        ),
      (_, PointsFailure(:final error)) => (AppStrings.pointsError(error), true),
      _ => (AppStrings.logRuleHint, true),
    };

    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.info_outline : Icons.emoji_events_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
