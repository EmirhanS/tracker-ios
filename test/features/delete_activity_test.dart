import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/core/widgets/activity_tile.dart';

import '../app_harness.dart';
import '../doubles/scripted_activity_repository.dart';
import '../doubles/scripted_world.dart';
import '../fixtures.dart';

/// Opens My activities with Mira's six rows already on screen.
Future<ScriptedActivityRepository> openActivities(WidgetTester tester) async {
  final repository = await pumpScripted(
    tester,
    activities: Fixture.activities,
  );
  await signIn(tester, Fixture.mira.name);
  await tester.tap(find.text(AppStrings.navActivities));
  await settle(tester);

  repository.emit();
  await settle(tester);

  expect(find.byType(ActivityTile), findsNWidgets(6));
  return repository;
}

/// Swipes the newest row left and confirms the dialog.
Future<void> swipeToDelete(WidgetTester tester) async {
  await tester.drag(find.byType(ActivityTile).first, const Offset(-500, 0));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, AppStrings.delete));
  await settle(tester);
}

/// The row is not the screen's to remove: it leaves the list when the
/// repository stream re-emits without it. Deleting from `onDismissed` starts
/// the write only once the dismiss animation has already finished, so for as
/// long as the write takes there is a dismissed `Dismissible` sitting in a list
/// that still contains its item — which Flutter throws on — and a failure has
/// nowhere to go but a row springing silently back under a "deleted" message.
///
/// In memory the write finishes in a microtask and none of this shows. These
/// tests hold it open.
void main() {
  group('A delete that takes time', () {
    testWidgets('keeps the row until the repository is done', (tester) async {
      final repository = await openActivities(tester);
      final inFlight = Completer<void>();
      repository.pendingDelete = inFlight;

      // The newest row is Sunday 11 Oct's gym session.
      await swipeToDelete(tester);

      expect(repository.deleted, ['activity_2']);
      expect(tester.takeException(), isNull);
      expect(find.byType(ActivityTile), findsNWidgets(6));
      expect(find.text(AppStrings.activitiesDeleted), findsNothing);

      inFlight.complete();
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ActivityTile), findsNWidgets(5));
      expect(find.text(AppStrings.activitiesDeleted), findsOneWidget);
    });

    testWidgets('drops the challenge total by exactly that many points',
        (tester) async {
      final repository = await openActivities(tester);
      final inFlight = Completer<void>();
      repository.pendingDelete = inFlight;

      await swipeToDelete(tester);

      // Still the full total: nothing has actually gone yet.
      expect(
        find.text('${Fixture.miraChallengePoints} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );

      inFlight.complete();
      await settle(tester);

      expect(
        find.text('${Fixture.miraChallengePoints - 3} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });
  });

  group('A delete that fails', () {
    testWidgets('keeps the row and says so', (tester) async {
      final repository = await openActivities(tester);
      repository.deleteError = StateError('offline');

      await swipeToDelete(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.activitiesDeleteFailed), findsOneWidget);
      expect(find.text(AppStrings.activitiesDeleted), findsNothing);
      expect(find.byType(ActivityTile), findsNWidgets(6));
      expect(
        find.text('${Fixture.miraChallengePoints} ${AppStrings.pointsShort}'),
        findsOneWidget,
      );
    });

    testWidgets('leaves the row swipeable again', (tester) async {
      final repository = await openActivities(tester);
      repository.deleteError = StateError('offline');

      await swipeToDelete(tester);
      expect(find.byType(ActivityTile), findsNWidgets(6));

      // The network came back.
      repository.deleteError = null;
      await swipeToDelete(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ActivityTile), findsNWidgets(5));
      expect(repository.deleted, ['activity_2', 'activity_2']);
    });
  });

  group('Cancelling', () {
    testWidgets('writes nothing at all', (tester) async {
      final repository = await openActivities(tester);

      await tester.drag(find.byType(ActivityTile).first, const Offset(-500, 0));
      await settle(tester);
      await tester.tap(find.widgetWithText(TextButton, AppStrings.cancel));
      await settle(tester);

      expect(repository.deleted, isEmpty);
      expect(find.byType(ActivityTile), findsNWidgets(6));
    });
  });
}
