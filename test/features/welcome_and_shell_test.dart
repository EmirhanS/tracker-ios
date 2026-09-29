import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sporttracker/core/strings/app_strings.dart';

import '../app_harness.dart';

void main() {
  testWidgets('the app opens on the welcome screen', (tester) async {
    await pumpApp(tester);

    expect(find.text(AppStrings.welcomeTagline), findsOneWidget);
    expect(find.text(AppStrings.welcomeChoosePlayer), findsOneWidget);
  });

  testWidgets('the roster is listed', (tester) async {
    await pumpApp(tester);

    expect(find.text('Mia Halvorsen'), findsOneWidget);
    expect(find.text('Jonas Berg'), findsOneWidget);

    // The last player is below the fold in the test window.
    await tester.scrollUntilVisible(find.text('Ines Duarte'), 200);
    expect(find.text('Ines Duarte'), findsOneWidget);
  });

  testWidgets('Continue is off until a player is picked', (tester) async {
    await pumpApp(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.welcomeContinue),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Jonas Berg'));
    await settle(tester);

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.welcomeContinue),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('picking a player opens the tab bar', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'Mia Halvorsen');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(AppStrings.navDashboard), findsWidgets);
    expect(find.text(AppStrings.navLeaderboard), findsWidgets);
    expect(find.text(AppStrings.welcomeChoosePlayer), findsNothing);
  });

  testWidgets('the tabs can be switched', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'Mia Halvorsen');

    await tester.tap(find.text(AppStrings.navLeaderboard));
    await settle(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
  });
}
