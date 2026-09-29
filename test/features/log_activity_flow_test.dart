import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';
import 'package:sporttracker/domain/models/activity.dart';
import 'package:sporttracker/domain/models/scoring_rule.dart';
import 'package:sporttracker/domain/points/points_engine.dart';

import '../app_harness.dart';
import '../fixtures.dart';

/// How a rule reads in the picker: "🏋️  Gym session".
String _label(ScoringRule rule) => '${rule.emoji}  ${rule.name}';

/// The text the preview must show, worked out by the engine itself.
///
/// Asserting against this rather than a hard-coded string is the point: it
/// fails if the screen and [PointsEngine] ever stop agreeing.
String _previewText(ScoringRule rule, ActivityInput input) {
  return switch (PointsEngine.calculate(rule, input)) {
    PointsSuccess(:final points) =>
      '${AppStrings.logPreview} ${AppStrings.formatPoints(points)}',
    PointsFailure(:final error) => AppStrings.pointsError(error),
  };
}

Finder _durationField() =>
    find.widgetWithText(TextField, AppStrings.logDuration);

Finder _distanceField() =>
    find.widgetWithText(TextField, AppStrings.logDistance);

Finder _submitButton() =>
    find.widgetWithText(FilledButton, AppStrings.logSubmit);

bool _canSubmit(WidgetTester tester) =>
    tester.widget<FilledButton>(_submitButton()).onPressed != null;

/// Signs [playerName] in and opens the Log tab.
Future<TestWorld> openLog(
  WidgetTester tester, {
  String? playerName,
}) async {
  final world = await pumpWorld(tester);
  await signIn(tester, playerName ?? Fixture.dana.name);
  await tester.tap(find.text(AppStrings.navLog));
  await settle(tester);
  return world;
}

/// Opens the rule picker and takes [rule].
Future<void> chooseRule(WidgetTester tester, ScoringRule rule) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await settle(tester);
  await tester.tap(find.text(_label(rule)).last);
  await settle(tester);
}

