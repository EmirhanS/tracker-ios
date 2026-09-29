import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/async_view.dart';
import 'package:sporttracker/core/widgets/points_chip.dart';

import '../app_harness.dart';
import '../doubles/scripted_world.dart';
import '../fixtures.dart';

/// The points totals are summed from a stream, so there is a stretch of time
/// with no number to show and, if the read fails, no number ever. Both used to
/// come out as a plain `0`, which is not "waiting" or "broken" — it is a claim
/// that the player has no points at all, right next to a list that is honestly
/// showing a spinner.
///
/// The in-memory repository cannot show this: its first batch lands in the same
/// frame as the subscription. These tests hold it back by hand.
void main() {
  group('Dashboard totals while the activities are still coming', () {
    testWidgets('show a spinner rather than a zero', (tester) async {
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
      );
      await signIn(tester, Fixture.mira.name);

      // Nothing has been emitted, so there is no total to state yet.
      expect(find.byType(StatTile), findsNothing);
      expect(find.text('0'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      repository.emit();
      await settle(tester);

      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.text('${Fixture.miraChallengePoints}'), findsOneWidget);
      expect(find.text('${Fixture.miraWeekPoints}'), findsOneWidget);
    });

    testWidgets('a failed read shows the error, not a zero', (tester) async {
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
        giveUpOnError: true,
      );
      await signIn(tester, Fixture.mira.name);

      repository.fail();
      await settle(tester);

      expect(find.text('0'), findsNothing);
      expect(find.byType(StatTile), findsNothing);
      // Both tiles and the recent-activities list below them.
      expect(find.byType(ErrorView), findsNWidgets(3));
    });

    testWidgets('a failure that Riverpod is still retrying reads as waiting',
        (tester) async {
      // Riverpod retries a failed provider before it gives up, and counts
      // itself loading while it does. The tiles have to sit at the spinner for
      // that stretch too — a "0" that later turns into a real total is worse
      // than a spinner that does.
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
      );
      await signIn(tester, Fixture.mira.name);

      repository.fail();
      await settle(tester);

      expect(find.text('0'), findsNothing);
      expect(find.byType(StatTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('a real zero is still shown as a zero', (tester) async {
      // Dana has logged nothing. "No points yet" is a fact, and has to survive
      // the fix that stopped loading and errors claiming the same thing.
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
      );
      await signIn(tester, Fixture.dana.name);

      repository.emit();
      await settle(tester);

      expect(find.byType(StatTile), findsNWidgets(2));
      expect(find.text('0'), findsNWidgets(2));
      expect(find.byType(ErrorView), findsNothing);
    });
  });

  group('The My activities challenge total in the app bar', () {
    testWidgets('stays blank until there is a number', (tester) async {
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
      );
      await signIn(tester, Fixture.mira.name);
      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      expect(find.text('0 ${AppStrings.pointsShort}'), findsNothing);

      repository.emit();
      await settle(tester);

      expect(
        find.text('${Fixture.miraChallengePoints} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });

    testWidgets('stays blank when the read fails', (tester) async {
      final repository = await pumpScripted(
        tester,
        activities: Fixture.activities,
        giveUpOnError: true,
      );
      await signIn(tester, Fixture.mira.name);
      await tester.tap(find.text(AppStrings.navActivities));
      await settle(tester);

      repository.fail();
      await settle(tester);

      expect(find.text('0 ${AppStrings.pointsShort}'), findsNothing);
      // The body carries the bad news; the app bar only has to keep quiet.
      expect(find.byType(ErrorView), findsOneWidget);
    });
  });
}
