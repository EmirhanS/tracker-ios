import 'package:flutter/material.dart';

import '../format/app_dates.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import 'points_chip.dart';

/// One row in an activity list: what it was, when, and what it scored.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.emoji,
    required this.ruleName,
    required this.date,
    required this.points,
    this.durationMinutes,
    this.distanceKm,
    this.notes,
    this.now,
  });

  final String? emoji;
  final String ruleName;
  final DateTime date;
  final int points;
  final int? durationMinutes;
  final double? distanceKm;
  final String? notes;
  final DateTime? now;

  /// "Today · 45 min" or "Tue 22 Sep · 5.2 km".
  String get _subtitle {
    final parts = <String>[AppDates.relativeDay(date, now: now)];

    final duration = durationMinutes;
    if (duration != null) parts.add(AppStrings.formatMinutes(duration));

    final distance = distanceKm;
    if (distance != null) parts.add(AppStrings.formatKm(distance));

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emoji = this.emoji;
    final notes = this.notes;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: emoji == null
            ? Icon(Icons.fitness_center, color: theme.colorScheme.onSurface)
            : Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(ruleName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_subtitle),
          if (notes != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      trailing: PointsChip(points: points, showSign: true),
      isThreeLine: notes != null,
    );
  }
}
