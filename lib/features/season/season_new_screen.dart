import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/format/app_dates.dart';
import '../../core/router/app_routes.dart';
import '../../core/strings/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/validation/season_validator.dart';
import '../session/current_player_provider.dart';

/// Step one of season setup: the name and the dates.
class SeasonNewScreen extends ConsumerStatefulWidget {
  const SeasonNewScreen({super.key});

  @override
  ConsumerState<SeasonNewScreen> createState() => _SeasonNewScreenState();
}

class _SeasonNewScreenState extends ConsumerState<SeasonNewScreen> {
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

  List<SeasonDetailsError> get _errors => SeasonValidator.validateDetails(
        name: _name.text,
        startDate: _start,
        endDate: _end,
      );

  String? _errorText(SeasonDetailsError error) =>
      _submitted && _errors.contains(error)
          ? AppStrings.seasonDetailsError(error)
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

    final captain = ref.read(currentPlayerProvider);
    if (captain == null) return;

    setState(() => _saving = true);
    try {
      final season = await ref.read(seasonRepositoryProvider).createDraft(
            name: _name.text,
            startDate: _start,
            endDate: _end,
            captainId: captain.id,
          );
      if (!mounted) return;
      context.go(AppRoutes.seasonTemplate(season.id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.seasonNewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: AppStrings.seasonName,
              hintText: AppStrings.seasonNameHint,
              errorText: _errorText(SeasonDetailsError.nameRequired),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: AppStrings.seasonStartDate,
            date: _start,
            onTap: () => _pickDate(isStart: true),
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: AppStrings.seasonEndDate,
            date: _end,
            onTap: () => _pickDate(isStart: false),
            errorText: _errorText(SeasonDetailsError.endNotAfterStart),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _create,
            child: const Text(AppStrings.seasonCreate),
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
