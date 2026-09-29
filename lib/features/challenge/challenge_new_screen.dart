import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/validation/challenge_validator.dart';
import '../session/current_player_provider.dart';

/// Step one of challenge setup: the name and the dates.
class ChallengeNewScreen extends ConsumerStatefulWidget {
  const ChallengeNewScreen({super.key});

  @override
  ConsumerState<ChallengeNewScreen> createState() => _ChallengeNewScreenState();
}

class _ChallengeNewScreenState extends ConsumerState<ChallengeNewScreen> {
  final TextEditingController _name = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = AppDates.dayOf(ref.read(clockProvider)());
    _start = today;
    _end = DateTime(today.year, today.month + 3, today.day);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<ChallengeDetailsError> get _errors => ChallengeValidator.validateDetails(
        name: _name.text,
        startDate: _start,
        endDate: _end,
      );

  String? _errorText(ChallengeDetailsError error) =>
      _submitted && _errors.contains(error)
          ? AppStrings.challengeDetailsError(error)
          : null;

  Future<void> _pickDate({required bool isStart}) async {
    final today = AppDates.dayOf(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _start = AppDates.dayOf(picked);
        // Keep the end after the start without silently losing the choice.
        if (!_end.isAfter(_start)) {
          _end = DateTime(_start.year, _start.month + 3, _start.day);
        }
      } else {
        _end = AppDates.dayOf(picked);
      }
    });
  }

  Future<void> _create() async {
    setState(() => _submitted = true);
    if (_errors.isNotEmpty) return;

    final owner = ref.read(currentPlayerProvider);
    if (owner == null) return;

    setState(() => _saving = true);
    try {
      final challenge = await ref.read(challengeRepositoryProvider).createDraft(
            name: _name.text,
            startDate: _start,
            endDate: _end,
            ownerId: owner.id,
          );
      if (!mounted) return;
      context.go(AppRoutes.challengeTemplate(challenge.id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.challengeNewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: AppStrings.challengeName,
              hintText: AppStrings.challengeNameHint,
              errorText: _errorText(ChallengeDetailsError.nameRequired),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: AppStrings.challengeStartDate,
            date: _start,
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: AppStrings.challengeEndDate,
            date: _end,
            onTap: () => _pickDate(isStart: false),
            errorText: _errorText(ChallengeDetailsError.endNotAfterStart),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _create,
            child: const Text(AppStrings.challengeCreate),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: errorText),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppDates.fullDate(date)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}