void main() {
  group('The rule picker', () {
    testWidgets('opens on the first enabled rule', (tester) async {
      await openLog(tester);

      expect(find.text(AppStrings.logRule), findsOneWidget);
      expect(find.text(_label(Fixture.gym)), findsOneWidget);
    });

    testWidgets('lists every enabled rule and no switched-off one',
        (tester) async {
      await openLog(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);

      for (final rule in [
        Fixture.gym,
        Fixture.cycling,
        Fixture.running,
        Fixture.stretching,
      ]) {
        expect(
          find.text(_label(rule)),
          findsWidgets,
          reason: '${rule.name} is on and must be offered',
        );
      }

      // Swimming is switched off in the season.
      expect(Fixture.swimming.isEnabled, isFalse);
      expect(find.text(_label(Fixture.swimming)), findsNothing);
      expect(find.text(Fixture.swimming.name), findsNothing);
    });
  });

  group('The form asks only for what the rule needs', () {
    testWidgets('a fixed rule with a minimum duration asks for a duration',
        (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.gym);

      expect(Fixture.gym.scoring.requiresDuration, isTrue);
      expect(_durationField(), findsOneWidget);
      expect(_distanceField(), findsNothing);
    });

    testWidgets('a time-based rule asks for a duration', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.cycling);

      expect(_durationField(), findsOneWidget);
      expect(_distanceField(), findsNothing);
    });

    testWidgets('a distance-tier rule asks for a distance', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.running);

      expect(_distanceField(), findsOneWidget);
      expect(_durationField(), findsNothing);
    });

    testWidgets('a fixed rule with no minimum asks for neither', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.stretching);

      expect(_durationField(), findsNothing);
      expect(_distanceField(), findsNothing);
      // Nothing to enter, so it can be logged straight away.
      expect(_canSubmit(tester), isTrue);
    });

    testWidgets('switching rules clears what was typed for the last one',
        (tester) async {
      await openLog(tester);

      await tester.enterText(_durationField(), '60');
      await settle(tester);
      expect(
        find.text(
          _previewText(Fixture.gym, const ActivityInput(durationMinutes: 60)),
        ),
        findsOneWidget,
      );

      await chooseRule(tester, Fixture.cycling);
      expect(
        find.text(_previewText(Fixture.cycling, const ActivityInput())),
        findsOneWidget,
      );
    });
  });

  group('The live preview agrees with the points engine', () {
    testWidgets('for a time-based rule, block by block', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.cycling);

      // 1 point per finished 30 minutes, minimum 30.
      for (final minutes in [30, 45, 59, 60, 89, 90]) {
        final input = ActivityInput(durationMinutes: minutes);
        await tester.enterText(_durationField(), '$minutes');
        await settle(tester);

        expect(
          find.text(_previewText(Fixture.cycling, input)),
          findsOneWidget,
          reason: '$minutes minutes of cycling',
        );
        expect(_canSubmit(tester), isTrue);
      }
    });

    testWidgets('for a distance rule, tier by tier', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.running);

      // Tiers are 3 km, 5 km and 10 km. The boundaries score, just under does
      // not.
      for (final km in [3.0, 4.9, 5.0, 9.9, 10.0, 42.0]) {
        final input = ActivityInput(distanceKm: km);
        await tester.enterText(_distanceField(), '$km');
        await settle(tester);

        expect(
          find.text(_previewText(Fixture.running, input)),
          findsOneWidget,
          reason: '$km km of running',
        );
      }
    });

    testWidgets('a comma is read as a decimal point', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.running);

      await tester.enterText(_distanceField(), '7,5');
      await settle(tester);

      expect(
        find.text(
          _previewText(Fixture.running, const ActivityInput(distanceKm: 7.5)),
        ),
        findsOneWidget,
      );
      expect(find.text('${AppStrings.logPreview} 2 points'), findsOneWidget);
    });
  });

  group('A value below the minimum is refused', () {
    testWidgets('too short for a fixed rule', (tester) async {
      await openLog(tester);

      await tester.enterText(_durationField(), '44');
      await settle(tester);

      expect(
        find.text('This activity must last at least 45 min to score.'),
        findsOneWidget,
      );
      expect(_canSubmit(tester), isFalse);

      // One more minute and it scores.
      await tester.enterText(_durationField(), '45');
      await settle(tester);
      expect(find.text('${AppStrings.logPreview} 3 points'), findsOneWidget);
      expect(_canSubmit(tester), isTrue);
    });

    testWidgets('too short for a time-based rule', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.cycling);

      await tester.enterText(_durationField(), '29');
      await settle(tester);

      expect(
        find.text('This activity must last at least 30 min to score.'),
        findsOneWidget,
      );
      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('below the lowest distance tier', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.running);

      await tester.enterText(_distanceField(), '2.9');
      await settle(tester);

      expect(find.text('You need at least 3 km to score.'), findsOneWidget);
      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('nothing entered at all', (tester) async {
      await openLog(tester);

      expect(find.text('Enter how long the activity was.'), findsOneWidget);
      expect(_canSubmit(tester), isFalse);

      await chooseRule(tester, Fixture.running);
      expect(find.text('Enter how far you went.'), findsOneWidget);
      expect(_canSubmit(tester), isFalse);
    });

    testWidgets('a refused value is never written to the repository',
        (tester) async {
      final world = await openLog(tester);

      await tester.enterText(_durationField(), '10');
      await settle(tester);
      // Tapping a disabled button does nothing, but prove it anyway.
      await tester.tap(_submitButton(), warnIfMissed: false);
      await settle(tester);

      expect(await world.activitiesOf(Fixture.dana.id), isEmpty);
    });
  });

  group('The date field', () {
    testWidgets('opens a picker inside the season', (tester) async {
      await openLog(tester);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('a season that has not begun yet does not crash the screen',
        (tester) async {
      // Nothing stops a captain from starting a season dated next month, and
      // then there is no day between its start and today to offer.
      await pumpWorld(
        tester,
        seasons: [
          Fixture.season().copyWith(
            startDate: DateTime(2026, 11, 1),
            endDate: DateTime(2027, 2, 1),
          ),
        ],
        activities: const [],
      );
      await signIn(tester, Fixture.dana.name);
      await tester.tap(find.text(AppStrings.navLog));
      await settle(tester);

      expect(find.text(AppStrings.logDateOutsideSeason), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_today));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(_canSubmit(tester), isFalse);
    });
  });

  group('A logged activity', () {
    testWidgets('is saved with the points the preview promised',
        (tester) async {
      final world = await openLog(tester);
      await chooseRule(tester, Fixture.cycling);

      await tester.enterText(_durationField(), '90');
      await settle(tester);
      expect(find.text('${AppStrings.logPreview} 3 points'), findsOneWidget);

      await tester.tap(_submitButton());
      await settle(tester);

      final mine = await world.activitiesOf(Fixture.dana.id);
      expect(mine, hasLength(1));
      expect(mine.single.ruleName, Fixture.cycling.name);
      expect(mine.single.durationMinutes, 90);
      expect(mine.single.points, 3);
      expect(mine.single.date, Fixture.now.dateOnly);
    });

    testWidgets('shows up on My activities', (tester) async {
      await openLog(tester);
      await chooseRule(tester, Fixture.cycling);

      await tester.enterText(_durationField(), '90');
      await settle(tester);
      await tester.tap(_submitButton());
      await settle(tester);

      // Saving moves the player to My activities. The title also names the
      // tab in the bottom bar, so look at the app bar.
      expect(
        find.widgetWithText(AppBar, AppStrings.activitiesTitle),
        findsOneWidget,
      );
      expect(find.byType(ActivityTile), findsOneWidget);
      expect(find.text(Fixture.cycling.name), findsOneWidget);
      expect(find.text('3 ${AppStrings.pointsShort}'), findsOneWidget);
    });

    testWidgets('adds its points to the dashboard totals', (tester) async {
      await openLog(tester, playerName: Fixture.mira.name);
      await chooseRule(tester, Fixture.stretching);

      await tester.tap(_submitButton());
      await settle(tester);

      await tester.tap(find.text(AppStrings.navDashboard));
      await settle(tester);

      // Stretching is worth 2, and today is inside the current week.
      expect(
        find.text('${Fixture.miraSeasonPoints + 2}'),
        findsOneWidget,
      );
      expect(find.text('${Fixture.miraWeekPoints + 2}'), findsOneWidget);
    });
  });
}

extension on DateTime {
  /// The same day with the time stripped, the way the repository stores it.
  DateTime get dateOnly => DateTime(year, month, day);
}
