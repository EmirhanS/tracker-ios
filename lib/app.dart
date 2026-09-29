import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock.dart';
import 'core/router/app_router.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';

/// The root widget: theme plus the router.
///
/// Wrapped in a [ClockTicker] so "Today" and "this week" follow the calendar
/// while the app stays open, instead of freezing on the day it started.
class SportTrackerApp extends ConsumerWidget {
  const SportTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClockTicker(
      child: MaterialApp.router(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
