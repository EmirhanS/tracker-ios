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
import '../../domain/exceptions.dart';
import '../../domain/models/scoring_rule.dart';
import '../../domain/models/season.dart';
import '../../domain/validation/rule_validator.dart';

/// Which kind of scoring the form is showing.
enum _ScoringKind { fixed, time, distance }

/// Edits one scoring rule of a draft season, or adds a new one.
class SeasonRuleEditScreen extends ConsumerWidget {
  const SeasonRuleEditScreen({
    super.key,
    required this.seasonId,
    required this.ruleId,
  });

  final String seasonId;

  /// [AppRoutes.newRuleId] means a new rule.
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(seasonByIdProvider(seasonId));

    return AsyncView<Season?>(
      value: season,
      builder: (context, season) {
        final rule = season == null || ruleId == AppRoutes.newRuleId
            ? null
            : season.ruleById(ruleId);

        if (season == null || (ruleId != AppRoutes.newRuleId && rule == null)) {
          return Scaffold(
            appBar: AppBar(title: const Text(AppStrings.seasonRuleEditTitle)),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: AppStrings.errorNotFound,
              body: AppStrings.seasonRulesTitle,
            ),
          );
        }

        return _RuleForm(
          key: ValueKey('$seasonId/$ruleId'),
          season: season,
          rule: rule,
        );
      },
    );
  }
}

class _RuleForm extends ConsumerStatefulWidget {
  const _RuleForm({super.key, required this.season, required this.rule});

  final Season season;

  /// Null when a new rule is being added.
  final ScoringRule? rule;

  @override
  ConsumerState<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends ConsumerState<_RuleForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _emoji = TextEditingController();
  final TextEditingController _points = TextEditingController(text: '1');
  final TextEditingController _minDuration = TextEditingController();
  final TextEditingController _minutesPerBlock = TextEditingController(
    text: '30',
  );

  final List<({TextEditingController km, TextEditingController points})>
      _tiers = [];

  /// The edited rule's id, or a fresh repository-issued one for a new rule.
  late final String _ruleId;

  _ScoringKind _kind = _ScoringKind.fixed;
  bool _isEnabled = true;
  bool _submitted = false;
  bool _saving = false;

  bool get _isNew => widget.rule == null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    // Minted once here, not in `_draft`: that getter runs on every build and
    // would burn a fresh id each frame. An edit keeps the id it came in with.
    _ruleId = rule?.id ?? ref.read(seasonRepositoryProvider).nextRuleId();
    if (rule == null) {
      _addTier(km: '3', points: '1');
      return;
    }

    _name.text = rule.name;
    _emoji.text = rule.emoji ?? '';
    _isEnabled = rule.isEnabled;

    switch (rule.scoring) {
      case FixedScoring(:final points, :final minDurationMinutes):
        _kind = _ScoringKind.fixed;
        _points.text = '$points';
        _minDuration.text =
            minDurationMinutes == null ? '' : '$minDurationMinutes';
      case TimeBasedScoring(
          :final pointsPerBlock,
          :final minutesPerBlock,
          :final minDurationMinutes,
        ):
        _kind = _ScoringKind.time;
        _points.text = '$pointsPerBlock';
        _minutesPerBlock.text = '$minutesPerBlock';
        _minDuration.text = '$minDurationMinutes';
      case DistanceTierScoring(:final tiers):
        _kind = _ScoringKind.distance;
        for (final tier in DistanceTierScoring(tiers: tiers).tiersLowestFirst) {
          _addTier(km: _trimZero(tier.minKm), points: '${tier.points}');
        }
    }

