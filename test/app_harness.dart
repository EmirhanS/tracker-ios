import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/app.dart';
import 'package:sporttracker/core/clock.dart';
import 'package:sporttracker/core/strings/app_strings.dart';
import 'package:sporttracker/data/in_memory/in_memory_activity_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_player_repository.dart';
import 'package:sporttracker/data/in_memory/in_memory_challenge_repository.dart';
import 'package:sporttracker/data/in_memory/seed_data.dart';
import 'package:sporttracker/data/providers.dart';
import 'package:sporttracker/domain/codes/join_code.dart';
import 'package:sporttracker/domain/models/player.dart';

import 'doubles/scripted_join_code_generator.dart';

/// The day the widget tests pretend it is, so the seeded data never moves.
final testToday = DateTime(2026, 9, 29);

/// Starts the app with freshly seeded in-memory repositories.
///
/// Returns the repositories so a test can look at what the screens changed.
Future<SeededRepositories> pumpApp(
  WidgetTester tester, {
  DateTime? now,
}) async {
  final today = now ?? testToday;
  final repositories = SeedData.build(now: today);
  addTearDown(repositories.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(repositories.players),
        challengeRepositoryProvider.overrideWithValue(repositories.challenges),
        activityRepositoryProvider.overrideWithValue(repositories.activities),
        clockProvider.overrideWithValue(() => today),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);

  return repositories;
}

/// Starts the app with the roster but no challenge at all.
///
/// This is the state a brand new team is in, and the only state in which a
/// owner can set a challenge up.
Future<({
  InMemoryPlayerRepository players,
  InMemoryChallengeRepository challenges,
  InMemoryActivityRepository activities,
})> pumpAppWithoutChallenge(
  WidgetTester tester, {
  DateTime? now,
}) async {
  final today = now ?? testToday;
  final players = InMemoryPlayerRepository(const [
    Player(id: 'player_1', name: 'Mia Halvorsen'),
    Player(id: 'player_2', name: 'Jonas Berg'),
  ]);
  final challenges = InMemoryChallengeRepository(
    joinCodeGenerator: ScriptedJoinCodeGenerator(['AAAAAA', 'BBBBBB']),
  );
  final activities = InMemoryActivityRepository(clock: () => today);

  addTearDown(() {
    players.dispose();
    challenges.dispose();
    activities.dispose();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerRepositoryProvider.overrideWithValue(players),
        challengeRepositoryProvider.overrideWithValue(challenges),
        activityRepositoryProvider.overrideWithValue(activities),
        clockProvider.overrideWithValue(() => today),
      ],
      child: const SportTrackerApp(),
    ),
  );
  await settle(tester);

  return (players: players, challenges: challenges, activities: activities);
}

/// Pumps a few frames. [WidgetTester.pumpAndSettle] cannot be used because the
/// app shows progress indicators, which never stop animating.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The button of type [T] carrying [label].
///
/// `find.byType` matches the exact runtime type, and the `.icon` constructors
/// hand back a private subclass, so a plain `widgetWithText(FilledButton, …)`
/// misses every button that has an icon on it.
Finder buttonWithText<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is T),
    );

/// Scrolls a button into view, taps it, and waits.
Future<void> tapButton(WidgetTester tester, String label) async {
  final button = buttonWithText<FilledButton>(label);
  // A screen can hold more than one Scrollable, so name the outer list.
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  // `scrollUntilVisible` stops as soon as the button is *built*, and a
  // `ListView` with a fixed child list builds all of them at once — so on a
  // long screen it stops without having scrolled, and the tap lands off the
  // bottom of the window. This is what actually brings it on screen.
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await settle(tester);
}

/// Takes one named template on the template step of challenge setup.
///
/// The screen lists every template in `ChallengeTemplates.all`, so each card
/// carries its own "use this set" button. The button has to be found inside the
/// card whose title matches, not by its label alone.
Future<void> useTemplate(WidgetTester tester, String templateName) async {
  final button = find.descendant(
    of: find.ancestor(
      of: find.text(templateName),
      matching: find.byType(Card),
    ),
    matching: find.widgetWithText(FilledButton, AppStrings.challengeTemplateUse),
  );

  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(button);
  await settle(tester);
}

/// Signs in from the welcome screen and waits for the dashboard.
Future<void> signIn(WidgetTester tester, String playerName) async {
  // The roster scrolls in the small test window.
  await tester.scrollUntilVisible(find.text(playerName), 100);
  await tester.tap(find.text(playerName));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await settle(tester);
}

/// Signs out from any tab of the main shell.
Future<void> signOut(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.switch_account));
  await settle(tester);
}

/// Opens the challenge switcher in the app bar.
Future<void> openSwitcher(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.expand_more));
  await settle(tester);
}

/// Opens the switcher and picks the challenge called [challengeName].
Future<void> switchToChallenge(WidgetTester tester, String challengeName) async {
  await openSwitcher(tester);
  await tester.tap(find.text(challengeName));
  await settle(tester);
}

/// Opens the switcher and follows "All challenges" through to the list.
Future<void> openChallengeList(WidgetTester tester) async {
  await openSwitcher(tester);
  await tester.tap(find.text(AppStrings.challengesAll));
  await settle(tester);
}

/// Taps a tab of the bottom bar by its label.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await settle(tester);
}

/// The join code the invite screen is showing, read back off the screen.
///
/// The screen groups the code for reading aloud, so this normalises it back
/// into the form the store holds — exactly what a player typing it in does.
String readInviteCode(WidgetTester tester) {
  final shown = tester.widget<Text>(
    find.descendant(of: find.byType(FittedBox), matching: find.byType(Text)),
  );
  return JoinCode.normalize(shown.data!);
}