    if (_tiers.isEmpty) _addTier(km: '3', points: '1');
  }

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _points.dispose();
    _minDuration.dispose();
    _minutesPerBlock.dispose();
    for (final tier in _tiers) {
      tier.km.dispose();
      tier.points.dispose();
    }
    super.dispose();
  }

  void _addTier({String km = '', String points = ''}) {
    _tiers.add(
      (
        km: TextEditingController(text: km),
        points: TextEditingController(text: points),
      ),
    );
  }

  static String _trimZero(double value) {
    return value == value.roundToDouble() ? '${value.round()}' : '$value';
  }

  int get _pointsValue => int.tryParse(_points.text.trim()) ?? -1;

  /// The rule as the form currently stands.
  ScoringRule get _draft {
    final scoring = switch (_kind) {
      _ScoringKind.fixed => FixedScoring(
          points: _pointsValue,
          minDurationMinutes: int.tryParse(_minDuration.text.trim()),
        ),
      _ScoringKind.time => TimeBasedScoring(
          pointsPerBlock: _pointsValue,
          minutesPerBlock: int.tryParse(_minutesPerBlock.text.trim()) ?? 0,
          minDurationMinutes: int.tryParse(_minDuration.text.trim()) ?? 0,
        ),
      _ScoringKind.distance => DistanceTierScoring(
          tiers: [
            for (final tier in _tiers)
              DistanceTier(
                minKm: double.tryParse(
                      tier.km.text.trim().replaceAll(',', '.'),
                    ) ??
                    0,
                points: int.tryParse(tier.points.text.trim()) ?? -1,
              ),
          ],
        ),
    };

    return ScoringRule(
      id: _ruleId,
      name: _name.text,
      emoji: _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
      isEnabled: _isEnabled,
      scoring: scoring,
    );
  }

  List<RuleValidationError> get _errors =>
      RuleValidator.validate(_draft, otherRules: widget.season.rules);

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (_errors.isNotEmpty) return;

    final draft = _draft;
    final season = widget.season;
    final rules = _isNew
        ? [...season.rules, draft]
        : [
            for (final rule in season.rules)
              rule.id == draft.id ? draft : rule,
          ];

    setState(() => _saving = true);
    try {
      await ref
          .read(seasonRepositoryProvider)
          .updateSeason(season.copyWith(rules: rules));
      if (!mounted) return;
      context.pop();
    } on SeasonLockedException {
      _sayLocked();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    if (rule == null) return;

    final season = widget.season;
    final rules =
        season.rules.where((other) => other.id != rule.id).toList(growable: false);

    setState(() => _saving = true);
    try {
      await ref
          .read(seasonRepositoryProvider)
          .updateSeason(season.copyWith(rules: rules));
      if (!mounted) return;
      context.pop();
    } on SeasonLockedException {
      _sayLocked();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The season started while this screen was open, so the write was refused.
  void _sayLocked() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.seasonLocked)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = _submitted ? _errors : const <RuleValidationError>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew
              ? AppStrings.seasonRuleNewTitle
              : AppStrings.seasonRuleEditTitle,
        ),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: AppStrings.seasonRuleDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: AppStrings.seasonRuleName,
              errorText: _firstErrorText(errors, const {
                RuleValidationError.nameRequired,
                RuleValidationError.nameNotUnique,
              }),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emoji,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: AppStrings.seasonRuleEmoji,
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            value: _isEnabled,
            onChanged: (value) => setState(() => _isEnabled = value),
            title: const Text(AppStrings.seasonRuleEnabled),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.seasonRuleScoringType,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_ScoringKind>(
            selected: {_kind},
            onSelectionChanged: (selection) =>
                setState(() => _kind = selection.first),
            segments: const [
              ButtonSegment(
                value: _ScoringKind.fixed,
                label: Text(AppStrings.seasonRuleTypeFixed),
                icon: Icon(Icons.filter_1),
              ),
              ButtonSegment(
                value: _ScoringKind.time,
                label: Text(AppStrings.seasonRuleTypeTime),
                icon: Icon(Icons.timer_outlined),
              ),
              ButtonSegment(
                value: _ScoringKind.distance,
                label: Text(AppStrings.seasonRuleTypeDistance),
                icon: Icon(Icons.route_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._scoringFields(errors),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(AppStrings.describeScoring(_draft.scoring)),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final error in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  AppStrings.ruleError(error),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ],
      ),
      // Save stays out of the scrolling form so it is always in reach, the
      // same as the review screen.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text(AppStrings.save),
          ),
        ),
      ),
    );
  }

  /// The error text for the first error in [wanted], or null.
  String? _firstErrorText(
    List<RuleValidationError> errors,
    Set<RuleValidationError> wanted,
  ) {
    for (final error in errors) {
      if (wanted.contains(error)) return AppStrings.ruleError(error);
    }
    return null;
  }

  List<Widget> _scoringFields(List<RuleValidationError> errors) {
    final pointsError = _firstErrorText(errors, const {
      RuleValidationError.pointsOutOfRange,
    });

    return switch (_kind) {
      _ScoringKind.fixed => [
          _numberField(
            controller: _points,
            label: AppStrings.seasonRulePoints,
            errorText: pointsError,
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            controller: _minDuration,
            label: AppStrings.seasonRuleMinDurationOptional,
            errorText: _firstErrorText(errors, const {
              RuleValidationError.minDurationNotPositive,
            }),
          ),
        ],
      _ScoringKind.time => [
          _numberField(
            controller: _points,
            label: AppStrings.seasonRulePointsPerBlock,
            errorText: pointsError,
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            controller: _minutesPerBlock,
            label: AppStrings.seasonRuleMinutesPerBlock,
            errorText: _firstErrorText(errors, const {
              RuleValidationError.minutesPerBlockTooSmall,
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            controller: _minDuration,
            label: AppStrings.seasonRuleMinDuration,
            errorText: _firstErrorText(errors, const {
              RuleValidationError.minDurationNotPositive,
              RuleValidationError.minDurationBelowBlock,
            }),
          ),
        ],
      _ScoringKind.distance => [
          Text(
            AppStrings.seasonRuleTiers,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _tiers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: _numberField(
                      controller: _tiers[i].km,
                      label: AppStrings.seasonRuleTierFrom,
                      decimal: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _numberField(
                      controller: _tiers[i].points,
                      label: AppStrings.seasonRuleTierPoints,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.delete,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _tiers.length == 1
                        ? null
                        : () => setState(() {
                              final removed = _tiers.removeAt(i);
                              removed.km.dispose();
                              removed.points.dispose();
                            }),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(_addTier),
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.seasonRuleTierAdd),
            ),
          ),
        ],
    };
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(labelText: label, errorText: errorText),
      onChanged: (_) => setState(() {}),
    );
  }
}
